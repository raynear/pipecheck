/// [ABTestService] 기능 게이트. 앱의 기능 플래그를 주입받는다.
///
/// 패키지는 앱의 `AppFeatureConfig`에 의존하지 않는다 — 앱이 부팅 시점에
/// 자신의 플래그 값을 이 객체로 스냅샷해 서비스에 주입한다.
class ABTestConfig {
  const ABTestConfig({
    required this.enabled,
    required this.remoteConfigEnabled,
    required this.analyticsEnabled,
    required this.crashlyticsEnabled,
  });

  /// A/B 테스팅 전체 on/off. false면 [ABTestService.initialize]는 no-op이며
  /// 모든 실험은 control로 동작한다.
  final bool enabled;

  /// Remote Config 킬스위치 fetch 여부. false면 로컬 할당만 사용.
  final bool remoteConfigEnabled;

  /// GA4 user property + 노출 이벤트 전송 여부.
  final bool analyticsEnabled;

  /// Crashlytics custom key(variant 분류) 설정 여부.
  final bool crashlyticsEnabled;
}
