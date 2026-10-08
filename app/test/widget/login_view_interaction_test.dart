// LoginView — 폼 상호작용 계약.
//
// 화면이 그려지는지가 아니라 **눌렀을 때 무슨 일이 일어나는지**를 잰다:
// 검증이 서버 호출을 막는가, 성공하면 어디로 가는가, 실패 메시지가 사용자에게
// 닿는가. `AuthViewModel`은 provider 주입점(emailAuthServiceProvider)으로
// 가짜 인증 엔진을 꽂아 실제 코드 경로를 그대로 태운다.

import 'dart:async';

import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/widgets/buttons/adaptive_button.dart';
import 'package:pipecheck/features/auth/view_models/auth_view_model.dart';
import 'package:pipecheck/features/auth/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipecheck/data/core/repositories/repository_providers.dart';
import 'package:go_router/go_router.dart';

import '../support/memory_database.dart';

class _FakeEmailAuth extends FirebaseEmailAuthService {
  _FakeEmailAuth({this.signInError, this.resetError});

  final Object Function()? signInError;
  final Object Function()? resetError;

  final signInCalls = <String>[];
  final signUpCalls = <String>[];
  final resetCalls = <String>[];

  @override
  bool get isFirebaseReady => true;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> userChanges() => const Stream.empty();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls.add(email);
    if (signInError != null) throw signInError!();
    return _user(email);
  }

  @override
  Future<EmailSignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    signUpCalls.add(email);
    return (user: _user(email, verified: false), verificationSent: true);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCalls.add(email);
    if (resetError != null) throw resetError!();
  }

  AuthUser _user(String email, {bool verified = true}) => AuthUser(
        uid: 'uid-1',
        email: email,
        isEmailVerified: verified,
        creationTime: DateTime.utc(2020),
      );
}

void main() {
  late bool origEmail;
  late bool origFirebase;
  late bool origSocial;

  setUp(() {
    AppFeatureConfig.applyBootConfig(profileName: 'minimal');
    origEmail = AppFeatureConfig.isEmailAuthEnabled;
    origFirebase = AppFeatureConfig.isFirebaseEnabled;
    origSocial = AppFeatureConfig.isSocialAuthEnabled;
    AppFeatureConfig.isEmailAuthEnabled = true;
    AppFeatureConfig.isFirebaseEnabled = true;
  });

  tearDown(() {
    AppFeatureConfig.isEmailAuthEnabled = origEmail;
    AppFeatureConfig.isFirebaseEnabled = origFirebase;
    AppFeatureConfig.isSocialAuthEnabled = origSocial;
  });

  /// LoginView를 라우터 위에 띄운다 — 성공 경로가 `context.go('/home')`를
  /// 부르므로 GoRouter 조상이 없으면 그 줄에서 터진다.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _FakeEmailAuth email,
  ) async {
    final container = ProviderContainer(overrides: [
      emailAuthServiceProvider.overrideWithValue(email),
      // 실제 DriftDatabase를 쓰면 플랫폼 채널이 없어 비동기로 터진다.
      databaseProvider.overrideWithValue(MemoryDb()),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// 로딩 스피너(무한 애니메이션)가 도는 동안 `pumpAndSettle`은 영영 안 끝난다.
  /// 고정 프레임 수로 흘려보낸다.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 스크롤 밖에 있는 위젯은 탭이 빗나간다 — 보이게 한 뒤 누른다.
  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  List<String> messages(ProviderContainer c) =>
      c.read(snackBarProvider).map((s) => s.message).toList();

  // easy_localization 미초기화 위젯 테스트에서는 키가 그대로 그려진다.
  final emailField = find.widgetWithText(TextFormField, 'login.emailLabel');
  final passwordField =
      find.widgetWithText(TextFormField, 'login.passwordLabel');
  // AdaptiveButton은 플랫폼별로 다른 버튼을 그린다(ElevatedButton이 아니다) —
  // 래퍼 자체를 겨냥해야 플랫폼과 무관하게 잡힌다.
  final submitButton = find.widgetWithText(AdaptiveButton, 'login.signIn');

  Future<void> fill(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.pump();
  }

  group('로그인', () {
    testWidgets('성공하면 홈으로 이동하고 성공 메시지가 뜬다', (tester) async {
      final auth = _FakeEmailAuth();
      final c = await pump(tester, auth);

      await fill(tester, email: 'user@example.com', password: 'secret1');
      await tapVisible(tester, submitButton);

      expect(auth.signInCalls, ['user@example.com']);
      expect(find.text('HOME'), findsOneWidget);
      expect(messages(c), contains('login.signInSuccess'));
    });

    testWidgets('실패하면 화면에 남고 에러 메시지가 뜬다', (tester) async {
      final auth = _FakeEmailAuth(
        signInError: () => const AuthException('wrong-password'),
      );
      final c = await pump(tester, auth);

      await fill(tester, email: 'user@example.com', password: 'nope');
      await tapVisible(tester, submitButton);

      expect(find.text('HOME'), findsNothing);
      expect(messages(c), contains('auth.errorInvalidCredentials'));
    });

    testWidgets('이메일 형식이 틀리면 서버를 부르지 않는다', (tester) async {
      final auth = _FakeEmailAuth();
      await pump(tester, auth);

      await fill(tester, email: 'not-an-email', password: 'secret1');
      await tapVisible(tester, submitButton);

      expect(auth.signInCalls, isEmpty,
          reason: '폼 검증이 신뢰 경계다 — 통과시키면 서버가 대신 막아야 한다');
    });

    testWidgets('비밀번호가 비어 있어도 서버를 부르지 않는다', (tester) async {
      final auth = _FakeEmailAuth();
      await pump(tester, auth);

      await fill(tester, email: 'user@example.com', password: '');
      await tapVisible(tester, submitButton);

      expect(auth.signInCalls, isEmpty);
    });
  });

  group('회원가입 모드', () {
    testWidgets('전환하면 비밀번호 확인 필드가 생기고, 불일치면 막힌다',
        (tester) async {
      final auth = _FakeEmailAuth();
      await pump(tester, auth);

      await tapVisible(
          tester, find.widgetWithText(OutlinedButton, 'login.switchToSignUp'));

      final confirmField =
          find.widgetWithText(TextFormField, 'login.confirmPasswordLabel');
      expect(confirmField, findsOneWidget);

      await fill(tester, email: 'new@example.com', password: 'secret1');
      await tester.enterText(confirmField, 'different');
      await tester.pump();
      await tapVisible(
          tester, find.widgetWithText(AdaptiveButton, 'login.signUp'));

      expect(auth.signUpCalls, isEmpty);
    });

  });

  group('비밀번호 찾기', () {
    Future<void> tapForgot(WidgetTester tester) async {
      await tapVisible(
          tester, find.widgetWithText(TextButton, 'login.forgotPassword'));
    }

    testWidgets('이메일이 비어 있으면 입력을 요구한다', (tester) async {
      final auth = _FakeEmailAuth();
      final c = await pump(tester, auth);

      await tapForgot(tester);

      expect(auth.resetCalls, isEmpty);
      expect(messages(c), contains('login.enterEmail'));
    });

    testWidgets('형식이 틀리면 올바른 이메일을 요구한다', (tester) async {
      final auth = _FakeEmailAuth();
      final c = await pump(tester, auth);

      await tester.enterText(emailField, 'nope');
      await tapForgot(tester);

      expect(auth.resetCalls, isEmpty);
      expect(messages(c), contains('login.enterValidEmail'));
    });

    testWidgets('정상 이메일이면 재설정 메일을 보낸다', (tester) async {
      final auth = _FakeEmailAuth();
      final c = await pump(tester, auth);

      await tester.enterText(emailField, 'user@example.com');
      await tapForgot(tester);

      expect(auth.resetCalls, ['user@example.com']);
      expect(messages(c), contains('auth.passwordResetSent'));
    });

    testWidgets('서버가 거절하면 그 이유가 사용자에게 닿는다', (tester) async {
      final auth = _FakeEmailAuth(
        resetError: () => const AuthException('user-not-found'),
      );
      final c = await pump(tester, auth);

      await tester.enterText(emailField, 'ghost@example.com');
      await tapForgot(tester);

      expect(messages(c), contains('auth.errorInvalidCredentials'));
    });
  });

  testWidgets('눈 아이콘이 비밀번호 가림을 토글한다', (tester) async {
    await pump(tester, _FakeEmailAuth());

    TextField field() => tester.widget<TextField>(
          find.descendant(of: passwordField, matching: find.byType(TextField)),
        );

    expect(field().obscureText, isTrue);
    await tapVisible(tester, find.byIcon(Icons.visibility_outlined));
    expect(field().obscureText, isFalse);
  });
}
