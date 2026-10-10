// 테스트용 인메모리 DatabaseDataSource.
//
// 이게 없으면 `databaseProvider`가 실제 `DriftDatabase()`를 만들고, 위젯
// 테스트에서 플랫폼 채널이 없어 비동기로 터진다 — 그 예외는 정작 실패로
// 보고되는 단언과 무관한 곳에서 나타나 원인 추적을 어렵게 한다.

import 'package:pipecheck/data/datasources/database_datasource.dart';

/// 인메모리 DB. 테이블→(id→row). `_saveUserToLocalDb`의 create/update 두 갈래를
/// 실제로 갈라 놓기 위해 findOne이 정직하게 동작해야 한다.
class MemoryDb implements DatabaseDataSource {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};

  /// 켜면 읽기가 던진다 (DB 파손 경로).
  bool failReads = false;

  @override
  List<String> get tableNames => tables.keys.toList();

  @override
  bool get isConnected => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> clearAll() async => tables.clear();

  @override
  Future<Map<String, dynamic>?> findOne(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
  }) async {
    if (failReads) throw StateError('DB 파손');
    return tables[table]?[where?['id'] as String?];
  }

  @override
  Future<List<Map<String, dynamic>>> findMany(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      tables[table]?.values.toList() ?? const [];

  @override
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    tables.putIfAbsent(table, () => {})[data['id'] as String] = data;
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> insertMany(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    for (final row in data) {
      await insert(table, row);
    }
    return data;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    tables.putIfAbsent(table, () => {})[where['id'] as String] = data;
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async =>
      tables[table]?.remove(where['id']) == null ? 0 : 1;

  @override
  Future<R> transaction<R>(Future<R> Function() action) => action();
}
