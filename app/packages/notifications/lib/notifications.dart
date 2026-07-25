/// 로컬 알림 엔진 (앱-무관).
///
/// 앱은 부팅 시점에 [NotificationsConfig]를 `NotificationService.configure`로
/// 주입하고, 알림 탭 네비게이션을 `NotificationController.onNavigate`로 주입한다.
/// FCM(firebase_messaging)은 이 패키지에 없다 — 앱이 소유한다.
///
/// 앱 특화 알림 정책(재참여/리마인더 스케줄러, 알림 ID, i18n 문자열)은
/// 앱에 남는다 — 이 패키지는 채널/그룹/생성/권한 프리미티브만 제공한다.
library;

export 'src/notification_controller.dart';
export 'src/notification_service.dart';
export 'src/notifications_config.dart';
