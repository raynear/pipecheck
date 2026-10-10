// AuthStateNotifier의 인증 수행 메서드 — 플래그가 꺼진/플랫폼이 없는 환경에서의 계약.
//
// 재잠금 API는 auth_state_relock_test.dart가 잠근다. 여기는 나머지 공개 메서드가
// 성공/실패 상태를 올바르게 남기는지(실패가 인증됨으로 새지 않는지)를 본다.

import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAccount extends FirebaseEmailAuthService {
  _FakeAccount({this.user, this.error});
  final AuthUser? user;
  final Object? error;
  int deleteCount = 0;

  @override
  bool get isFirebaseReady => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<void> deleteCurrentUser() async {
    deleteCount++;
    if (error != null) throw error!;
  }
}

const _user = AuthUser(uid: 'u1', email: 'a@b.c', isEmailVerified: true);

void main() {
  late Map<String, bool> saved;

  setUp(() => saved = AppFeatureConfig.toMap());
  tearDown(() => AppFeatureConfig.fromMap(saved));

  ProviderContainer make() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('인증 기능이 꺼져 있으면 PIN 인증은 통과하고 method=pin', () async {
    AppFeatureConfig.isAuthenticationEnabled = false;
    final container = make();

    final ok = await container
        .read(authStateProvider.notifier)
        .authenticateWithPin();

    expect(ok, isTrue);
    expect(container.read(authStateProvider).method, AuthMethod.pin);
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
  });

  test('생체 인증 기능이 꺼져 있으면 method=none 으로 인증된다', () async {
    AppFeatureConfig.isBiometricAuthEnabled = false;
    final container = make();

    final ok = await container
        .read(authStateProvider.notifier)
        .authenticateWithBiometrics();

    expect(ok, isTrue);
    expect(container.read(authStateProvider).method, AuthMethod.none);
  });

  test('플랫폼 인증이 실패하거나 던지면 인증됨으로 새지 않는다 (PIN)', () async {
    AppFeatureConfig.isAuthenticationEnabled = true;
    final container = make();

    final ok = await container
        .read(authStateProvider.notifier)
        .authenticateWithPin();

    expect(ok, isFalse, reason: '테스트 환경에는 local_auth 플랫폼이 없다');
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
    expect(container.read(authStateProvider).errorMessage, isNotNull);
  });

  test('플랫폼 인증이 실패하거나 던지면 인증됨으로 새지 않는다 (생체)', () async {
    AppFeatureConfig.isAuthenticationEnabled = true;
    AppFeatureConfig.isBiometricAuthEnabled = true;
    final container = make();

    final ok = await container
        .read(authStateProvider.notifier)
        .authenticateWithBiometrics();

    expect(ok, isFalse);
    expect(container.read(authStateProvider).isAuthenticated, isFalse);
    expect(container.read(authStateProvider).errorMessage, isNotNull);
  });

  test('계정 삭제는 기능이 꺼져 있거나 Firebase가 없으면 false', () async {
    AppFeatureConfig.isAccountDeletionEnabled = true;
    AppFeatureConfig.isFirebaseEnabled = true; // 플래그만 켜짐, 앱은 미초기화
    final container = make();

    expect(
      await container.read(authStateProvider.notifier).deleteAccount(),
      isFalse,
    );

    AppFeatureConfig.isAccountDeletionEnabled = false;
    expect(
      await container.read(authStateProvider.notifier).deleteAccount(),
      isFalse,
    );
  });

  test('signOut은 인증됨 상태를 build 재유도 값으로 되돌린다', () async {
    AppFeatureConfig.isAuthenticationEnabled = true;
    final container = make();
    final auth = container.read(authStateProvider.notifier);
    auth.setAuthState(AuthState.authenticated(method: AuthMethod.pin));

    await auth.signOut();

    expect(container.read(authStateProvider).method, isNot(AuthMethod.pin));
  });

  group('계정 삭제 (Firebase 준비됨)', () {
    late ProviderContainer container;
    late AuthStateNotifier auth;

    Future<bool> run(_FakeAccount fake) {
      AppFeatureConfig.isAccountDeletionEnabled = true;
      AppFeatureConfig.isFirebaseEnabled = true;
      container = make();
      auth = container.read(authStateProvider.notifier)..emailService = fake;
      return auth.deleteAccount();
    }

    test('성공하면 true, 서버 계정 삭제를 한 번 호출한다', () async {
      final fake = _FakeAccount(user: _user);
      expect(await run(fake), isTrue);
      expect(fake.deleteCount, 1);
    });

    test('로그인된 계정이 없으면 삭제를 시도하지 않고 false', () async {
      final fake = _FakeAccount();
      expect(await run(fake), isFalse);
      expect(fake.deleteCount, 0);
    });

    test('requires-recent-login 이면 false + 안내 메시지', () async {
      final fake = _FakeAccount(
        user: _user,
        error: const AuthException('requires-recent-login', 'x'),
      );
      expect(await run(fake), isFalse);
      expect(container.read(authStateProvider).errorMessage, isNotNull);
    });

    test('그 밖의 AuthException·예외도 false', () async {
      expect(
        await run(
          _FakeAccount(user: _user, error: const AuthException('boom', 'x')),
        ),
        isFalse,
      );
      expect(
        await run(_FakeAccount(user: _user, error: StateError('x'))),
        isFalse,
      );
    });
  });
}
