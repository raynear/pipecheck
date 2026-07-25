/// 데이터 소스의 기본 인터페이스
abstract class BaseDataSource {
  /// 데이터 소스 초기화
  Future<void> initialize();

  /// 데이터 소스 정리
  Future<void> dispose();

  /// 연결 상태 확인
  bool get isConnected;
}
