import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications_fcm/notifications_fcm.dart';

import 'raynear_notification.dart';

/// 앱 알림 서비스 provider — RaynearNotification(로컬 엔진 + FCM 위임) 싱글톤.
///
/// 과거 notification_controller.dart에서 `NotificationService()`를 반환했으나,
/// FCM 위임 메서드(subscribeToTopic 등)가 RaynearNotification으로 이전돼
/// 일관성을 위해 RaynearNotification을 반환한다 (provider-singleton 불일치 수정).
final notificationServiceProvider = Provider<RaynearNotification>((ref) {
  return RaynearNotification();
});

/// FCM 권한 상태 provider (PR4에서 FCM 분리 시 함께 이전 예정).
final fcmPermissionProvider = FutureProvider<AuthorizationStatus>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getFCMPermissionStatus();
});
