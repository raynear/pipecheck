import 'package:boilerplate/data/datasources/base_datasource.dart';

/// 일반화된 데이터베이스 인터페이스
/// 테이블에 독립적인 CRUD 작업 제공
abstract class DatabaseDataSource extends BaseDataSource {
  // ========== 메타데이터 ==========

  /// 내보내기/관리용 테이블 이름 목록 (P2-23f 데이터 내보내기 소비).
  List<String> get tableNames;

  /// 모든 테이블의 데이터를 삭제한다 (PIN 분실 복구의 앱 데이터 초기화,
  /// P2-23h ③ — 잠금 우회를 막기 위해 보호 데이터를 함께 폐기).
  Future<void> clearAll();

  // ========== 기본 CRUD 작업 ==========

  /// 단일 레코드 조회
  Future<Map<String, dynamic>?> findOne(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
  });

  /// 여러 레코드 조회
  Future<List<Map<String, dynamic>>> findMany(
    String table, {
    Map<String, dynamic>? where,
    List<String>? columns,
    String? orderBy,
    int? limit,
    int? offset,
  });

  /// 레코드 생성
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  );

  /// 여러 레코드 생성
  Future<List<Map<String, dynamic>>> insertMany(
    String table,
    List<Map<String, dynamic>> data,
  );

  /// 레코드 업데이트
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> where,
  });

  /// 레코드 삭제
  Future<int> delete(
    String table, {
    required Map<String, dynamic> where,
  });

  // ========== 트랜잭션 ==========

  /// 트랜잭션 실행 (P2-24 백업/복원 원자성에 소비).
  Future<R> transaction<R>(Future<R> Function() action);
}
