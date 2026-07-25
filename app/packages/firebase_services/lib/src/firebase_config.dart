/// Firebase 엔진([FirebaseService] · [CrashReporter]) 기능 게이트.
///
/// 패키지는 앱의 `AppFeatureConfig`에 의존하지 않는다 — 앱이 부팅 시점에
/// 자신의 플래그 값을 이 객체로 스냅샷해 `configure`로 주입한다.
class FirebaseServicesConfig {
  const FirebaseServicesConfig({
    required this.firebaseEnabled,
    required this.analyticsEnabled,
    required this.crashlyticsEnabled,
  });

  /// 모든 기능이 꺼진 기본값. `configure` 전에는 엔진이 이 값으로 동작해
  /// 항상 no-op이다.
  const FirebaseServicesConfig.disabled()
      : firebaseEnabled = false,
        analyticsEnabled = false,
        crashlyticsEnabled = false;

  /// Firebase 전체 on/off. false면 Analytics·Crashlytics 모두 no-op.
  final bool firebaseEnabled;

  /// Analytics 이벤트/동의/화면뷰 전송 여부.
  final bool analyticsEnabled;

  /// Crashlytics 에러 리포트/커스텀 키 설정 여부.
  final bool crashlyticsEnabled;
}
