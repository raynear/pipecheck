import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthUser', () {
    test('필드를 그대로 보존한다', () {
      final created = DateTime(2024, 1, 2);
      const user = AuthUser(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        isEmailVerified: true,
      );
      expect(user.uid, 'u1');
      expect(user.email, 'a@b.com');
      expect(user.displayName, 'Alice');
      expect(user.isEmailVerified, isTrue);

      final withDate = AuthUser(
        uid: 'u2',
        email: 'c@d.com',
        isEmailVerified: false,
        creationTime: created,
      );
      expect(withDate.displayName, isNull);
      expect(withDate.creationTime, created);
    });
  });

  group('AuthException', () {
    test('code/message를 노출하고 toString에 포함한다', () {
      const e = AuthException('wrong-password', 'bad creds');
      expect(e.code, 'wrong-password');
      expect(e.message, 'bad creds');
      expect(e.toString(), contains('wrong-password'));
      expect(e.toString(), contains('bad creds'));
    });

    test('message는 선택', () {
      const e = AuthException('network-request-failed');
      expect(e.code, 'network-request-failed');
      expect(e.message, isNull);
    });
  });

  group('FirebaseEmailAuthService', () {
    test('Firebase 미초기화 시 isFirebaseReady=false (앱 게이트의 AND 항)', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      const service = FirebaseEmailAuthService();
      // 테스트 환경엔 Firebase 앱이 없다 → 앱 바인딩의 게이트가 차단된다.
      expect(service.isFirebaseReady, isFalse);
    });
  });

  group('SocialAuthService', () {
    test('Firebase 미초기화 시 isFirebaseReady=false (앱 게이트의 AND 항)', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      const service = SocialAuthService();
      expect(service.isFirebaseReady, isFalse);
    });

    test('configureGoogle은 throw하지 않음 (포크 OAuth 자격증명 주입)', () {
      expect(
        () => SocialAuthService.configureGoogle(clientId: null, serverClientId: null),
        returnsNormally,
      );
    });
  });
}
