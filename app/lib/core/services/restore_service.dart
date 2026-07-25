import 'dart:convert';

import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.runInTransaction,
  }) : rowKey = rowKey ?? _defaultRowKey;

  /// 복원 가능한(템플릿이 아는) 테이블 이름 목록.
  final List<String> Function() listTables;

  /// 테이블 이름 → 현재 행 전체.
  final Future<List<Map<String, dynamic>>> Function(String table) readTable;

  /// 테이블에 행들을 추가한다.
  final Future<void> Function(String table, List<Map<String, dynamic>> rows)
      insertRows;

  /// 행 식별 키 추출기 (기본 `id` 컬럼).
  final Object? Function(String table, Map<String, dynamic> row) rowKey;

  /// merge 본체를 감쌀 트랜잭션 러너 (주입, 선택).
  ///
  /// 제공되면 복원 전체가 **원자적**으로 적용된다 — 중간 테이블에서 insert가
  /// 실패하면 앞서 넣은 행도 롤백된다(부분 복원 방지). null이면 직접 실행한다
  /// (단위 테스트). 형식 파싱은 트랜잭션 밖에서 먼저 하므로 형식 오류는 DB를
  /// 전혀 건드리지 않는다.
  final Future<RestoreSummary> Function(
    Future<RestoreSummary> Function() action,
  )? runInTransaction;

  static Object? _defaultRowKey(String table, Map<String, dynamic> row) =>
      row['id'];

  /// 백업 JSON 문자열을 파싱해 현재-우선 merge로 복원한다.
  ///
  /// - 백업 형식이 아니면 [FormatException] (DB 무변경 — 파싱이 merge보다 먼저).
  /// - 템플릿에 없는 테이블([listTables]에 없는 이름)은 무시한다.
  /// - 키가 현재 테이블에 이미 있으면 건너뛴다(현재 우선). 키가 null이면 추가한다.
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
    if (doc is! Map || doc['schema'] != 'local-drift' || doc['tables'] is! Map) {
      throw const FormatException('Not a recognized backup file');
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
      final currentKeys =
          current.map((r) => rowKey(table, r)).whereType<Object>().toSet();

      final toInsert = <Map<String, dynamic>>[];
      for (final row in rows) {
        final key = rowKey(table, row);
        if (key != null && currentKeys.contains(key)) {
          skipped++;
          continue;
        }
        toInsert.add(row);
      }
      if (toInsert.isNotEmpty) {
        await insertRows(table, toInsert);
        inserted += toInsert.length;
      }
    }

    return RestoreSummary(inserted: inserted, skipped: skipped);
  }
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
  );
});
