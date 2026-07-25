import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utils/utils.dart';

import 'ab_test_config.dart';
import 'experiment_spec.dart';

/// 코드 레벨 A/B 테스트 + Firebase Remote Config 킬스위치 엔진.
///
/// 앱별 실험 목록([experiments])과 기능 설정([config])을 주입받는다 —
/// 패키지는 어떤 앱에도 의존하지 않는다(앱의 `AppFeatureConfig` import 없음).
///
/// 동작 방식:
/// 1. 첫 실행 시 로컬에서 [ExperimentSpec.trafficPercent] 비율로 랜덤 할당
/// 2. SharedPreferences에 영구 저장 (한 번 할당되면 변하지 않음)
/// 3. Remote Config는 킬스위치 역할만 (false → 강제 control)
/// 4. GA4 user property로 variant 자동 동기화
///
/// 사용 예시:
/// ```dart
/// final svc = ABTestService(
///   experiments: Experiment.values,
///   config: ABTestConfig(enabled: true, remoteConfigEnabled: true,
///       analyticsEnabled: true, crashlyticsEnabled: true),
/// );
/// await svc.initialize();
///
/// if (svc.isEnabled(Experiment.example)) {
///   // treatment
/// } else {
///   // control
/// }
/// svc.logExposure(Experiment.example);
/// ```
class ABTestService {
  ABTestService({
    required List<ExperimentSpec> experiments,
    required ABTestConfig config,
  })  : _experiments = experiments,
        _config = config;

  final List<ExperimentSpec> _experiments;
  final ABTestConfig _config;

  /// 내부 상태는 [ExperimentSpec.remoteKey](문자열)로 키잉 —
  /// ExperimentSpec 구현 종류(enum/클래스)에 무관하게 동작.
  ///
  /// 로컬 랜덤 할당 결과 (true = treatment, false = control)
  final Map<String, bool> _assignments = {};

  /// Remote Config 킬스위치 상태 (true = 실험 활성, false = 강제 control)
  final Map<String, bool> _killSwitches = {};

  /// 디버그 오버라이드 (최우선)
  final Map<String, bool> _overrides = {};

  final Set<String> _exposureLogged = {};

  // prefs 키 규칙 (기존 코어 ABTestService와 호환 — 기존 설치 할당 보존).
  static String _assignmentKey(String remoteKey) => 'ab_assignment_$remoteKey';
  static String _killSwitchCacheKey(String remoteKey) =>
      'ab_killswitch_$remoteKey';
  static String _overrideKey(String remoteKey) => 'ab_override_$remoteKey';

  /// GA4 user property 키 (`_enabled` suffix 제거)
  static String _userPropertyKey(String remoteKey) =>
      'ab_${remoteKey.replaceAll('_enabled', '')}';

  /// 실험 활성 여부 반환.
  ///
  /// 우선순위: 오버라이드 > 킬스위치 > 로컬 할당
  /// - 오버라이드 있으면 → 오버라이드 값
  /// - 킬스위치 OFF (false) → 강제 control
  /// - 킬스위치 ON (true) → 로컬 할당 결과
  bool isEnabled(ExperimentSpec experiment) {
    final key = experiment.remoteKey;
    if (_overrides.containsKey(key)) {
      return _overrides[key]!;
    }
    final killSwitch = _killSwitches[key] ?? true;
    if (!killSwitch) {
      return false;
    }
    return _assignments[key] ?? false;
  }

  /// 특정 실험의 variant 문자열 반환 (`treatment` / `control`).
  String getVariant(ExperimentSpec experiment) =>
      isEnabled(experiment) ? 'treatment' : 'control';

  /// 디버그용: 실험 값을 로컬에서 강제 설정. 앱 재시작 후에도 유지.
  Future<void> setOverride(ExperimentSpec experiment, bool value) async {
    final key = experiment.remoteKey;
    _overrides[key] = value;
    _exposureLogged.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_overrideKey(key), value);
    _syncUserProperties();
  }

  /// 디버그용: 특정 실험의 오버라이드 해제.
  Future<void> clearOverride(ExperimentSpec experiment) async {
    final key = experiment.remoteKey;
    _overrides.remove(key);
    _exposureLogged.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey(key));
    _syncUserProperties();
  }

  /// 디버그용: 특정 실험에 오버라이드가 설정되어 있는지 확인.
  bool hasOverride(ExperimentSpec experiment) =>
      _overrides.containsKey(experiment.remoteKey);

  /// 앱 시작 시 호출. 로컬 할당 → 캐시 로드 → Remote Config fetch.
  ///
  /// [ABTestConfig.enabled]가 false면 no-op.
  Future<void> initialize() async {
    if (!_config.enabled) {
      logger.d('ABTestService: A/B testing disabled by config');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final random = Random();

      for (final exp in _experiments) {
        final key = exp.remoteKey;

        // 1) 로컬 할당: 이미 할당된 적 있으면 유지, 없으면 새로 할당
        final existingAssignment = prefs.getBool(_assignmentKey(key));
        if (existingAssignment != null) {
          _assignments[key] = existingAssignment;
        } else {
          final isTreatment = random.nextInt(100) < exp.trafficPercent;
          _assignments[key] = isTreatment;
          await prefs.setBool(_assignmentKey(key), isTreatment);
        }

        // 2) 킬스위치 캐시 로드 (기본 true = 활성)
        _killSwitches[key] = prefs.getBool(_killSwitchCacheKey(key)) ?? true;

        // 3) 디버그 오버라이드 복원
        final override = prefs.getBool(_overrideKey(key));
        if (override != null) {
          _overrides[key] = override;
        }
      }

      // 4) GA4 user property 설정
      _syncUserProperties();

      // 5) Remote Config fetch (논블로킹)
      if (_config.remoteConfigEnabled) {
        _fetchKillSwitches(prefs);
      }

      logger.d('ABTestService initialized (${_experiments.length} experiments)');
    } catch (e) {
      logger.e('ABTestService.initialize failed: $e');
    }
  }

  /// Remote Config에서 킬스위치 값만 가져와 캐시 갱신.
  Future<void> _fetchKillSwitches(SharedPreferences prefs) async {
    try {
      Firebase.app();
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // 기본값: 킬스위치 ON (실험 활성)
      final defaults = <String, dynamic>{};
      for (final exp in _experiments) {
        defaults[exp.remoteKey] = true;
      }
      await remoteConfig.setDefaults(defaults);

      await remoteConfig.fetchAndActivate();

      for (final exp in _experiments) {
        final killSwitch = remoteConfig.getBool(exp.remoteKey);
        _killSwitches[exp.remoteKey] = killSwitch;
        await prefs.setBool(_killSwitchCacheKey(exp.remoteKey), killSwitch);
      }

      _syncUserProperties();
    } catch (e) {
      logger.w('ABTestService._fetchKillSwitches failed: $e');
    }
  }

  /// GA4 user property로 최종 variant 전송.
  void _syncUserProperties() {
    if (!_config.analyticsEnabled && !_config.crashlyticsEnabled) {
      return;
    }

    try {
      Firebase.app();
      for (final exp in _experiments) {
        final variant = getVariant(exp);
        if (_config.analyticsEnabled) {
          FirebaseAnalytics.instance.setUserProperty(
            name: _userPropertyKey(exp.remoteKey),
            value: variant,
          );
        }
        // crash 리포트를 AB variant로 분류 (P1-14c)
        if (_config.crashlyticsEnabled) {
          FirebaseCrashlytics.instance
              .setCustomKey('ab_${exp.remoteKey}', variant);
        }
      }
    } catch (e) {
      logger.w('ABTestService._syncUserProperties failed: $e');
    }
  }

  /// 실험 노출 이벤트 기록. 세션 내 실험당 1회만 전송.
  ///
  /// 사용자가 실제로 영향받는 시점에 호출해야 한다 (분기 진입점).
  /// 자세한 원칙은 `docs/AB_TEST_LIFECYCLE.md` 참고.
  void logExposure(ExperimentSpec experiment) {
    if (!_config.analyticsEnabled) return;
    final key = experiment.remoteKey;
    if (_exposureLogged.contains(key)) return;
    _exposureLogged.add(key);

    try {
      Firebase.app();
      final analytics = FirebaseAnalytics.instance;
      analytics.logEvent(
        name: 'ab_experiment_exposure',
        parameters: {
          'experiment_name': key,
          'variant': getVariant(experiment),
        },
      );
    } catch (e) {
      logger.w('ABTestService.logExposure failed: $e');
    }
  }
}
