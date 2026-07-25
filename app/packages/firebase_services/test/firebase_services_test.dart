import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/foundation.dart' show FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Firebase를 초기화하지 않은 환경에서 엔진이 안전하게 no-op으로
  // 동작하는지 검증한다 (가드 계약). 어떤 호출도 throw하지 않아야 한다.

  group('FirebaseServicesConfig', () {
    test('disabled()는 모든 플래그가 false', () {
      const config = FirebaseServicesConfig.disabled();
      expect(config.firebaseEnabled, isFalse);
      expect(config.analyticsEnabled, isFalse);
      expect(config.crashlyticsEnabled, isFalse);
    });
  });

  group('FirebaseService (Analytics)', () {
    test('configure 전(disabled 기본)에는 Analytics 사용 불가', () {
      FirebaseService.configure(const FirebaseServicesConfig.disabled());
      expect(FirebaseService.isAnalyticsAvailable, isFalse);
    });

    test('플래그를 켜도 Firebase 미초기화면 사용 불가 (가드)', () {
      FirebaseService.configure(const FirebaseServicesConfig(
        firebaseEnabled: true,
        analyticsEnabled: true,
        crashlyticsEnabled: true,
      ));
      // Firebase.initializeApp을 호출하지 않았으므로 isInitialized가 false.
      expect(FirebaseService.isAnalyticsAvailable, isFalse);
    });

    test('사용 불가 상태에서 로깅/설정 호출이 throw하지 않음', () async {
      FirebaseService.configure(const FirebaseServicesConfig.disabled());
      expect(
        () => FirebaseService.logEvent(name: 'x', parameters: {'a': 1}),
        returnsNormally,
      );
      expect(
        () => FirebaseService.logScreenView(screenName: 'X'),
        returnsNormally,
      );
      await expectLater(
        FirebaseService.setConsent(
          analyticsStorageConsentGranted: true,
          adStorageConsentGranted: true,
        ),
        completes,
      );
      await expectLater(
          FirebaseService.setAnalyticsCollectionEnabled(true), completes);
      await expectLater(
          FirebaseService.setSessionTimeoutDuration(
              const Duration(minutes: 30)),
          completes);
      await expectLater(
          FirebaseService.setUserProperty(name: 'k', value: 'v'), completes);
    });

    test('비활성화 시 navigatorObserver는 null', () {
      FirebaseService.configure(const FirebaseServicesConfig.disabled());
      expect(FirebaseService.navigatorObserver, isNull);
    });
  });

  group('CrashReporter', () {
    test('configure 전·비활성화에서 리포트 호출이 throw하지 않음', () async {
      CrashReporter.configure(const FirebaseServicesConfig.disabled());
      await expectLater(
        CrashReporter.recordError(Exception('boom'), StackTrace.current,
            reason: 'test', fatal: true),
        completes,
      );
      expect(
        () => CrashReporter.recordFlutterError(
          FlutterErrorDetails(exception: Exception('flutter boom')),
        ),
        returnsNormally,
      );
      await expectLater(CrashReporter.setCollectionEnabled(true), completes);
      await expectLater(CrashReporter.setCustomKey('flavor', 'debug'), completes);
    });
  });

  group('RemoteConfigService', () {
    test('instance는 싱글턴', () {
      expect(
          identical(RemoteConfigService.instance, RemoteConfigService.instance),
          isTrue);
    });
  });
}
