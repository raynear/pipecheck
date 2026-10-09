// 라우터 잠금 하드닝 회귀 테스트.
//
// H4  `/settings/<하위>` 딥링크·직접 이동으로 앱 잠금을 우회하던 구멍.
// M2  라우터가 인증 변화를 안 들어 로그아웃·잠금 후에도 보호 화면이 남던 문제.
// M7  screen_view 중복 집계(pageBuilder는 rebuild마다 다시 불린다).

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/pin_service.dart';
import 'package:pipecheck/core/services/secure_store.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/features/auth/view_models/auth_view_model.dart'
    as vm;
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

void main() {
  group('isProtectedRoute (H4)', () {
    test('정확히 일치하는 보호 라우트', () {
      expect(isProtectedRoute(Routes.home), isTrue);
      expect(isProtectedRoute(Routes.settings), isTrue);
    });

    test('하위 경로도 보호된다 — /settings/pin, /settings/feature-config', () {
      expect(isProtectedRoute('/settings/pin'), isTrue);
      expect(isProtectedRoute('/settings/feature-config'), isTrue);
      expect(isProtectedRoute('/home/anything'), isTrue);
    });

    test('공개 목록 밖은 전부 보호된다 — 파생 앱이 추가한 경로도 기본 보호 (허용목록)', () {
      for (final p in [
        Routes.subscription,
        '/history', // 파생 앱이 optionalRoutes/ShellRoute로 더하는 경로들
        '/stats',
        '/badges',
        '/anything/else',
      ]) {
        expect(isProtectedRoute(p), isTrue, reason: p);
      }
    });

    test('접두사가 이름만 닮은 경로는 공개로 오인되지 않는다 (/authx)', () {
      expect(isProtectedRoute('/authx'), isTrue);
      expect(isProtectedRoute('/loginfoo'), isTrue);
      expect(isProtectedRoute('/auth/sub'), isFalse, reason: '공개 라우트의 하위는 공개');
    });

    test('인증 흐름 라우트는 보호 대상이 아니다', () {
      for (final p in [
        Routes.auth,
        Routes.login,
        Routes.pinRecovery,
        Routes.splash,
        Routes.permission,
        Routes.onboarding,
      ]) {
        expect(isProtectedRoute(p), isFalse, reason: p);
      }
    });
  });

  group('deepLinkLocation 전체 경로 기준 (H4)', () {
    test('하위 경로 딥링크는 무시된다 — 잠금 우회 경로 차단', () {
      expect(deepLinkLocation(Uri.parse('myapp://open/settings/pin')), isNull);
      expect(
        deepLinkLocation(Uri.parse('https://x.com/settings/feature-config')),
        isNull,
      );
    });

    test('화이트리스트 라우트 자체는 그대로 통과 (쿼리 보존)', () {
      expect(deepLinkLocation(Uri.parse('myapp://open/settings')), '/settings');
      expect(
        deepLinkLocation(Uri.parse('https://x.com/settings?id=3')),
        '/settings?id=3',
      );
    });

    test('끝 슬래시는 같은 라우트로 정규화한다', () {
      expect(
        deepLinkLocation(Uri.parse('myapp://open/settings/')),
        '/settings',
      );
    });
  });

  group('라우터 통합 (H4 redirect / M2 refreshListenable)', () {
    late Map<String, bool> saved;

    setUp(() {
      AppFeatureConfig.applyBootConfig(profileName: 'minimal');
      saved = AppFeatureConfig.toMap();
      AppFeatureConfig.isAuthenticationEnabled = true;
      AppFeatureConfig.isOnboardingEnabled = false; // 온보딩 분기는 N8 테스트만 켠다
    });
    tearDown(() => AppFeatureConfig.fromMap(saved));

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          pinServiceProvider.overrideWithValue(PinService(_MemStore())),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// 스플래시가 자체 타이머로 떠난 뒤까지 흘려보낸다 (router_server_account_gate_test 동일 사유).
    Future<void> settleSplash(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    }

    Future<GoRouter> boot(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      final router = container.read(goRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settleSplash(tester);
      return router;
    }

    /// 설정·홈 화면은 끝없는 애니메이션/타이머가 있어 pumpAndSettle이 타임아웃한다.
    Future<void> settleProtected(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    String path(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

    Future<void> teardownTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    testWidgets('H4: 잠긴 상태에서 /settings/pin 으로 가면 /auth 로 보낸다', (tester) async {
      final container = makeContainer();
      final router = await boot(tester, container);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.initial());
      await tester.pumpAndSettle();

      router.go('/settings/pin');
      await tester.pumpAndSettle();

      expect(path(router), Routes.auth);
      await teardownTree(tester);
    });

    testWidgets('허용목록: 잠긴 상태에서 /subscription 으로 가도 /auth 로 보낸다', (
      tester,
    ) async {
      final container = makeContainer();
      final router = await boot(tester, container);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.initial());
      await tester.pumpAndSettle();

      router.go(Routes.subscription);
      await tester.pumpAndSettle();

      expect(path(router), Routes.auth);
      await teardownTree(tester);
    });

    testWidgets('N2: 잠금으로 튕긴 원래 목적지를 해제 뒤 이어 열 수 있게 보관한다', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      final container = makeContainer();
      final router = await boot(tester, container);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.initial());
      await tester.pumpAndSettle();

      router.go('/settings?tab=2');
      await tester.pumpAndSettle();

      expect(path(router), Routes.auth);
      expect(PendingDeepLink.takeAfterUnlock(Routes.home), '/settings?tab=2');
      await teardownTree(tester);
    });

    testWidgets('N8: 온보딩 전에는 보호 라우트 대신 온보딩으로 보내고 목적지를 보관한다', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      AppFeatureConfig.isOnboardingEnabled = true;
      final container = makeContainer();
      final router = await boot(tester, container);
      await settleProtected(tester);
      router.go('/settings?tab=2');
      await settleProtected(tester);
      expect(path(router), Routes.onboarding);
      expect(PendingDeepLink.takeAfterUnlock(Routes.home), '/settings?tab=2');
      await teardownTree(tester);
    });

    testWidgets('N8: 이미 인증된 채 /auth 로 오면 보관된 목적지로 보내되 꺼내지는 않는다(peek)', (tester) async {
      PendingDeepLink.reset();
      addTearDown(PendingDeepLink.reset);
      final container = makeContainer();
      final router = await boot(tester, container);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.authenticated(method: AuthMethod.pin));
      await settleProtected(tester);
      PendingDeepLink.holdForUnlock('/settings?tab=2');
      router.go(Routes.auth);
      await settleProtected(tester);
      expect(path(router), Routes.settings);
      expect(PendingDeepLink.takeAfterUnlock(Routes.home), '/settings?tab=2',
          reason: 'redirect가 소비하면 안 된다');
      await teardownTree(tester);
    });

    testWidgets('H4 양성 대조군: 인증된 상태에서는 /settings/pin 에 들어간다', (tester) async {
      final container = makeContainer();
      final router = await boot(tester, container);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.authenticated(method: AuthMethod.pin));
      await tester.pumpAndSettle();

      router.go('/settings/pin');
      await settleProtected(tester);

      expect(path(router), '/settings/pin');
      await teardownTree(tester);
    });

    testWidgets('M2: 보호 화면에 있다가 잠기면(authState 변화) 즉시 /auth 로 튕긴다', (
      tester,
    ) async {
      final container = makeContainer();
      final router = await boot(tester, container);
      final auth = container.read(authStateProvider.notifier);
      auth.setAuthState(AuthState.authenticated(method: AuthMethod.pin));
      router.go('/settings/pin');
      await settleProtected(tester);
      expect(path(router), '/settings/pin', reason: '전제: 보호 화면에 있다');

      auth.setAuthState(AuthState.initial());
      await tester.pumpAndSettle(); // /auth 화면은 정착한다

      expect(
        path(router),
        Routes.auth,
        reason: 'refreshListenable이 없으면 다음 네비게이션까지 보호 화면이 그대로 남는다',
      );
      await teardownTree(tester);
    });

    test('M2: authState·서버 세션(authViewModel) 변화 모두 refresh를 울린다', () {
      final container = ProviderContainer(
        overrides: [
          pinServiceProvider.overrideWithValue(PinService(_MemStore())),
        ],
      );
      addTearDown(container.dispose);
      final refresh = container.read(
        Provider((ref) => authRefreshNotifier(ref)),
      );
      addTearDown(refresh.dispose);
      expect(refresh.value, 0);

      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.initial());
      final afterLock = refresh.value;
      expect(afterLock, greaterThan(0), reason: '앱잠금 변화는 refresh를 울려야 한다');

      container.read(vm.authViewModelProvider.notifier).state =
          const AsyncValue.data(vm.AuthState.unauthenticated());
      expect(
        refresh.value,
        greaterThan(afterLock),
        reason: '서버 세션 만료/로그아웃도 refresh를 울려야 한다',
      );
    });

    testWidgets('M7: 셸 안 화면(설정)도 라우트 이름으로 집계된다', (tester) async {
      final container = makeContainer();
      final logged = <String>[];
      final router = container.read(goRouterProvider);
      final detach = attachScreenViewLogging(router, log: logged.add);
      addTearDown(detach);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settleSplash(tester);
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.authenticated(method: AuthMethod.pin));

      router.go(Routes.settings);
      await settleProtected(tester);

      expect(logged, contains(RouteNames.settings));
      await teardownTree(tester);
    });

    testWidgets('M7: 같은 화면은 한 번만 집계된다 (rebuild·refresh로 중복 안 됨)', (
      tester,
    ) async {
      final container = makeContainer();
      final logged = <String>[];
      final router = container.read(goRouterProvider);
      final detach = attachScreenViewLogging(router, log: logged.add);
      addTearDown(detach);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settleSplash(tester);

      // /login은 인증된 사용자를 /home으로 되튕기고 /home은 정착하지 않는다 —
      // 되튕김이 없는 인증 흐름 화면으로 이동한다.
      router.go(Routes.pinRecovery);
      await tester.pumpAndSettle();
      // 인증 상태 변화 = 라우터 refresh. 위치가 같으니 재집계되면 안 된다.
      container
          .read(authStateProvider.notifier)
          .setAuthState(AuthState.initial());
      await tester.pumpAndSettle();
      // 명시적 refresh도 같은 위치를 다시 평가시킨다.
      router.refresh();
      await tester.pumpAndSettle();
      // 쿼리만 바뀌는 이동도 같은 화면이다.
      router.go('${Routes.pinRecovery}?step=2');
      await tester.pumpAndSettle();

      expect(logged.where((n) => n == RouteNames.pinRecovery).length, 1);
      expect(
        logged.where((n) => n == RouteNames.splash).length,
        1,
        reason: 'Splash는 pageBuilder 2회 호출 때문에 항상 2회 집계되던 화면',
      );
      for (var i = 1; i < logged.length; i++) {
        expect(logged[i], isNot(logged[i - 1]), reason: '연속 중복: $logged');
      }
      await teardownTree(tester);
    });
  });
}
