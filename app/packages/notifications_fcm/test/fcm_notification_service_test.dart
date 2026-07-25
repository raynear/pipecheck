import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_fcm/notifications_fcm.dart';

void main() {
  // 비활성 config / 미초기화(_messaging null) 경로는 플랫폼 채널을 건드리지 않고
  // 안전하게 no-op으로 동작한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmConfig', () {
    test('disabled()는 모든 플래그 false', () {
      const c = FcmConfig.disabled();
      expect(c.firebaseEnabled, isFalse);
      expect(c.messagingEnabled, isFalse);
    });

    test('config 값 보존', () {
      const c = FcmConfig(firebaseEnabled: true, messagingEnabled: true);
      expect(c.firebaseEnabled, isTrue);
      expect(c.messagingEnabled, isTrue);
    });
  });

  group('FcmNotificationService (비활성 config)', () {
    setUp(() {
      FcmNotificationService.configure(const FcmConfig.disabled());
    });

    test('비활성 시 initialize는 조기 반환 (isInitialized false)', () async {
      await FcmNotificationService().initialize();
      expect(FcmNotificationService().isInitialized, isFalse);
    });

    test('미초기화 시 토픽/배지 호출이 throw하지 않음', () async {
      await expectLater(
          FcmNotificationService().subscribeToTopic('t'), completes);
      await expectLater(
          FcmNotificationService().unsubscribeFromTopic('t'), completes);
      await expectLater(FcmNotificationService().updateBadgeCount(1), completes);
      expect(FcmNotificationService().fcmToken, isNull);
    });

    test('미초기화 시 getFCMPermissionStatus는 denied', () async {
      expect(await FcmNotificationService().getFCMPermissionStatus(),
          AuthorizationStatus.denied);
    });
  });
}
