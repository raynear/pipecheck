import 'package:pipecheck/data/datasources/database_datasource.dart';
import 'package:utils/utils.dart';

/// Generic base repository with full CRUD implementation
/// Eliminates ~3,000 lines of BoilerPlate across 9 repositories
abstract class BaseRepository<T, ID> {
  final DatabaseDataSource database;
  final String tableName;
  final T Function(Map<String, dynamic>) fromDatabaseMap;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toDatabaseMap;
  final Map<String, dynamic> Function(T) toJson;
  final ID Function(T) getId;

  BaseRepository({
    required this.database,
    required this.tableName,
    required this.fromDatabaseMap,
    required this.fromJson,
    required this.toDatabaseMap,
    required this.toJson,
    required this.getId,
  });

  /// Get by ID from local DB
  Future<T?> getById(ID id) async {
    try {
      final result = await database.findOne(tableName, where: {'id': id.toString()});
      if (result != null) {
        return fromDatabaseMap(result);
      }
      return null;
    } catch (e) {
      throw RepositoryException('Failed to get $tableName by id', originalError: e);
    }
  }

  /// Get all items
  Future<List<T>> getAll() async {
    try {
      final results = await database.findMany(tableName);
      return results.map((e) => fromDatabaseMap(e)).toList();
    } catch (e, stackTrace) {
      logger.e('BaseRepository.getAll() error: $e', stackTrace: stackTrace);
      throw RepositoryException('Failed to get all $tableName', originalError: e);
    }
  }

  /// Create item
  Future<T> create(T model) async {
    try {
      final dbMap = toDatabaseMap(model);
      await database.insert(tableName, dbMap);
      return model;
    } catch (e) {
      throw RepositoryException('Failed to create $tableName', originalError: e);
    }
  }

  /// Update item
  Future<T> update(T model) async {
    try {
      final id = getId(model);
      final dbMap = toDatabaseMap(model);
      await database.update(tableName, dbMap, where: {'id': id.toString()});
      return model;
    } catch (e) {
      throw RepositoryException('Failed to update $tableName', originalError: e);
    }
  }

  /// Delete item
  Future<bool> delete(ID id) async {
    try {
      await database.delete(tableName, where: {'id': id.toString()});
      return true;
    } catch (e) {
      throw RepositoryException('Failed to delete $tableName', originalError: e);
    }
  }

  /// Delete multiple items
  Future<bool> deleteMany(List<ID> ids) async {
    try {
      for (final id in ids) {
        await database.delete(tableName, where: {'id': id.toString()});
      }
      return true;
    } catch (e) {
      throw RepositoryException('Failed to delete multiple $tableName items', originalError: e);
    }
  }

  /// Find by field
  Future<List<T>> findByField(String field, dynamic value) async {
    try {
      final results = await database.findMany(tableName, where: {field: value});
      return results.map((e) => fromDatabaseMap(e)).toList();
    } catch (e) {
      throw RepositoryException('Failed to find $tableName by $field', originalError: e);
    }
  }
}

/// Repository 에러 클래스
class RepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  RepositoryException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'RepositoryException: $message';
}
