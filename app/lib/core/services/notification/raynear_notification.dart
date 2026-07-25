import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications/notifications.dart';
import 'package:notifications_fcm/notifications_fcm.dart';

import 're_engagement_scheduler.dart';
import 'reminder_scheduler.dart';

/// 애플리케이션 특화 알림 서비스 (fork 정체성).
///
/// 패키지 [NotificationService](로컬 엔진)를 상속받아 앱 특화 알림 기능을
/// 제공합니다. 재참여/리마인더/백그라운드 스케줄러(앱 정책)와 FCM 위임을
/// 소유합니다. FCM은 P2-20c PR4에서 별도 패키지로 분리 예정 — 그때까지 앱 잔류.
///
/// 싱글톤 패턴을 사용하여 앱 전체에서 하나의 인스턴스만 사용됩니다.
class RaynearNotification extends NotificationService {
  static final RaynearNotification _instance = RaynearNotification._internal();
  factory RaynearNotification() => _instance;
  RaynearNotification._internal() : super.protected();

  late final ReEngagementScheduler _reEngagementScheduler = ReEngagementScheduler(this);
  late final ReminderScheduler _reminderScheduler = ReminderScheduler(this);

  // FCM 위임 (P2-20c PR4까지 앱 잔류 — 패키지 NotificationService는 firebase-free).
  final FcmNotificationService _fcmService = FcmNotificationService();

  @override
  String get defaultIcon => 'resource://drawable/res_app_icon';

  @override
  bool? get debugMode => true;

  /// 로컬 엔진 초기화 후 FCM도 초기화한다.
  ///
  /// 과거 base.initialize()가 FCM init을 내포했으나, 패키지 엔진은 firebase-free라
  /// FCM init을 여기로 옮겼다. isInitialized(로컬 엔진이 활성+초기화됨)일 때만
  /// FCM을 초기화 — 알림 비활성 시 FCM도 건너뛰던 기존 동작 보존.
  @override
  Future<void> initialize() async {
    await super.initialize();
    if (isInitialized) {
      await _fcmService.initialize();
    }
  }

  static String get defaultGroupKey => NotificationService.defaultGroupKey;
  static String get defaultChannelKey => NotificationService.defaultChannelKey;

  String getGroupKey(int id) => 'identity_$id';
  String getChannelKey(int id) => 'habitChain_$id';

  /// 재참여 알림을 설정합니다.
  Future<void> setReEngagementNotification() =>
      _reEngagementScheduler.setReEngagementNotification();

  /// 일일 리마인더 알림을 설정합니다.
  Future<void> setReminderNotification({WidgetRef? ref}) =>
      _reminderScheduler.setReminderNotification(ref: ref);

  Future<void> deleteReminderNotification() =>
      _reminderScheduler.deleteReminderNotification();

  /// 백그라운드 알림 등록
  Future<void> registerBackgroundNotification() =>
      _reminderScheduler.registerBackgroundNotification();

  /// 백그라운드 알림 제거
  Future<void> removeBackgroundNotification() =>
      _reminderScheduler.removeBackgroundNotification();

  // ===== FCM 관련 메서드들 (FcmNotificationService에 위임 — PR4 분리 예정) =====

  /// FCM 권한 요청
  Future<bool> requestFCMPermission() => _fcmService.requestFCMPermission();

  /// 현재 FCM 권한 상태 확인
  Future<AuthorizationStatus> getFCMPermissionStatus() =>
      _fcmService.getFCMPermissionStatus();

  /// 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) =>
      _fcmService.subscribeToTopic(topic);

  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) =>
      _fcmService.unsubscribeFromTopic(topic);

  /// 배지 업데이트 (iOS)
  Future<void> updateBadgeCount(int count) =>
      _fcmService.updateBadgeCount(count);

  /// 현재 FCM 토큰 가져오기
  String? get fcmToken => _fcmService.fcmToken;

  void dispose() {
    _fcmService.dispose();
  }
}
