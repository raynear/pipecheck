import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/widgets/ads/ad_container.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:pipecheck/core/widgets/navigation/bottom_nav_bar.dart';
import 'package:pipecheck/features/auth/index.dart';
import 'package:pipecheck/features/home/index.dart';
import 'package:pipecheck/features/onboarding/index.dart';
import 'package:pipecheck/features/permission/index.dart';
import 'package:pipecheck/features/settings/index.dart';
import 'package:pipecheck/features/settings/views/feature_config_view.dart';
import 'package:pipecheck/features/splash/index.dart';
import 'package:pipecheck/features/subscription/index.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheet/route.dart';
import 'package:utils/utils.dart';

/// 전역 네비게이터 키
///
/// 앱 전체에서 네비게이션을 제어하기 위한 최상위 네비게이터 키입니다.
/// 다이얼로그, 스낵바 등을 표시하거나 프로그래밍 방식으로 네비게이션을 제어할 때 사용됩니다.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shellRoot');

/// 전역 네비게이터 키에 대한 접근자
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

/// 페이지 빌더 헬퍼 함수
CupertinoExtendedPage<void> _logAndBuildPage({
  required Widget child,
  required GoRouterState state,
}) {
  final screenName = state.name ?? state.fullPath ?? child.runtimeType.toString();
  // 현재 페이지 로깅
  logger.d('화면 전환: $screenName');

  // screen_view는 여기서 보내지 않는다 — GoRouter는 탐색·refresh마다 스택의 모든
  // 매치에 pageBuilder를 다시 불러서 여기서 보내면 중복 집계된다(Splash는 항상 2회).
  // 위치가 바뀔 때 한 번만 보내는 [attachScreenViewLogging]이 맡는다.
  return CupertinoExtendedPage(child: child);
}

/// screen_view 로거 시그니처 (테스트에서 대체).
typedef ScreenViewLog = void Function(String screenName);

void _logScreenViewToFirebase(String screenName) =>
    FirebaseService.logScreenView(screenName: screenName);

/// 라우터 위치가 **바뀔 때만** screen_view를 한 번 보낸다. 반환값은 해제 함수.
///
/// `FirebaseAnalyticsObserver`로 일원화하지 않은 이유: 옵저버는 네비게이터마다
/// 인스턴스가 따로 필요한데(NavigatorObserver는 한 네비게이터에만 붙는다)
/// `FirebaseService.navigatorObserver`는 단일 인스턴스라 ShellRoute 안의
/// 홈·설정을 못 본다. 라우터 위치 변화를 한 곳에서 듣는 쪽이 루트·셸을 함께 덮는다.
VoidCallback attachScreenViewLogging(
  GoRouter router, {
  ScreenViewLog log = _logScreenViewToFirebase,
}) {
  String? lastPath;
  void onChange() {
    final config = router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return;
    final path = config.uri.path;
    if (path == lastPath) return;
    lastPath = path;
    final route = config.last.route;
    log(route.name ?? config.fullPath);
  }

  router.routerDelegate.addListener(onChange);
  return () => router.routerDelegate.removeListener(onChange);
}

/// GoRouter 프로바이더
///
/// 앱의 전체 라우팅을 관리하는 GoRouter 인스턴스를 제공합니다.
///
/// 주요 기능:
/// - 선언적 라우팅 관리
/// - 중첩 라우팅 (ShellRoute를 통한 Bottom Navigation)
/// - 권한 기반 리다이렉트
/// - 에러 페이지 처리
/// - 페이지 전환 시 Analytics 로깅
///
/// 사용 예시:
/// ```dart
/// context.go(Routes.home); // 홈으로 이동
/// context.push(Routes.settings); // 설정 페이지를 스택에 추가
/// ```
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = authRefreshNotifier(ref);

  final router = GoRouter(
    // 인증 변화는 redirect를 다시 평가시킨다 — 로그인 성공 시 라우터가 LoginView의
    // `context.go`보다 먼저 보낼 수 있으므로 로그인 뒤 별도 흐름은 redirect 이후 화면이 소유한다.
    refreshListenable: authRefresh,
    initialLocation: Routes.splash,
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    restorationScopeId: 'app',
    routerNeglect: true,
    routes: [
      // Splash 라우트
      GoRoute(
        name: RouteNames.splash,
        path: Routes.splash,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const SplashView(),
          state: state,
        ),
      ),

      // 인증 라우트 (Biometric/PIN)
      GoRoute(
        name: RouteNames.auth,
        path: Routes.auth,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const AuthenticationView(),
          state: state,
        ),
      ),

      // 로그인 라우트 (Email/Password)
      GoRoute(
        name: RouteNames.login,
        path: Routes.login,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const LoginView(),
          state: state,
        ),
      ),

      // PIN 분실 복구 라우트 (P2-23h ③) — 잠금 해제 전(미인증)에 접근 가능.
      GoRoute(
        name: RouteNames.pinRecovery,
        path: Routes.pinRecovery,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const PinRecoveryView(),
          state: state,
        ),
      ),

      // 권한 요청 라우트
      GoRoute(
        name: RouteNames.permission,
        path: Routes.permission,
        pageBuilder: (context, state) {
          // queryParameters에서 권한 정보를 가져오거나 기본값 사용
          final permissionMap = state.extra as Map<PermissionType, String>? ?? {};

          return _logAndBuildPage(
            child: PermissionRequestView(
              permissionMap: permissionMap,
            ),
            state: state,
          );
        },
      ),

      // 구독 라우트
      GoRoute(
        name: RouteNames.subscription,
        path: Routes.subscription,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const SubscriptionView(),
          state: state,
        ),
      ),

      // 온보딩 라우트
      GoRoute(
        name: RouteNames.onboarding,
        path: Routes.onboarding,
        pageBuilder: (context, state) => _logAndBuildPage(
          child: const OnboardingView(),
          state: state,
        ),
      ),

      // 메인 앱 Shell (Bottom Navigation Bar 포함)
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithBottomNavBar(
          child: AppFeatureConfig.isAdsEnabled
              ? AdContainer(
                  adKey: 'shell',
                  child: child,
                )
              : child,
        ),
        routes: [
          // 홈 라우트
          GoRoute(
            name: RouteNames.home,
            path: Routes.home,
            pageBuilder: (context, state) => _logAndBuildPage(
              child: HomeView(),
              state: state,
            ),
          ),

          // 설정 라우트
          GoRoute(
            name: RouteNames.settings,
            path: Routes.settings,
            pageBuilder: (context, state) => _logAndBuildPage(
              child: const SettingsView(),
              state: state,
            ),
            routes: [
              // Feature Configuration 서브 라우트
              GoRoute(
                name: 'feature-config',
                path: 'feature-config',
                pageBuilder: (context, state) => _logAndBuildPage(
                  child: const FeatureConfigView(),
                  state: state,
                ),
              ),
              // PIN 설정/변경 서브 라우트 (P2-23h ②)
              GoRoute(
                name: 'pin-setup',
                path: 'pin',
                pageBuilder: (context, state) => _logAndBuildPage(
                  child: const PinSetupView(),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
    ],

    // 리다이렉트 로직
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.isAuthenticated;
      final currentPath = state.matchedLocation;

      // 인증 관련 라우트
      const authRoutes = [
        Routes.auth,
        Routes.login,
      ];

      // Splash는 리다이렉트하지 않는다 — SplashView가 ATT/프라이버시 동의 수집과
      // 후속 네비게이션(_navigateToNextScreen)을 직접 소유한다.
      // 여기서 튕겨내면 동의 플로우 전체가 도달 불가가 된다.
      if (currentPath == Routes.splash) {
        return null;
      }

      // 이미 인증된 사용자가 인증 화면에 접근하는 경우
      if (isAuthenticated && authRoutes.contains(currentPath)) {
        return Routes.home;
      }

      // 인증이 필요한 라우트 보호 (공개 목록 밖은 전부)
      if (AppFeatureConfig.isAuthenticationEnabled &&
          !isAuthenticated &&
          isProtectedRoute(currentPath)) {
        // 원래 목적지를 잠금 해제 뒤 이어 연다 (딥링크·알림 탭을 버리지 않는다).
        PendingDeepLink.holdForUnlock(state.uri.toString());
        return Routes.auth;
      }

      return null;
    },

    // 에러 페이지
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            SText('router.pageNotFound'),
            const SizedBox(height: 8),
            SText(
              'Path: {}',
              args: [state.path ?? ''],
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              child: SText('router.backToHome'),
            ),
          ],
        ),
      ),
    ),
  );

  ref.onDispose(attachScreenViewLogging(router));
  ref.onDispose(router.dispose);
  ref.onDispose(authRefresh.dispose); // 라우터가 먼저 리스너를 뗀 뒤

  return router;
});

/// 인증 변화(앱잠금 authState, 서버 세션 authViewModel)를 알리는 notifier.
///
/// GoRouter의 `refreshListenable`에 물려 라우터를 **재생성하지 않고** redirect만
/// 다시 평가시킨다 — 로그아웃·잠금·세션 만료 때 보호 화면이 다음 네비게이션까지
/// 남지 않게 한다. dispose는 호출한 쪽(라우터 provider) 몫이다.
ValueNotifier<int> authRefreshNotifier(Ref ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => notifier.value++);
  ref.listen(authViewModelProvider, (_, _) => notifier.value++);
  return notifier;
}

/// 앱잠금이 걸려 있어도 열리는 공개 라우트 (하위 경로 포함). **여기 없는 경로는
/// 전부 보호된다** — 차단 목록이면 경로를 추가하고 목록에 넣는 걸 잊는 순간 그 화면이
/// 잠금 없이 열린다(fail-open).
///
/// - splash·auth·login·pinRecovery: 잠금을 푸는 흐름 자체.
/// - permission·onboarding: 잠금 설정 이전에 거치는 첫 실행 흐름(splash가 보냄).
///   개인 데이터가 없는 화면이다.
const _publicRoutes = [
  Routes.splash,
  Routes.auth,
  Routes.login,
  Routes.pinRecovery,
  Routes.permission,
  Routes.onboarding,
];

/// [path]가 앱잠금 뒤에 있어야 하는 라우트인가 — 공개 라우트(와 그 하위)가 아니면
/// 전부 true.
///
/// 정확 일치만 보면 `/settings/pin` 같은 하위 라우트가 우회한다.
/// `/authx`가 공개로 오인되지 않게 `<route>/` 접두사만 인정한다.
bool isProtectedRoute(String path) =>
    !_publicRoutes.any((r) => path == r || path.startsWith('$r/'));

/// 라우트 경로 상수 클래스
///
/// 앱 내에서 사용되는 모든 라우트 경로를 정의합니다.
/// 타입 안전성을 위해 문자열 상수로 관리됩니다.
///
/// 사용 예시:
/// ```dart
/// context.go(Routes.home);
/// context.push(Routes.settings);
/// ```
class Routes {
  Routes._();

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String login = '/login';
  static const String pinRecovery = '/pin-recovery';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String permission = '/permission';
  static const String subscription = '/subscription';
  static const String onboarding = '/onboarding';
  static const String stats = '/stats';
  static const String badges = '/badges';
}

/// 딥링크가 도달할 수 있는 라우트 화이트리스트 (P2-23a).
///
/// 플로우 내부 라우트(splash/auth/login/permission)는 제외 — 외부 링크가
/// 인증/온보딩 흐름을 건너뛰지 못하게 한다.
const Set<String> deepLinkableRoutes = {
  Routes.home,
  Routes.settings,
  Routes.subscription,
  Routes.stats,
  Routes.badges,
  Routes.onboarding,
};

/// 들어온 딥링크 [uri]를 GoRouter 위치로 변환한다 (P2-23a).
///
/// 커스텀 스킴(`myapp://open/settings`)과 유니버설 링크
/// (`https://host/settings?x=1`) 모두 `uri.path`가 라우트가 된다(host는 스킴
/// sentinel 또는 도메인일 뿐). 전체 경로가 [deepLinkableRoutes]에 있을
/// 때만 위치를 돌려주고(쿼리 보존), 그 외에는 null(무시 — 가비지 링크로 에러
/// 페이지를 띄우거나 보호 라우트를 건너뛰지 않는다).
String? deepLinkLocation(Uri uri) {
  // 전체 경로가 화이트리스트와 같아야 한다. 첫 세그먼트만 보면
  // `/settings/pin` 같은 하위 라우트가 보호 판정 없이 열린다.
  final path = uri.path.length > 1 && uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  if (!deepLinkableRoutes.contains(path)) return null;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

/// 라우트 이름 상수 클래스
///
/// GoRouter의 named route를 위한 이름 상수를 정의합니다.
/// 각 라우트 이름은 해당 화면을 식별하는 고유한 문자열입니다.
///
/// 사용 예시:
/// ```dart
/// context.goNamed(RouteNames.home);
/// context.pushNamed(RouteNames.settings);
/// ```
class RouteNames {
  RouteNames._();

  static const String splash = 'Splash';
  static const String auth = 'Auth';
  static const String login = 'Login';
  static const String pinRecovery = 'PinRecovery';
  static const String home = 'Home';
  static const String settings = 'Settings';
  static const String permission = 'Permission';
  static const String subscription = 'Subscription';
  static const String onboarding = 'Onboarding';
  static const String stats = 'Stats';
  static const String badges = 'Badges';
}

/// BuildContext에 대한 라우터 확장 메서드
///
/// GoRouter의 기능을 더 편리하게 사용할 수 있도록 하는 확장 메서드들을 제공합니다.
///
/// 사용 예시:
/// ```dart
/// context.goToProtected('/settings'); // 인증 확인 후 이동
/// if (context.canGoBack) context.goBackSafely(); // 안전한 뒤로가기
/// ```
extension RouterExtension on BuildContext {
  /// 인증된 사용자만 접근 가능한 라우트로 이동합니다.
  ///
  /// 인증되지 않은 사용자는 로그인 페이지로 리다이렉트됩니다.
  /// GoRouter의 redirect 로직에서 처리되므로 단순히 이동합니다.
  ///
  /// @param location 이동할 라우트 경로
  void goToProtected(String location) {
    // GoRouter의 redirect 로직에서 인증 상태를 확인하고
    // 필요시 auth 페이지로 리다이렉트합니다.
    go(location);
  }

  /// 이전 라우트로 돌아갈 수 있는지 확인합니다.
  ///
  /// @return 뒤로가기가 가능하면 true, 불가능하면 false
  bool get canGoBack => GoRouter.of(this).canPop();

  /// 안전하게 뒤로가기를 수행합니다.
  ///
  /// 뒤로갈 수 있는 경우 이전 페이지로 이동하고,
  /// 그렇지 않은 경우 홈 화면으로 이동합니다.
  void goBackSafely() {
    if (canGoBack) {
      pop();
    } else {
      go(Routes.home);
    }
  }
}
