import 'package:boilerplate/data/datasources/database_datasource.dart';
import 'package:boilerplate/data/datasources/local/database/database.dart';
import 'package:drift/drift.dart';
import 'package:utils/utils.dart';

/// Drift 기반 데이터베이스 구현체
class DriftDatabase extends DatabaseDataSource {
  final AppDatabase _db = AppDatabase();
  bool _isInitialized = false;

  // 테이블 레지스트리: 문자열 이름 → TableInfo 객체 매핑
  late final Map<String, TableInfo> _tableRegistry;

  DriftDatabase() {
    logger.d('DriftDatabase constructor called');
    // 테이블 레지스트리 초기화
    // Note: 고아 테이블들(calendar_accounts, calendar_preferences, categorys, tasks, blocks, sync_queues, holidays, todo_list_mappings)은
    //       정의 파일이 없고 사용되지 않아 제거됨 (v9 마이그레이션)
    _tableRegistry = {
      'badge': _db.$Badge,
      'user': _db.$User,
    };
    logger.d('DriftDatabase registry initialized with tables: ${_tableRegistry.keys.join(", ")}');
  }

  @override
  List<String> get tableNames => _tableRegistry.keys.toList();

  @override
  Future<void> clearAll() async {
    await _db.transaction(() async {
      for (final table in _tableRegistry.keys) {
        // 빈 where → `DELETE FROM <table>` (전체 행 삭제)
        await delete(table, where: const {});
      }
    });
  }

  @override
  bool get isConnected => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    await _db.close();
    _isInitialized = false;
  }

  // ========== 기본 CRUD 구현 ==========

  @override
  Future<Map<String, dynamic>?> findOne(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
  }) async {
    final query = _db.customSelect(
      _buildSelectQuery(table, where: where, columns: columns, limit: 1),
      variables: _extractWhereValues(where),
      readsFrom: {_getTable(table)},
    );

    final result = await query.getSingleOrNull();
    return result?.data;
  }

  @override
  Future<List<Map<String, dynamic>>> findMany(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    logger.d('DriftDatabase.findMany called for table: $table');
    try {
      final query = _db.customSelect(
        _buildSelectQuery(
          table,
          where: where,
          columns: columns,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ),
        variables: _extractWhereValues(where),
        readsFrom: {_getTable(table)},
      );

      final results = await query.get();
      logger.d('DriftDatabase.findMany results count: ${results.length}');
      if (results.isNotEmpty && table == 'categorys') {
        logger.d('First category row data: ${results.first.data}');
      }
      return results.map((row) => row.data).toList();
    } catch (e) {
      logger.e('DriftDatabase.findMany error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    // 현재 시간 추가
    final now = DateTime.now();
    data['created_at'] ??= now.toIso8601String();
    data['updated_at'] ??= now.toIso8601String();

    await _db.customInsert(
      _buildInsertQuery(table, data),
      variables: data.values.map((v) => Variable(v)).toList(),
    );

    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> insertMany(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    final now = DateTime.now();

    // Drift의 batch는 테이블별로만 동작하므로, 각각 실행
    for (final row in data) {
      row['created_at'] ??= now.toIso8601String();
      row['updated_at'] ??= now.toIso8601String();

      await _db.customInsert(
        _buildInsertQuery(table, row),
        variables: row.values.map((v) => Variable(v)).toList(),
      );
    }

    return data;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  }) async {
    // 업데이트 시간 추가
    data['updated_at'] = DateTime.now().toIso8601String();

    final result = await _db.customUpdate(
      _buildUpdateQuery(table, data, where),
      variables: [
        ...data.values.map((v) => Variable(v)),
        ..._whereToVariables(where),
      ],
    );

    return result;
  }

  @override
  Future<int> delete(
    String table, {
    required Map<String, dynamic> where,
  }) async {
    final result = await _db.customUpdate(
      _buildDeleteQuery(table, where),
      variables: _whereToVariables(where),
    );

    return result;
  }

  // ========== 트랜잭션 구현 ==========

  @override
  Future<R> transaction<R>(Future<R> Function() action) {
    return _db.transaction(() => action());
  }

  // ========== 헬퍼 메서드 ==========

  /// WHERE 절에서 값들을 추출하는 헬퍼 메서드
  List<Variable> _extractWhereValues(Map<String, dynamic>? where) {
    if (where == null || where.isEmpty) return [];

    final values = <Variable>[];

    where.forEach((key, value) {
      // 특수 연산자 처리
      if (key.endsWith('_null')) {
        // IS NULL/IS NOT NULL은 값이 필요 없음
        return;
      } else if (key.endsWith('_in')) {
        // IN 절의 경우 리스트의 각 값을 추가
        if (value is List) {
          for (final item in value) {
            values.add(Variable(item));
          }
        }
      } else {
        // 일반 조건의 경우 값 추가
        values.add(Variable(value));
      }
    });

    return values;
  }

  String _buildSelectQuery(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final columnList = columns?.join(', ') ?? '*';
    var sql = 'SELECT $columnList FROM $table';

    sql += _buildWhereClause(where);

    if (orderBy != null) sql += ' ORDER BY $orderBy';
    if (limit != null) sql += ' LIMIT $limit';
    if (offset != null) sql += ' OFFSET $offset';

    return sql;
  }

  String _buildInsertQuery(String table, Map<String, dynamic> data) {
    final columns = data.keys.join(', ');
    final placeholders = data.keys.map((_) => '?').join(', ');
    return 'INSERT INTO $table ($columns) VALUES ($placeholders)';
  }

  String _buildUpdateQuery(
    String table,
    Map<String, dynamic> data,
    Map<String, dynamic> where,
  ) {
    final setClause = data.keys.map((key) => '$key = ?').join(', ');
    return 'UPDATE $table SET $setClause ${_buildWhereClause(where)}';
  }

  String _buildDeleteQuery(String table, Map<String, dynamic> where) {
    return 'DELETE FROM $table ${_buildWhereClause(where)}';
  }

  String _buildWhereClause(Map<String, dynamic>? where) {
    if (where == null || where.isEmpty) return '';

    final conditions = <String>[];

    where.forEach((key, value) {
      if (key.endsWith('!=')) {
        conditions.add('${key.replaceAll('!=', '')} != ?');
      } else if (key.endsWith('>')) {
        conditions.add('${key.replaceAll('>', '')} > ?');
      } else if (key.endsWith('>=')) {
        conditions.add('${key.replaceAll('>=', '')} >= ?');
      } else if (key.endsWith('<')) {
        conditions.add('${key.replaceAll('<', '')} < ?');
      } else if (key.endsWith('<=')) {
        conditions.add('${key.replaceAll('<=', '')} <= ?');
      } else if (key.endsWith('_null')) {
        final column = key.replaceAll('_null', '');
        conditions.add(value ? '$column IS NULL' : '$column IS NOT NULL');
      } else if (key.endsWith('_in')) {
        final column = key.replaceAll('_in', '');
        final values = (value as List).map((_) => '?').join(', ');
        conditions.add('$column IN ($values)');
      } else if (key.endsWith('_between')) {
        final column = key.replaceAll('_between', '');
        conditions.add('$column BETWEEN ? AND ?');
      } else {
        conditions.add('$key = ?');
      }
    });

    return ' WHERE ${conditions.join(' AND ')}';
  }

  List<Variable> _whereToVariables(Map<String, dynamic> where) {
    final variables = <Variable>[];

    where.forEach((key, value) {
      if (!key.endsWith('_null')) {
        if (value is List) {
          variables.addAll(value.map((v) => Variable(v)));
        } else {
          variables.add(Variable(value));
        }
      }
    });

    return variables;
  }

  TableInfo _getTable(String tableName) {
    logger.d('_getTable called with tableName: $tableName');
    logger.d('Available tables in registry: ${_tableRegistry.keys.join(", ")}');
    final table = _tableRegistry[tableName.toLowerCase()];
    if (table == null) {
      throw ArgumentError('Unknown table: $tableName. Available tables: ${_tableRegistry.keys.join(", ")}');
    }
    logger.d('Table found: ${table.actualTableName}');
    return table;
  }

  /// 사용 가능한 테이블 목록 반환
  List<String> getAvailableTables() {
    return _tableRegistry.keys.toList();
  }
}
