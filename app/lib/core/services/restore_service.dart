import 'dart:convert';
import 'dart:typed_data';

import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:pipecheck/data/datasources/local/database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 자동증가 정수 `id`를 PK로 쓰는 테이블의 **자연키 컬럼** (테이블 → 컬럼).
///
/// 자동증가 `id`는 기기마다 따로 매겨지는 대리키라 백업의 `id=1`과 이 기기의
/// `id=1`은 다른 행이다. `id`로 병합하면 서로 다른 행이 "이미 있다"로 조용히
/// 버려진다. 그래서 이 테이블들은 자연키로 병합하고, 복원할 때 `id`는 떼어
/// 내 DB가 새로 매기게 한다. uuid PK 테이블은 `id`가 곧 전역 식별자라 등록이
/// 필요 없다.
///
/// **자동증가 PK 테이블을 추가하면 여기에 한 줄 더한다** —
/// `restore_natural_keys_test.dart`가 빠뜨리면 빨개진다. 컬럼명은 SQL(snake_case).
const restoreNaturalKeys = <String, String>{'badge': 'badge_id'};

/// 백업 JSON에서 BLOB(`Uint8List`)을 담는 래퍼 키 — `{"$base64": "..."}`.
const blobKey = r'$base64';

/// 백업 복원 결과 요약.
class RestoreSummary {
  const RestoreSummary({required this.inserted, required this.skipped});

  /// 새로 추가된 행 수.
  final int inserted;

  /// 현재 기기에 이미 있어 건너뛴 행 수.
  final int skipped;
}

/// 백업 JSON을 로컬 DB로 복원하는 서비스 (P2-24 백업/복원).
///
/// [DataExportService]가 만든 백업 파일을 받아 **merge(현재 우선)**로 병합한다 —
/// 현재 기기에 이미 있는 키는 유지하고, 백업에만 있는 행만 추가한다(사용자 결정).
/// 서버 코드 0줄(backend-direction): 복원도 로컬에서 완결된다.
///
/// DB에 직접 결합하지 않도록 능력만 주입받는다([listTables]/[readTable]/
/// [insertRows]) — 테스트가 람다로 트리비얼하게 검증한다. 행 식별 키는
/// [rowKey](기본 `id` 컬럼)로 추출한다(템플릿 테이블은 `id` PK 규약).
class RestoreService {
  RestoreService({
    required this.listTables,
    required this.readTable,
    required this.insertRows,
    Object? Function(String table, Map<String, dynamic> row)? rowKey,
    this.naturalKeys = const {},
    this.schemaVersion,
    this.runInTransaction,
  }) : _customRowKey = rowKey != null,
       rowKey = rowKey ?? ((t, r) => r[naturalKeys[t] ?? 'id']);

  /// 자동증가 PK 테이블의 자연키 컬럼 ([restoreNaturalKeys]). 여기 있는 테이블은
  /// 자연키로 병합하고 복원 시 `id`를 떼어 낸다. 커스텀 [rowKey]를 주면 무시.
  final Map<String, String> naturalKeys;

  /// 이 기기 DB의 스키마 버전. 백업의 `schemaVersion`이 이보다 크면(더 새 앱이
  /// 만든 백업) 없는 컬럼이 있을 수 있어 복원을 거부한다. null이면 검사 안 함.
  final int? schemaVersion;

  final bool _customRowKey;

  /// 복원 가능한(템플릿이 아는) 테이블 이름 목록.
  final List<String> Function() listTables;

  /// 테이블 이름 → 현재 행 전체.
  final Future<List<Map<String, dynamic>>> Function(String table) readTable;

  /// 테이블에 행들을 추가한다.
  final Future<void> Function(String table, List<Map<String, dynamic>> rows)
  insertRows;

  /// 행 식별 키 추출기 (기본: [naturalKeys]에 있으면 그 컬럼, 아니면 `id`).
  final Object? Function(String table, Map<String, dynamic> row) rowKey;

  /// merge 본체를 감쌀 트랜잭션 러너 (주입, 선택).
  ///
  /// 제공되면 복원 전체가 **원자적**으로 적용된다 — 중간 테이블에서 insert가
  /// 실패하면 앞서 넣은 행도 롤백된다(부분 복원 방지). null이면 직접 실행한다
  /// (단위 테스트). 형식 파싱은 트랜잭션 밖에서 먼저 하므로 형식 오류는 DB를
  /// 전혀 건드리지 않는다.
  final Future<RestoreSummary> Function(
    Future<RestoreSummary> Function() action,
  )?
  runInTransaction;

  /// 백업 JSON 문자열을 파싱해 현재-우선 merge로 복원한다.
  ///
  /// - 백업 형식이 아니면 [FormatException] (DB 무변경 — 파싱이 merge보다 먼저).
  /// - 템플릿에 없는 테이블([listTables]에 없는 이름)은 무시한다.
  /// - 백업이 더 새 스키마([schemaVersion] 초과)면 [FormatException].
  /// - 키가 현재 테이블에 이미 있으면 건너뛴다(현재 우선). 키가 null이면 추가한다.
  ///   백업 안의 중복 키도 한 번만 넣는다.
  Future<RestoreSummary> restoreFromJson(String jsonString) async {
    final tables = _parseTables(jsonString);
    Future<RestoreSummary> merge() => _merge(tables);
    final runner = runInTransaction;
    return runner != null ? runner(merge) : merge();
  }

  /// 백업 문서를 검증하고 `tables` 맵을 꺼낸다. DB를 건드리지 않는다.
  Map _parseTables(String jsonString) {
    final Object? doc;
    try {
      doc = jsonDecode(jsonString);
    } on FormatException {
      throw const FormatException('Backup file is not valid JSON');
    }
    if (doc is! Map ||
        doc['schema'] != 'local-drift' ||
        doc['tables'] is! Map) {
      throw const FormatException('Not a recognized backup file');
    }
    final backupVersion = doc['schemaVersion'];
    final mine = schemaVersion;
    if (mine != null && backupVersion is int && backupVersion > mine) {
      throw const FormatException('Backup is from a newer app version');
    }
    return doc['tables'] as Map;
  }

  Future<RestoreSummary> _merge(Map tables) async {
    final known = listTables().toSet();
    var inserted = 0;
    var skipped = 0;

    for (final entry in tables.entries) {
      final table = entry.key as String;
      if (!known.contains(table)) continue;

      final value = entry.value;
      if (value is! List) continue;
      final rows = value
          .whereType<Map>()
          .map((r) => r.cast<String, dynamic>())
          .toList();

      final current = await readTable(table);
      final currentKeys = current
          .map((r) => rowKey(table, r))
          .whereType<Object>()
          .toSet();

      final stripId = !_customRowKey && naturalKeys.containsKey(table);
      final toInsert = <Map<String, dynamic>>[];
      for (final raw in rows) {
        final row = _decodeBlobs(raw);
        final key = rowKey(table, row);
        if (key != null && !currentKeys.add(key)) {
          skipped++;
          continue;
        }
        if (stripId) row.remove('id');
        toInsert.add(row);
      }
      if (toInsert.isNotEmpty) {
        await insertRows(table, toInsert);
        inserted += toInsert.length;
      }
    }

    return RestoreSummary(inserted: inserted, skipped: skipped);
  }

  /// `{"$base64": "..."}` 래퍼를 `Uint8List`로 되돌린다 (복사본을 돌려준다).
  static Map<String, dynamic> _decodeBlobs(Map<String, dynamic> row) => {
    for (final e in row.entries)
      e.key: switch (e.value) {
        {blobKey: final String b64} => Uint8List.fromList(base64Decode(b64)),
        final v => v,
      },
  };
}

/// 앱 DB(로컬 Drift)에 배선된 RestoreService.
final restoreServiceProvider = Provider<RestoreService>((ref) {
  final db = ref.watch(databaseProvider);
  return RestoreService(
    listTables: () => db.tableNames,
    readTable: (t) => db.findMany(t),
    insertRows: (t, rows) async {
      await db.insertMany(t, rows);
    },
    runInTransaction: (action) => db.transaction(action),
    naturalKeys: restoreNaturalKeys,
    schemaVersion: appSchemaVersion,
  );
});
