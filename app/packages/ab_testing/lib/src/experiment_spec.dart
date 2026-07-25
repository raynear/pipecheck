/// A/B 실험 정의 계약. 앱이 자신의 실험 레지스트리(enum 등)로 구현한다.
///
/// 패키지는 어떤 앱에도 의존하지 않으므로 실험 목록은 이 인터페이스를 통해
/// 주입받는다. 앱의 `Experiment` enum이 `implements ExperimentSpec`로 구현한다.
///
/// - [remoteKey]: Firebase Remote Config 킬스위치 키이자 GA4/prefs 키의 기준.
/// - [trafficPercent]: treatment 그룹 비율 (0–100).
abstract interface class ExperimentSpec {
  /// Remote Config 킬스위치 키 (예: `example_feature_enabled`).
  String get remoteKey;

  /// treatment 그룹 비율 (0–100).
  int get trafficPercent;
}
