// 백업 복원 테스트 (P2-24 백업/복원).
//
// RestoreService는 DB에 직접 결합하지 않고 listTables/readTable/insertRows
// 람다만 받으므로 Drift 없이 트리비얼하게 검증한다. 복원 정책은 merge(현재 우선)
// — 현재 기기에 이미 있는 키는 유지, 백업에만 있는 행만 추가(사용자 결정).

import 'dart:convert';
import 'dart:typed_data';

import 'package:pipecheck/core/services/restore_service.dart';
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

  group('RestoreService — 자동증가 id 테이블은 자연키로 병합', () {
    RestoreService make(
      Map<String, List<Map<String, dynamic>>> current,
      Map<String, List<Map<String, dynamic>>> captured, {
      int? schemaVersion,
    }) => RestoreService(
      listTables: () => ['badge'],
      readTable: (t) async => current[t] ?? const [],
      insertRows: (t, rows) async {
        (captured[t] ??= []).addAll(rows.map(Map<String, dynamic>.from));
      },
      naturalKeys: const {'badge': 'badge_id'},
      schemaVersion: schemaVersion,
    );

    test('id가 충돌해도 badge_id가 다르면 복원하고, id는 떼어 DB가 새로 매기게 한다', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = make({
        'badge': [
          {'id': 1, 'badge_id': 'local-only'},
        ],
      }, captured);

      final summary = await service.restoreFromJson(
        _backup({
          'badge': [
            {'id': 1, 'badge_id': 'from-backup'}, // id는 같지만 다른 배지
          ],
        }),
      );

      expect(summary.inserted, 1);
      expect(summary.skipped, 0);
      expect(captured['badge']!.single, {'badge_id': 'from-backup'});
    });

    test('badge_id가 같으면 id가 달라도 건너뛴다 (현재 우선)', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = make({
        'badge': [
          {'id': 7, 'badge_id': 'dup'},
        ],
      }, captured);

      final summary = await service.restoreFromJson(
        _backup({
          'badge': [
            {'id': 1, 'badge_id': 'dup'},
          ],
        }),
      );

      expect(summary.inserted, 0);
      expect(summary.skipped, 1);
      expect(captured, isEmpty);
    });

    test('백업 안의 같은 키 중복은 한 번만 넣는다', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final summary = await make(const {}, captured).restoreFromJson(
        _backup({
          'badge': [
            {'id': 1, 'badge_id': 'x'},
            {'id': 2, 'badge_id': 'x'},
          ],
        }),
      );

      expect(summary.inserted, 1);
      expect(summary.skipped, 1);
    });

    test('자연키 미등록 테이블은 기존대로 id로 병합하고 id를 유지한다', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = RestoreService(
        listTables: () => ['user'],
        readTable: (t) async => const [],
        insertRows: (t, rows) async {
          (captured[t] ??= []).addAll(rows.map(Map<String, dynamic>.from));
        },
        naturalKeys: const {'badge': 'badge_id'},
      );
      await service.restoreFromJson(
        _backup({
          'user': [
            {'id': 'u1'},
          ],
        }),
      );
      expect(captured['user']!.single['id'], 'u1');
    });
  });

  group('RestoreService — BLOB·스키마 버전', () {
    test('{\$base64: ...}를 Uint8List로 되돌려 넣는다', () async {
      final captured = <String, List<Map<String, dynamic>>>{};
      final service = RestoreService(
        listTables: () => ['files'],
        readTable: (t) async => const [],
        insertRows: (t, rows) async {
          (captured[t] ??= []).addAll(rows);
        },
      );
      await service.restoreFromJson(
        _backup({
          'files': [
            {
              'id': 'f1',
              'data': {r'$base64': 'AAH+/w=='},
              'name': 'n',
            },
          ],
        }),
      );
      final row = captured['files']!.single;
      expect(row['data'], Uint8List.fromList([0, 1, 254, 255]));
      expect(row['name'], 'n');
    });

    RestoreService versioned(int v, List<Map<String, dynamic>> inserted) =>
        RestoreService(
          listTables: () => ['user'],
          readTable: (t) async => const [],
          insertRows: (t, rows) async => inserted.addAll(rows),
          schemaVersion: v,
        );

    String backupWith(int? v) => jsonEncode({
      'schema': 'local-drift',
      'schemaVersion': ?v,
      'tables': {
        'user': [
          {'id': '1'},
        ],
      },
    });

    test('더 새 스키마의 백업은 DB를 건드리지 않고 거부', () async {
      final inserted = <Map<String, dynamic>>[];
      await expectLater(
        versioned(2, inserted).restoreFromJson(backupWith(3)),
        throwsA(isA<FormatException>()),
      );
      expect(inserted, isEmpty);
    });

    test('같거나 낮은 버전, 버전 없는 옛 백업은 복원된다', () async {
      for (final v in [2, 1, null]) {
        final inserted = <Map<String, dynamic>>[];
        await versioned(2, inserted).restoreFromJson(backupWith(v));
        expect(inserted, hasLength(1), reason: 'backup v=$v');
      }
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

      final summary = await service.restoreFromJson(
        _backup({
          'user': [
            {'id': '1'},
          ],
        }),
      );

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
        () => service.restoreFromJson(
          _backup({
            'user': [
              {'id': '1'},
            ],
          }),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
