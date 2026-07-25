import 'package:biometric_auth/biometric_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Authentication (biometric)', () {
    test('싱글톤', () {
      expect(identical(Authentication(), Authentication()), isTrue);
    });

    test('초기 상태 기본값 (플랫폼 호출 전)', () {
      final a = Authentication();
      expect(a.supportState, SupportState.unknown);
      expect(a.authorized, AuthorizeState.notAuthorized);
      expect(a.isAuthenticating, isFalse);
    });
  });

  group('enums', () {
    test('SupportState 값 노출', () {
      expect(SupportState.values,
          containsAll([SupportState.unknown, SupportState.supported, SupportState.unsupported]));
    });

    test('AuthorizeState 값 노출', () {
      expect(AuthorizeState.values,
          containsAll([AuthorizeState.authorized, AuthorizeState.notAuthorized, AuthorizeState.error]));
    });
  });
}
