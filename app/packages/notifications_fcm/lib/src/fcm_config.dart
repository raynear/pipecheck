/// FCM 알림 엔진([FcmNotificationService]) 기능 게이트.
///
/// 패키지는 앱의 `AppFeatureConfig`에 의존하지 않는다 — 앱이 부팅 시점에
/// 플래그 값을 이 객체로 스냅샷해 `FcmNotificationService.configure`로 주입한다.
class FcmConfig {
  const FcmConfig({
    required this.firebaseEnabled,
    required this.messagingEnabled,
  });

  /// 모든 기능 비활성. `configure` 전 기본값 — 엔진은 이 값으로 no-op.
  const FcmConfig.disabled()
      : firebaseEnabled = false,
        messagingEnabled = false;

  /// Firebase 전체 on/off. AppFeatureConfig.isFirebaseEnabled.
  final bool firebaseEnabled;

  /// FCM 메시징 on/off. AppFeatureConfig.isFirebaseMessagingEnabled.
  final bool messagingEnabled;
}
