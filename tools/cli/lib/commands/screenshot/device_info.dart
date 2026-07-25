/// 디바이스 정보.
class DeviceInfo {
  /// 디바이스 정보를 생성합니다.
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.state,
  });

  /// 디바이스 ID.
  final String id;

  /// 디바이스 이름.
  final String name;

  /// 플랫폼 (ios, android).
  final String platform;

  /// 상태 (Booted, Shutdown, available, connected).
  final String state;
}
