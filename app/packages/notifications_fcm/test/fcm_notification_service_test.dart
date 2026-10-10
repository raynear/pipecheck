import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_fcm/notifications_fcm.dart';

/// APNs 토큰이 영영 오지 않는 iOS 기기 흉내. 쓰는 멤버만 구현한다.
class _FakeMessaging extends Fake implements FirebaseMessaging {
  int apnsReads = 0;

  /// 설정하면 getAPNSToken이 이 completer가 끝날 때까지 대기한다.
  Completer<void>? apnsGate;
  final tokenRefresh = StreamController<String>.broadcast();

  @override
  Future<String?> getAPNSToken() async {
    apnsReads++;
    await apnsGate?.future;
    return null;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;
}

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

  group('FcmNotificationService (APNs 재시도·구독 수명)', () {
    late _FakeMessaging messaging;
    late FcmNotificationService service;

    setUp(() {
      messaging = _FakeMessaging();
      service = FcmNotificationService();
      service.debugAttach(messaging, isIOS: true, apnsRetryBaseDelay: Duration.zero);
    });

    tearDown(() {
      service.dispose();
    });

    test('APNs 토큰이 계속 없어도 재시도는 상한(처음 1 + 재시도 5)에서 멈춘다', () async {
      await service.debugFetchToken();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(messaging.apnsReads, 6);
    });

    test('재시도 간격은 지수적으로 늘어난다', () {
      expect(FcmNotificationService.apnsRetryDelay(const Duration(seconds: 5), 0), const Duration(seconds: 5));
      expect(FcmNotificationService.apnsRetryDelay(const Duration(seconds: 5), 1), const Duration(seconds: 10));
      expect(FcmNotificationService.apnsRetryDelay(const Duration(seconds: 5), 3), const Duration(seconds: 40));
    });

    test('dispose하면 대기 중인 재시도가 취소된다', () async {
      service.debugAttach(messaging, isIOS: true, apnsRetryBaseDelay: const Duration(milliseconds: 30));
      await service.debugFetchToken(); // 1회 읽고 30ms 뒤 재시도 예약
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(messaging.apnsReads, 1);
    });

    test('getAPNSToken을 기다리는 중에 dispose하면 재시도 읽기가 더 일어나지 않는다 (apnsReads 1 유지)', () async {
      service.debugAttach(messaging, isIOS: true, apnsRetryBaseDelay: const Duration(milliseconds: 10));
      messaging.apnsGate = Completer<void>();
      final fetch = service.debugFetchToken(); // getAPNSToken 대기 중
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.dispose();
      messaging.apnsGate!.complete(); // 토큰 없음으로 풀림 → 예전엔 여기서 재시도 예약
      await fetch;
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(messaging.apnsReads, 1);
    });

    test('onTokenRefresh 구독은 dispose에서 해제되고, 재등록해도 하나만 남는다', () async {
      service.debugListenTokenRefresh();
      service.debugListenTokenRefresh();
      expect(messaging.tokenRefresh.hasListener, isTrue);

      service.dispose();
      expect(messaging.tokenRefresh.hasListener, isFalse);
    });
  });
}
