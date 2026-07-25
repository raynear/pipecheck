import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

void main() {
  // 비활성 config 경로는 AwesomeNotifications 플랫폼 채널을 건드리지 않고
  // 조기 반환하므로 단위 테스트에서 안전하게 no-op 동작을 검증할 수 있다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationsConfig', () {
    test('disabled()는 notificationEnabled false', () {
      expect(const NotificationsConfig.disabled().notificationEnabled, isFalse);
    });

    test('config 값 보존', () {
      expect(const NotificationsConfig(notificationEnabled: true).notificationEnabled, isTrue);
    });
  });

  group('NotificationService (비활성 config — 플랫폼 미접촉)', () {
    setUp(() {
      NotificationService.configure(const NotificationsConfig.disabled());
    });

    test('createNotification은 0 반환 (초기화/권한 경로 미진입)', () async {
      final id = await NotificationService().createNotification(
        id: 1,
        groupKey: 'g',
        channelKey: 'c',
        title: 't',
        body: 'b',
        scheduleTime: const TimeOfDay(hour: 9, minute: 0),
      );
      expect(id, 0);
    });

    test('isNotificationAllowed false / getAppNotifications []', () async {
      expect(await NotificationService().isNotificationAllowed(), isFalse);
      expect(await NotificationService().getAppNotifications(), isEmpty);
    });

    test('createNotificationNow / deleteNotification / pause가 throw하지 않음', () async {
      await expectLater(
          NotificationService().createNotificationNow(title: 't', body: 'b'),
          completes);
      await expectLater(NotificationService().deleteNotification(1), completes);
      await expectLater(NotificationService().pauseAppNotification(), completes);
    });

    test('권한 raw 메서드는 default 키(default group/channel)와 무관하게 존재', () {
      expect(NotificationService.defaultGroupKey, 'default');
      expect(NotificationService.defaultChannelKey, 'default');
    });
  });

  group('NotificationController', () {
    test('onNavigate 콜백 주입 가능', () {
      String? captured;
      NotificationController.onNavigate = (route) => captured = route;
      NotificationController.onNavigate?.call('/home');
      expect(captured, '/home');
      NotificationController.onNavigate = null;
    });
  });
}
