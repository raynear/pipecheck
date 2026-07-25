/// 로컬 알림 엔진([NotificationService]) 기능 게이트.
///
/// 패키지는 앱의 `AppFeatureConfig`에 의존하지 않는다 — 앱이 부팅 시점에
/// 플래그 값을 이 객체로 스냅샷해 `NotificationService.configure`로 주입한다.
class NotificationsConfig {
  const NotificationsConfig({
    required this.notificationEnabled,
  });

  /// 알림 전체 비활성. `configure` 전 기본값 — 엔진은 이 값으로 no-op.
  const NotificationsConfig.disabled() : notificationEnabled = false;

  /// 알림 전체 on/off (마스터 게이트). AppFeatureConfig.isNotificationEnabled.
  /// reEngagement/reminder/background 등 세부 게이트는 앱의 스케줄러가
  /// AppFeatureConfig로 직접 판단한다 (스케줄러는 앱 정책으로 잔류).
  final bool notificationEnabled;
}
