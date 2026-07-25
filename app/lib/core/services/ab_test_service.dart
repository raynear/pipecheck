import 'package:ab_testing/ab_testing.dart';

import '../../config/app_feature_config.dart';

/// A/B 테스트 실험 정의 (앱 실험 레지스트리).
///
/// [remoteKey]는 Firebase Remote Config 킬스위치 키.
/// Remote Config가 `false`이면 실험 강제 비활성 (킬스위치).
/// Remote Config가 `true`이면 로컬 랜덤 할당 결과를 따름.
/// [trafficPercent]는 treatment 그룹 비율 (0–100).
///
/// 이 `Experiment` enum이 앱-측 실험 정의 SSOT다 — 엔진은 [remoteKey]를
/// Remote Config 킬스위치 키로 읽는다. (선택) Firebase A/B Testing 콘솔 흐름은
/// `fastlane/config/ab_experiments.yml`을 사용한다.
///
/// A/B 엔진은 `package:ab_testing`(앱-무관)이 제공한다 — 이 enum이
/// [ExperimentSpec]를 구현해 엔진에 주입된다 ([abTestService] 참조).
enum Experiment implements ExperimentSpec {
  /// 예시 항목 — 실제 실험으로 교체하고 이 주석 제거
  example('example_feature_enabled', 50);

  const Experiment(this.remoteKey, this.trafficPercent);

  @override
  final String remoteKey;
  @override
  final int trafficPercent;
}

/// 앱 전역 A/B 서비스 인스턴스.
///
/// top-level final = lazy: 부팅 설정([applyBootConfig])으로 기능 플래그가
/// 확정된 뒤 첫 접근(보통 [ABTestService.initialize])에서 1회 구성된다.
/// 따라서 [AppFeatureConfig] 플래그 스냅샷이 부팅 후 값으로 고정된다.
///
/// 사용 예시:
/// ```dart
/// await abTestService.initialize();
///
/// if (abTestService.isEnabled(Experiment.example)) {
///   // treatment
/// }
/// abTestService.logExposure(Experiment.example);
/// ```
///
/// 자세한 운영 가이드는 `docs/AB_TEST_GUIDE.md` 참고.
final ABTestService abTestService = ABTestService(
  experiments: Experiment.values,
  config: ABTestConfig(
    enabled: AppFeatureConfig.isABTestingEnabled,
    remoteConfigEnabled: AppFeatureConfig.isFirebaseRemoteConfigEnabled,
    analyticsEnabled: AppFeatureConfig.isFirebaseAnalyticsEnabled,
    crashlyticsEnabled: AppFeatureConfig.isFirebaseCrashlyticsEnabled,
  ),
);
