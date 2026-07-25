// 백업 복원 테스트 (P2-24 백업/복원).
//
// RestoreService는 DB에 직접 결합하지 않고 listTables/readTable/insertRows
// 람다만 받으므로 Drift 없이 트리비얼하게 검증한다. 복원 정책은 merge(현재 우선)
// — 현재 기기에 이미 있는 키는 유지, 백업에만 있는 행만 추가(사용자 결정).

import 'dart:convert';

import 'package:boilerplate/core/services/restore_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _backup(Map<String, List<Map<String, dynamic>>> tables) => jsonEncode({
  'schema': 'local-drift',
  'exportedAt': '2026-01-01T00:00:00.000Z',
  'tables': tables,
});

RestoreService _service({
  required List<String> known,
  required Map<String, List<Map<String, dynamic>>> current,
  required Map<String, List<Map<String, dynamic>>> captured,
}) => RestoreService(
  listTables: () => known,
  readTable: (t) async => current[t] ?? const [],
  insertRows: (t, rows) async {
    (captured[t] ??= []).addAll(rows.map(Map<String, dynamic>.from));
  },
);

void main() {
  group('RestoreService.restoreFromJson — merge(현재 우선)', () {
    test('현재에 있는 키는 건너뛰고 백업에만 있는 행만 추가', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = _service(
        known: ['user'],
        current: {
          'user': [
            {'id': '1', 'name': 'CurrentKim'},
          ],
        },
        captured: captured,
      );

      final summary = await service.restoreFromJson(
        _backup({
          'user': [
            {'id': '1', 'name': 'BackupKim'}, // 현재에 있는 키 → skip (현재 우선)
            {'id': '2', 'name': 'BackupLee'}, // 백업에만 → insert
          ],
        }),
      );

      expect(summary.inserted, 1);
      expect(summary.skipped, 1);
      expect(captured['user'], hasLength(1));
      expect(captured['user']!.first['id'], '2');
      expect(captured['user']!.first['name'], 'BackupLee');
    });

    test('템플릿에 없는 테이블은 무시', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = _service(
        known: ['user'],
        current: {'user': const []},
        captured: captured,
      );

      final summary = await service.restoreFromJson(
        _backup({
          'ghost': [
            {'id': 'x'},
          ],
        }),
      );

      expect(summary.inserted, 0);
      expect(captured.containsKey('ghost'), false);
    });

    test('키(id)가 null인 행은 중복 판정 불가 → 추가', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = _service(
        known: ['log'],
        current: {'log': const []},
        captured: captured,
      );

      final summary = await service.restoreFromJson(
        _backup({
          'log': [
            {'message': 'no id row'},
          ],
        }),
      );

      expect(summary.inserted, 1);
      expect(captured['log'], hasLength(1));
    });

    test('빈 백업 → inserted/skipped 0', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = _service(
        known: ['user'],
        current: {'user': const []},
        captured: captured,
      );

      final summary = await service.restoreFromJson(_backup({}));

      expect(summary.inserted, 0);
      expect(summary.skipped, 0);
      expect(captured, isEmpty);
    });

    test('커스텀 rowKey로 식별 컬럼 지정', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = RestoreService(
        listTables: () => ['event'],
        readTable: (t) async => [
          {'uuid': 'a', 'v': 1},
        ],
        insertRows: (t, rows) async {
          (captured[t] ??= []).addAll(rows.map(Map<String, dynamic>.from));
        },
        rowKey: (t, row) => row['uuid'],
      );

      final summary = await service.restoreFromJson(
        _backup({
          'event': [
            {'uuid': 'a', 'v': 2}, // 현재 키 'a' → skip
            {'uuid': 'b', 'v': 3}, // → insert
          ],
        }),
      );

      expect(summary.inserted, 1);
      expect(captured['event']!.single['uuid'], 'b');
    });
  });

  group('RestoreService.restoreFromJson — 형식 검증', () {
    RestoreService bare() => RestoreService(
      listTables: () => const ['user'],
      readTable: (t) async => const [],
      insertRows: (t, rows) async {},
    );

    test('JSON이 아니면 FormatException', () {
      expect(
        () => bare().restoreFromJson('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('schema가 local-drift가 아니면 FormatException', () {
      expect(
        () => bare().restoreFromJson(
          jsonEncode({'schema': 'other', 'tables': {}}),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('tables 키가 없으면 FormatException', () {
      expect(
        () => bare().restoreFromJson(jsonEncode({'schema': 'local-drift'})),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RestoreService — 트랜잭션 원자성', () {
    test('runInTransaction이 제공되면 merge를 그 안에서 실행', () async {
      var wrapped = false;
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = RestoreService(
        listTables: () => ['user'],
        readTable: (t) async => const [],
        insertRows: (t, rows) async {
          (captured[t] ??= []).addAll(rows.map(Map<String, dynamic>.from));
        },
        runInTransaction: (action) async {
          wrapped = true;
          return action();
        },
      );

      final summary = await service.restoreFromJson(_backup({
        'user': [
          {'id': '1'},
        ],
      }));

      expect(wrapped, true);
      expect(summary.inserted, 1);
    });

    test('insert 실패는 트랜잭션 러너로 전파(롤백 가능)', () {
      final service = RestoreService(
        listTables: () => ['user'],
        readTable: (t) async => const [],
        insertRows: (t, rows) async => throw StateError('insert boom'),
        runInTransaction: (action) => action(),
      );

      expect(
        () => service.restoreFromJson(_backup({
          'user': [
            {'id': '1'},
          ],
        })),
        throwsA(isA<StateError>()),
      );
    });
  });
}
