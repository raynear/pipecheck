// H5: PIN 복구의 이메일 경로가 "아무 Firebase 계정"으로 잠금을 풀던 구멍.
//
// 기기를 주운 사람이 자기 계정으로 로그인하면 PIN이 삭제되고 잠금이 none이 되어
// 피해자의 로컬 데이터가 그대로 노출됐다. 이제 이메일 복구는 PIN을 만들 때 로그인
// 했던 계정(uid)으로만 통과하고, 묶인 계정이 없으면 이 경로 자체를 숨긴다.
//
// 진짜 PinRecoveryView·PinService·AuthStateNotifier를 돌리고 Firebase 쪽만 가짜.

import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/features/auth/view_models/auth_view_model.dart';
import 'package:pipecheck/features/auth/views/pin_recovery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MemStore implements SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

/// 로그인하면 [signInUid] 계정이 되는 가짜 Firebase 이메일 인증.
class _FakeEmailAuth extends FirebaseEmailAuthService {
  _FakeEmailAuth(this.signInUid, {this.sessionUid, this.reauthFails = false});
  final String signInUid;

  /// 복구를 시작하기 전에 이 기기에 살아 있던 Firebase 세션의 uid.
  final String? sessionUid;
  final bool reauthFails;
  int signOutCount = 0;
  int signInCount = 0;
  int reauthCount = 0;

  @override
  AuthUser? get currentUser => sessionUid == null
      ? null
      : AuthUser(
          uid: sessionUid!,
          email: 'owner@example.com',
          isEmailVerified: true,
        );

  @override
  Future<AuthUser> reauthenticate({
    required String email,
    required String password,
  }) async {
    reauthCount++;
    if (reauthFails) throw const AuthException('wrong-password', 'bad');
    return AuthUser(uid: sessionUid!, email: email, isEmailVerified: true);
  }

  @override
  bool get isFirebaseReady => true;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCount++;
    return AuthUser(uid: signInUid, email: email, isEmailVerified: true);
  }

  @override
  Future<void> signOut() async => signOutCount++;
}

const _emailTile = 'auth.pin.recoverEmail';

void main() {
  late Map<String, bool> saved;
  late _MemStore store;
  late PinService pin;
  late GoRouter router;

  setUp(() {
    saved = AppFeatureConfig.toMap();
    AppFeatureConfig.isEmailAuthEnabled = true;
    AppFeatureConfig.isFirebaseEnabled = true;
    store = _MemStore();
    pin = PinService(store);
  });
  tearDown(() => AppFeatureConfig.fromMap(saved));

  Future<ProviderContainer> pumpView(
    WidgetTester tester,
    _FakeEmailAuth email,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pinServiceProvider.overrideWithValue(pin),
        emailAuthServiceProvider.overrideWithValue(email),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router = GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const PinRecoveryView()),
              GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
              GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> signInThroughDialog(WidgetTester tester) async {
    await tester.tap(find.text(_emailTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'someone@example.com');
    await tester.enterText(find.byType(TextField).last, 'pw');
    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();
  }

  testWidgets('묶인 계정이 없으면 이메일 복구 항목이 보이지 않는다', (tester) async {
    await pin.setPin('123456'); // 로그아웃 상태에서 만든 PIN

    await pumpView(tester, _FakeEmailAuth('uid-any'));

    expect(find.text(_emailTile), findsNothing);
    expect(
      find.text('auth.pin.recoverReset'),
      findsOneWidget,
      reason: '초기화는 항상 남아 있어 사용자가 갇히지 않는다',
    );
  });

  testWidgets('묶인 계정이 있으면 이메일 복구 항목이 보인다 (양성 대조군)', (tester) async {
    await pin.setPin('123456', boundUid: 'uid-owner');

    await pumpView(tester, _FakeEmailAuth('uid-owner'));

    expect(find.text(_emailTile), findsOneWidget);
  });

  testWidgets('다른 계정으로 로그인하면 잠금을 풀지 않고 그 세션도 끊는다', (tester) async {
    await pin.setPin('123456', boundUid: 'uid-owner');
    final attacker = _FakeEmailAuth('uid-attacker');
    final container = await pumpView(tester, attacker);

    await signInThroughDialog(tester);

    expect(await pin.hasPin(), isTrue, reason: 'PIN이 지워지면 잠금이 풀린 것이다');
    expect(container.read(authStateProvider).method, isNot(AuthMethod.email));
    expect(attacker.signOutCount, 1);
    expect(
      container.read(snackBarProvider).map((s) => s.type),
      contains(SnackBarType.error),
    );
  });

  testWidgets('주인 계정으로 로그인하면 잠금이 풀린다 (양성 대조군)', (tester) async {
    await pin.setPin('123456', boundUid: 'uid-owner');
    final owner = _FakeEmailAuth('uid-owner');
    final container = await pumpView(tester, owner);

    await signInThroughDialog(tester);

    expect(await pin.hasPin(), isFalse);
    expect(container.read(authStateProvider).method, AuthMethod.email);
    expect(owner.signOutCount, 0);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
  });

  testWidgets('N2: 복구로 잠금이 풀리면 보류된 원래 목적지로 이어 간다', (tester) async {
    PendingDeepLink.reset();
    addTearDown(PendingDeepLink.reset);
    PendingDeepLink.holdForUnlock('/settings');
    await pin.setPin('123456', boundUid: 'uid-owner');
    await pumpView(tester, _FakeEmailAuth('uid-owner'));

    await signInThroughDialog(tester);

    expect(router.routerDelegate.currentConfiguration.uri.path, '/settings');
  });

  testWidgets('주인 세션이 살아 있으면 재인증만 하고 signIn·signOut은 안 한다', (tester) async {
    await pin.setPin('123456', boundUid: 'uid-owner');
    final owner = _FakeEmailAuth('uid-attacker', sessionUid: 'uid-owner');
    final container = await pumpView(tester, owner);

    await signInThroughDialog(tester);

    expect(owner.reauthCount, 1);
    expect(owner.signInCount, 0, reason: 'signIn은 기기의 주인 세션을 덮는다');
    expect(owner.signOutCount, 0);
    expect(await pin.hasPin(), isFalse);
    expect(container.read(authStateProvider).method, AuthMethod.email);
  });

  testWidgets('주인 세션에서 재인증이 실패하면 잠금은 그대로고 세션도 안 끊는다', (tester) async {
    await pin.setPin('123456', boundUid: 'uid-owner');
    final owner = _FakeEmailAuth(
      'uid-attacker',
      sessionUid: 'uid-owner',
      reauthFails: true,
    );
    final container = await pumpView(tester, owner);

    await signInThroughDialog(tester);

    expect(owner.reauthCount, 1);
    expect(owner.signInCount, 0);
    expect(owner.signOutCount, 0);
    expect(await pin.hasPin(), isTrue);
    expect(container.read(authStateProvider).method, isNot(AuthMethod.email));
  });
}
