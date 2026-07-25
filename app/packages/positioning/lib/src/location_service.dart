import 'package:geolocator/geolocator.dart';
import 'package:utils/utils.dart';

import 'location_config.dart';

/// 위치(positioning) 서비스 — `geolocator` 래퍼 (앱-무관).
///
/// 권한 확인/요청은 순수 passthrough(호출 시점은 앱 UI가 결정), 위치 취득
/// (현재 위치/스트림)은 주입된 [LocationConfig]로 가드한다.
///
/// 앱은 부팅 시점에 [configure]로 기능 플래그를 주입한다. 호출 전 또는 비활성
/// 상태에서 위치 취득은 안전하게 no-op(null / 빈 스트림).
class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;

  static LocationConfig _config = const LocationConfig.disabled();

  /// 앱이 부팅 시점에 기능 플래그를 주입한다.
  static void configure(LocationConfig config) {
    _config = config;
  }

  /// OS 위치 서비스 활성 여부 (passthrough).
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// 현재 위치 권한 상태 (passthrough — 권한 UI 전용).
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  /// 위치 권한 요청 (passthrough — 권한 UI 전용).
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  /// 현재 위치 1회 취득. 비활성/권한 없음이면 null.
  Future<Position?> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (!_config.locationEnabled) {
      logger.d('Location disabled by config - skipping getCurrentPosition');
      return null;
    }
    final permission = await checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      logger.w('Location permission not granted - skipping getCurrentPosition');
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(locationSettings: locationSettings);
    } catch (e) {
      logger.e('Failed to get current position: $e');
      return null;
    }
  }

  /// 마지막으로 알려진 위치 (캐시, 빠름). 비활성이면 null.
  Future<Position?> getLastKnownPosition() async {
    if (!_config.locationEnabled) return null;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      logger.e('Failed to get last known position: $e');
      return null;
    }
  }

  /// 위치 변경 스트림. 비활성이면 빈 스트림.
  Stream<Position> positionStream({LocationSettings? locationSettings}) {
    if (!_config.locationEnabled) {
      return const Stream<Position>.empty();
    }
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
