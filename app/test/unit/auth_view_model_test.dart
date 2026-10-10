// AuthViewModel — 서버 인증 바인딩의 계약 테스트.
//
// 이 파일이 생기기 전 이 ViewModel의 커버리지는 **16%**였다. 이유는 실력이
// 아니라 배선이었다: `_emailService`/`_socialService`가 `static const`로
// 박혀 있어 테스트가 Firebase 없는 환경에서 `isFirebaseReady == false`에
// 걸렸고, 모든 메서드가 "비활성" 조기 반환으로 새 버려 성공·실패 경로에
// 아예 닿을 수 없었다. 두 서비스를 provider 주입점으로 바꾸면서(같은 PR)
// 이제 가짜를 꽂아 실제 분기를 잰다.

import 'dart:async';

import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/error_handler.dart';
import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:pipecheck/features/auth/view_models/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';

// ── 가짜들 ────────────────────────────────────────────────────────────────

/// 실제 ErrorHandler는 Crashlytics·스낵바를 건드린다. 호출 사실만 기록한다.
class _RecordingErrorHandler extends ErrorHandler {
  _RecordingErrorHandler(super.ref);

  final List<AppError> calls = [];

  @override
  Future<void> handleError(AppError error) async => calls.add(error);
}

typedef _Thrower = Object Function();

class _FakeEmailAuth extends FirebaseEmailAuthService {
  _FakeEmailAuth({
    this.ready = true,
    this.user,
    this.signInError,
    this.signUpError,
    this.resetError,
    this.signOutError,
    this.verificationSent = true,
  });

  final bool ready;
  AuthUser? user;
  final _Thrower? signInError;
  final _Thrower? signUpError;
  final _Thrower? resetError;
  final _Thrower? signOutError;
  final bool verificationSent;

  final controller = StreamController<AuthUser?>.broadcast();
  int signOutCount = 0;
  String? lastResetEmail;

  @override
  bool get isFirebaseReady => ready;

  @override
  AuthUser? get currentUser {
    return user;
  }

  @override
  Stream<AuthUser?> userChanges() => controller.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!();
    return user ??= _authUser(email: email);
  }

  @override
  Future<EmailSignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (signUpError != null) throw signUpError!();
    final created = _authUser(
      email: email,
      displayName: displayName,
      isEmailVerified: !verificationSent,
    );
    user = created;
    return (user: created, verificationSent: verificationSent);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    lastResetEmail = email;
    if (resetError != null) throw resetError!();
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (signOutError != null) throw signOutError!();
    user = null;
  }
}

class _FakeSocialAuth extends SocialAuthService {
  _FakeSocialAuth({this.ready = true, this.error});

  final bool ready;
  final _Thrower? error;
  int signOutCount = 0;

  @override
  bool get isFirebaseReady => ready;

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (error != null) throw error!();
    return _authUser(email: 'g@example.com', displayName: 'Googler');
  }

  @override
  Future<AuthUser> signInWithApple() async {
    if (error != null) throw error!();
    return _authUser(email: 'a@example.com', displayName: 'Appler');
  }

  @override
  Future<void> signOut() async => signOutCount++;
}

AuthUser _authUser({
  String uid = 'uid-1',
  String email = 'user@example.com',
  String? displayName,
  bool isEmailVerified = true,
}) =>
    AuthUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isEmailVerified: isEmailVerified,
      creationTime: DateTime.utc(2020),
    );

// ── 하네스 ────────────────────────────────────────────────────────────────

class _Harness {
  _Harness({
    _FakeEmailAuth? email,
    _FakeSocialAuth? social,
  })  : email = email ?? _FakeEmailAuth(),
        social = social ?? _FakeSocialAuth() {
    container = ProviderContainer(overrides: [
      emailAuthServiceProvider.overrideWithValue(this.email),
      socialAuthServiceProvider.overrideWithValue(this.social),
      databaseProvider.overrideWithValue(db),
      errorHandlerProvider.overrideWith((ref) {
        return errors = _RecordingErrorHandler(ref);
      }),
    ]);
  }

  final _FakeEmailAuth email;
  final _FakeSocialAuth social;
  final MemoryDb db = MemoryDb();
  late final ProviderContainer container;
  late _RecordingErrorHandler errors;

  AuthViewModel get vm => container.read(authViewModelProvider.notifier);
  AsyncValue<AuthState> get state => container.read(authViewModelProvider);

  void dispose() {
    email.controller.close();
    container.dispose();
  }
}

void main() {
  late bool origEmailFlag;
  late bool origSocialFlag;
  late bool origFirebaseFlag;

  setUp(() {
    AppFeatureConfig.applyBootConfig(profileName: 'minimal');
    origEmailFlag = AppFeatureConfig.isEmailAuthEnabled;
    origSocialFlag = AppFeatureConfig.isSocialAuthEnabled;
    origFirebaseFlag = AppFeatureConfig.isFirebaseEnabled;
    // 기본은 "서버 인증이 살아 있는 앱".
    AppFeatureConfig.isEmailAuthEnabled = true;
    AppFeatureConfig.isSocialAuthEnabled = true;
    AppFeatureConfig.isFirebaseEnabled = true;
  });

  tearDown(() {
    AppFeatureConfig.isEmailAuthEnabled = origEmailFlag;
    AppFeatureConfig.isSocialAuthEnabled = origSocialFlag;
    AppFeatureConfig.isFirebaseEnabled = origFirebaseFlag;
  });

  group('게이트 — 플래그/Firebase가 안 받쳐 주면 서버를 부르지 않는다', () {
    test('isEmailAuthEnabled=false면 로그인이 비활성 메시지로 실패한다',
        () async {
      AppFeatureConfig.isEmailAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm
          .signInWithEmail(email: 'a@b.com', password: 'pw');

      expect(r.isSuccess, isFalse);
      expect(r.message, 'auth.emailAuthDisabled');
      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('isFirebaseEnabled=false면 회원가입도 막힌다', () async {
      AppFeatureConfig.isFirebaseEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      final r =
          await h.vm.signUpWithEmail(email: 'a@b.com', password: 'pw');

      expect(r.message, 'auth.emailAuthDisabled');
    });

    test('Firebase가 초기화되지 않았으면(플래그는 켜져도) 막힌다', () async {
      final h = _Harness(email: _FakeEmailAuth(ready: false));
      addTearDown(h.dispose);

      final r = await h.vm.sendPasswordResetEmail(email: 'a@b.com');

      expect(r.message, 'auth.emailAuthDisabled');
      expect(h.email.lastResetEmail, isNull, reason: '서버를 부르면 안 된다');
    });

    test('소셜 플래그가 꺼져 있으면 Google/Apple 둘 다 비활성', () async {
      AppFeatureConfig.isSocialAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      expect((await h.vm.signInWithGoogle()).message,
          'auth.socialAuthDisabled');
      expect((await h.vm.signInWithApple()).message,
          'auth.socialAuthDisabled');
    });

    // 게이트는 플래그와 Firebase 준비 상태의 AND다 — 플래그만 재면 비대칭
    // 풋건(주석이 경고하는 그것)이 되살아나도 못 잡는다.
    test('플래그가 켜져도 Firebase가 준비 안 됐으면 소셜은 비활성', () async {
      final h = _Harness(social: _FakeSocialAuth(ready: false));
      addTearDown(h.dispose);

      expect((await h.vm.signInWithGoogle()).message,
          'auth.socialAuthDisabled');
    });
  });

  group('이메일 로그인', () {
    test('성공하면 인증 상태가 되고 로컬 DB에 사용자가 남는다', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm
          .signInWithEmail(email: 'user@example.com', password: 'pw');

      expect(r.isSuccess, isTrue);
      expect(r.user!.email, 'user@example.com');
      expect(h.state.value!.isAuthenticated, isTrue);
      expect(h.db.tables['user']!['uid-1'], isNotNull,
          reason: '로컬 영속이 인증 성공의 일부다');
    });

    test('이미 있는 사용자면 create가 아니라 update로 간다', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.db.tables['user'] = {'uid-1': {'id': 'uid-1', 'email': 'stale'}};

      await h.vm.signInWithEmail(email: 'user@example.com', password: 'pw');

      expect(h.db.tables['user']!['uid-1']!['email'], 'user@example.com');
    });

    test('AuthException은 코드별 i18n 키로 번역된다', () async {
      const cases = {
        'invalid-credential': 'auth.errorInvalidCredentials',
        'user-not-found': 'auth.errorInvalidCredentials',
        'wrong-password': 'auth.errorInvalidCredentials',
        'invalid-email': 'auth.errorInvalidEmail',
        'email-already-in-use': 'auth.errorEmailInUse',
        'weak-password': 'auth.errorWeakPassword',
        'user-disabled': 'auth.errorUserDisabled',
        'too-many-requests': 'auth.errorTooManyRequests',
        'network-request-failed': 'errors.network',
        'requires-recent-login': 'auth.errorRequiresRecentLogin',
      };

      for (final entry in cases.entries) {
        final h = _Harness(
          email: _FakeEmailAuth(
            signInError: () => AuthException(entry.key),
          ),
        );
        final r =
            await h.vm.signInWithEmail(email: 'a@b.com', password: 'pw');

        expect(r.isSuccess, isFalse);
        expect(r.message, entry.value, reason: '코드 ${entry.key}');
        expect(h.state.value!.isAuthenticated, isFalse);
        h.dispose();
      }
    });

    test('모르는 코드는 원본 메시지를 그대로 쓴다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(
          signInError: () => const AuthException('quantum-flux', 'boom'),
        ),
      );
      addTearDown(h.dispose);

      final r = await h.vm.signInWithEmail(email: 'a@b.com', password: 'pw');

      expect(r.message, 'boom');
    });

    test('AuthException이 아닌 예외는 ErrorHandler로 가고 상태가 error가 된다',
        () async {
      final h = _Harness(
        email: _FakeEmailAuth(signInError: () => StateError('네트워크 붕괴')),
      );
      addTearDown(h.dispose);

      final r = await h.vm.signInWithEmail(email: 'a@b.com', password: 'pw');

      expect(r.isSuccess, isFalse);
      expect(h.errors.calls.single.type, ErrorType.authentication);
      expect(h.state.hasError, isTrue);
    });
  });

  group('회원가입', () {
    test('인증 메일이 발송되면 requiresEmailVerification이 참이다', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm.signUpWithEmail(
          email: 'new@example.com', password: 'pw', name: '이름');

      expect(r.isSuccess, isTrue);
      expect(r.message, 'auth.signUpSuccessVerify');
      expect(r.requiresEmailVerification, isTrue);
      expect(r.user!.name, '이름');
      expect(h.state.value!.isAuthenticated, isTrue);
    });

    test('이미 검증된 계정이면 검증 요구 없이 성공 메시지', () async {
      final h = _Harness(email: _FakeEmailAuth(verificationSent: false));
      addTearDown(h.dispose);

      final r = await h.vm
          .signUpWithEmail(email: 'new@example.com', password: 'pw');

      expect(r.message, 'auth.signUpSuccess');
      expect(r.requiresEmailVerification, isFalse);
    });

    test('AuthException은 번역되고 상태는 미인증으로 돌아간다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(
          signUpError: () => const AuthException('email-already-in-use'),
        ),
      );
      addTearDown(h.dispose);

      final r =
          await h.vm.signUpWithEmail(email: 'a@b.com', password: 'pw');

      expect(r.message, 'auth.errorEmailInUse');
      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('일반 예외는 ErrorHandler로 간다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(signUpError: () => StateError('x')),
      );
      addTearDown(h.dispose);

      await h.vm.signUpWithEmail(email: 'a@b.com', password: 'pw');

      expect(h.errors.calls.single.message, 'Email sign-up failed');
    });
  });

  group('소셜 로그인', () {
    test('Google 성공 시 표시 이름이 UserModel로 넘어온다', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm.signInWithGoogle();

      expect(r.isSuccess, isTrue);
      expect(r.user!.name, 'Googler');
      expect(h.state.value!.isAuthenticated, isTrue);
    });

    test('Apple 성공', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      expect((await h.vm.signInWithApple()).user!.name, 'Appler');
    });

    test('AuthException은 번역된다', () async {
      final h = _Harness(
        social: _FakeSocialAuth(
          error: () => const AuthException('too-many-requests'),
        ),
      );
      addTearDown(h.dispose);

      expect((await h.vm.signInWithGoogle()).message,
          'auth.errorTooManyRequests');
      expect((await h.vm.signInWithApple()).message,
          'auth.errorTooManyRequests');
    });

    test('일반 예외는 각자의 진단 메시지로 ErrorHandler에 간다', () async {
      final h = _Harness(
        social: _FakeSocialAuth(error: () => StateError('x')),
      );
      addTearDown(h.dispose);

      await h.vm.signInWithGoogle();
      await h.vm.signInWithApple();

      expect(h.errors.calls.map((e) => e.message),
          ['Google sign-in failed', 'Apple sign-in failed']);
    });
  });

  group('비밀번호 재설정', () {
    test('성공', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm.sendPasswordResetEmail(email: 'a@b.com');

      expect(r.isSuccess, isTrue);
      expect(r.message, 'auth.passwordResetSent');
      expect(h.email.lastResetEmail, 'a@b.com');
    });

    test('AuthException은 번역된다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(
          resetError: () => const AuthException('invalid-email'),
        ),
      );
      addTearDown(h.dispose);

      expect((await h.vm.sendPasswordResetEmail(email: 'a')).message,
          'auth.errorInvalidEmail');
    });

    test('일반 예외는 발송 실패 키로 떨어진다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(resetError: () => StateError('x')),
      );
      addTearDown(h.dispose);

      expect((await h.vm.sendPasswordResetEmail(email: 'a')).message,
          'auth.emailSendFailed');
    });
  });

  group('로그아웃', () {
    test('이메일·소셜 세션을 모두 정리하고 미인증이 된다', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.vm.signOut();

      expect(h.email.signOutCount, 1);
      expect(h.social.signOutCount, 1);
      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('소셜을 안 쓰는 앱은 소셜 로그아웃을 부르지 않는다', () async {
      AppFeatureConfig.isSocialAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      await h.vm.signOut();

      expect(h.email.signOutCount, 1);
      expect(h.social.signOutCount, 0);
    });

    test('실패하면 ErrorHandler로 가고 상태가 error가 된다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(signOutError: () => StateError('x')),
      );
      addTearDown(h.dispose);

      await h.vm.signOut();

      expect(h.errors.calls.single.message, 'Sign-out failed');
      expect(h.state.hasError, isTrue);
    });
  });

  group('현재 사용자 새로고침', () {
    test('서버 세션이 살아 있으면 그걸로 복원한다', () async {
      final h = _Harness(email: _FakeEmailAuth(user: _authUser()));
      addTearDown(h.dispose);

      await h.vm.refreshCurrentUser();

      expect(h.state.value!.user!.id, 'uid-1');
    });

    test('서버 세션이 없으면 로컬 DB에서 찾는다', () async {
      AppFeatureConfig.isEmailAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);
      h.db.tables['user'] = {
        '1': {
          'id': '1',
          'email': 'local@example.com',
          'name': 'Local',
          'isEmailVerified': false,
          'createdAt': DateTime.utc(2021).toIso8601String(),
          'lastLoginAt': DateTime.utc(2021).toIso8601String(),
        }
      };

      await h.vm.refreshCurrentUser();

      expect(h.state.value!.isAuthenticated, isTrue);
      expect(h.state.value!.user!.email, 'local@example.com');
    });

    test('어디에도 없으면 미인증', () async {
      AppFeatureConfig.isEmailAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      await h.vm.refreshCurrentUser();

      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('실패해도 상태를 뒤엎지 않는다 — 에러만 보고한다', () async {
      AppFeatureConfig.isEmailAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);
      h.db.failReads = true;

      final before = h.state;
      await h.vm.refreshCurrentUser();

      expect(h.errors.calls.single.message, 'Failed to load user info');
      expect(h.state.value!.isAuthenticated, before.value!.isAuthenticated,
          reason: '주석이 "현재 상태 유지"라고 약속한다');
    });
  });

  group('build — 세션 복원과 원격 로그아웃', () {



    test('스트림이 null을 뱉으면(세션 만료) 로컬 상태가 정리된다', () async {
      final h = _Harness(email: _FakeEmailAuth(user: _authUser()));
      addTearDown(h.dispose);

      h.vm;
      await Future<void>.delayed(Duration.zero);
      h.email.controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('스트림 에러도 미인증으로 떨어뜨린다', () async {
      final h = _Harness(email: _FakeEmailAuth(user: _authUser()));
      addTearDown(h.dispose);

      h.vm;
      await Future<void>.delayed(Duration.zero);
      h.email.controller.addError(StateError('세션 붕괴'));
      await Future<void>.delayed(Duration.zero);

      expect(h.state.value!.isAuthenticated, isFalse);
    });

    test('서버 인증을 안 쓰는 앱은 스트림을 구독하지 않는다', () async {
      AppFeatureConfig.isEmailAuthEnabled = false;
      final h = _Harness();
      addTearDown(h.dispose);

      h.vm;
      await Future<void>.delayed(Duration.zero);

      expect(h.email.controller.hasListener, isFalse);
      expect(h.state.value!.isLoading, isTrue, reason: 'initial 그대로');
    });
  });

  group('AuthUser → UserModel 매핑', () {
    test('표시 이름이 없으면 이메일 로컬파트를 쓴다', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final r = await h.vm
          .signInWithEmail(email: 'gil.dong@example.com', password: 'pw');

      expect(r.user!.name, 'gil.dong');
    });

    test('이메일마저 비어 있으면 "User"로 떨어진다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(user: _authUser(email: '')),
      );
      addTearDown(h.dispose);

      final r = await h.vm.signInWithEmail(email: '', password: 'pw');

      expect(r.user!.name, 'User');
    });
  });

  group('파생 provider', () {
    test('currentAuthUserProvider / isAuthenticatedProvider가 상태를 따른다',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);

      expect(h.container.read(isAuthenticatedProvider), isFalse);
      expect(h.container.read(currentAuthUserProvider), isNull);

      await h.vm.signInWithEmail(email: 'a@b.com', password: 'pw');

      expect(h.container.read(isAuthenticatedProvider), isTrue);
      expect(h.container.read(currentAuthUserProvider)!.email, 'a@b.com');
    });

    test('로딩·에러 상태에서는 미인증으로 읽힌다', () async {
      final h = _Harness(
        email: _FakeEmailAuth(signInError: () => StateError('x')),
      );
      addTearDown(h.dispose);

      await h.vm.signInWithEmail(email: 'a@b.com', password: 'pw');

      expect(h.container.read(isAuthenticatedProvider), isFalse);
      expect(h.container.read(currentAuthUserProvider), isNull);
    });
  });
}
