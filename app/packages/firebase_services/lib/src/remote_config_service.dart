import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:utils/utils.dart';

/// Firebase Remote Config 래퍼 (앱-무관 엔진).
///
/// `Firebase.initializeApp` 이후에 [initialize]를 호출해야 한다 — 이 클래스는
/// Firebase를 초기화하지 않는다. Riverpod provider 바인딩은 앱에 남는다.
class RemoteConfigService {
  static RemoteConfigService? _instance;
  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  RemoteConfigService._internal();

  static RemoteConfigService get instance {
    _instance ??= RemoteConfigService._internal();
    return _instance!;
  }

  /// 멱등 초기화. 부팅 패스(RC→플래그 override, P2-23.5b)와 비중요 서비스
  /// 단계가 모두 호출할 수 있으므로 한 번만 실제 초기화한다 —
  /// `late final _remoteConfig` 재할당과 중복 fetch를 막는다.
  ///
  /// Firebase 앱이 없으면 `FirebaseRemoteConfig.instance`가 던지는데, 그 경우
  /// `_initialized`를 false로 두고 조용히 반환한다(다음 호출이 재시도). 인스턴스
  /// 확보 후의 fetch 실패는 기본값으로 폴백한다(getter는 안전하게 동작).
  Future<void> initialize() async {
    if (_initialized) return;

    final FirebaseRemoteConfig rc;
    try {
      rc = FirebaseRemoteConfig.instance;
    } catch (e) {
      logger.w('Remote Config unavailable (no Firebase app yet): $e');
      return;
    }
    _remoteConfig = rc;
    _initialized = true;

    try {
      // Set default values (P1-15: zero-reader 키 정리 —
      // subscription_variant는 P2-21이, maintenance_mode는 P2-23이 소비 예정)
      await _remoteConfig.setDefaults({
        'subscription_variant': 'A',
        'maintenance_mode': false,
        'min_app_version': '1.0.0',
      });

      // Configure settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();

      logger.d('Remote Config initialized successfully');
    } catch (e) {
      logger.e('Failed to fetch Remote Config: $e');
    }
  }

  /// 서버에서 명시적으로 설정된 `feature_<flag>` 키만 `{flagName: bool}`로 반환한다
  /// (RC→플래그 override 브리지, P2-23.5b).
  ///
  /// `getBool`은 미설정 키를 false로 주기 때문에, source가
  /// [ValueSource.valueRemote]인 키만 추린다 — 기본값/정적 소스(콘솔에 없는 키)는
  /// "의견 없음"으로 보고 제외한다. 안 그러면 콘솔에 없는 모든 기능이 false로
  /// override돼 전부 꺼진다.
  ///
  /// 초기화 전이거나 Firebase가 없으면 빈 맵(= override 없음, yaml 값 유지).
  Map<String, bool> remoteFeatureOverrides({String prefix = 'feature_'}) {
    if (!_initialized) return const {};
    final result = <String, bool>{};
    for (final entry in _remoteConfig.getAll().entries) {
      if (!entry.key.startsWith(prefix)) continue;
      if (entry.value.source != ValueSource.valueRemote) continue;
      result[entry.key.substring(prefix.length)] = entry.value.asBool();
    }
    return result;
  }

  // Getters for various configurations
  String get subscriptionVariant => _remoteConfig.getString('subscription_variant');
  bool get maintenanceMode => _remoteConfig.getBool('maintenance_mode');
  String get minAppVersion => _remoteConfig.getString('min_app_version');

  // Generic getters
  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);

  // Feature flags
  bool isFeatureEnabled(String featureName) {
    return _remoteConfig.getBool('feature_$featureName');
  }

  // A/B Test variants
  String getABTestVariant(String testName) {
    return _remoteConfig.getString('ab_test_$testName');
  }

  // Force refresh (use sparingly)
  Future<void> forceRefresh() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));

      await _remoteConfig.fetchAndActivate();

      // Reset to normal interval
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      logger.d('Remote Config force refreshed');
    } catch (e) {
      logger.e('Failed to force refresh Remote Config: $e');
    }
  }
}
