import 'dart:async';

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/design/design_system_provider.dart';
import 'package:pipecheck/core/error_handler.dart';
import 'package:pipecheck/core/router.dart';
import 'package:pipecheck/core/services/badge_service.dart';
import 'package:pipecheck/core/services/deep_link_service.dart';
import 'package:pipecheck/core/services/in_app_purchase_service.dart';
import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:pipecheck/core/services/snackbar_service.dart';
import 'package:pipecheck/core/state/auth_state.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:utils/utils.dart';

/// 애플리케이션의 진입점입니다.
///
/// 앱 설정을 초기화하고, 로케일을 설정한 후 Flutter 앱을 실행합니다.
/// Riverpod과 EasyLocalization을 통해 상태 관리와 다국어 지원을 초기화합니다.
void main() async {
  // 전역 에러 핸들러를 가장 먼저 — 초기화 중 에러도 잡는다 (P1-14b).
  // Crashlytics 전송은 핸들러 내부에서 플래그/릴리즈 모드로 가드된다.
  ErrorHandler.setupGlobalErrorHandling();

  // 알림 탭 → 라우트 이동 핸들러를 notifications 패키지에 주입 (P2-20c PR3).
  // 패키지는 앱 라우터(rootNavigatorKey/go_router)에 의존하지 않는다.
  NotificationController.onNavigate = (route) =>
      navigateFromNotification(route, (r) => rootNavigatorKey.currentContext?.go(r));

  final appConfig = await AppConfig().initialize();
  // 개발 프리미엄 덮어쓰기는 디버그 또는 `-dev` 내부 배포 빌드에서만 인정한다.
  devOverrideAllowed = kDebugMode || (await PackageInfo.fromPlatform()).version.contains('-dev');
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  // languageCode 기준 매칭 — 정확일치(contains)는 country가 다른 기기 로케일
  // (예: 'ar-EG' vs 지원 'ar', 'en-GB' vs 'en-US')을 놓쳐 영어로 강제 폴백시켜
  // "RTL 레이아웃 + 영문 스트링" 혼합 UI를 만든다. languageCode로 완화.
  final startLocale = supportedLocales.firstWhere(
    (l) => l.languageCode == systemLocale.languageCode,
    orElse: () => defaultLocale,
  );

  // localization log 설정
  EasyLocalization.logger.enableLevels = [];

  // 기능 플래그는 AppConfig().initialize() 안에서 서비스 초기화 **전에**
  // env 산출물(APP_PROFILE/FF_*)로 적용된다 — 여기서 덮어쓰지 말 것.
  // 현재 기능 설정 상태 출력 (디버그 모드에서만)
  if (kDebugMode) {
    AppFeatureConfig.printFeatureSummary();
  }

  runApp(ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((_) => appConfig),
      ],
      child: EasyLocalization(
          supportedLocales: supportedLocales,
          path: 'assets/languages',
          fallbackLocale: defaultLocale,
          // 부분 번역(키 누락) 시 원시 키 노출 대신 fallbackLocale 문자열 사용.
          useFallbackTranslations: true,
          startLocale: startLocale,
          child: const MainApp())));
}

/// `app_start`를 부팅 동의 적용이 끝난 **뒤에** 보낸다 — 먼저 보내면 거부한 사용자의
/// 이벤트가 나가거나 유실된다.
@visibleForTesting
Future<void> sendAppStartAfterConsent({
  required Future<void> consentApplied,
  required void Function() log,
}) => consentApplied.then((_) => log());

/// 딥링크·알림 탭 목적지를 **지금 이동할 위치**로 바꾼다. 스플래시 이동 전(콜드 스타트
/// 포함)이면 보관하고 null — 지금 `go()`하면 동의·ATT·점검·온보딩을 건너뛴다.
@visibleForTesting
String? deepLinkTarget(String location) => PendingDeepLink.offer(location);

/// 알림 탭 → 이동. 콜드 스타트 탭은 스플래시가 끝날 때까지 보관한다(점검·동의·온보딩 우회 방지).
@visibleForTesting
void navigateFromNotification(String route, void Function(String) go) {
  final target = deepLinkTarget(route);
  if (target != null) go(target);
}

/// 딥링크 URI → 이동. 화이트리스트 밖/가비지 링크는 무시하고, 나머지는 [deepLinkTarget]을 거친다.
@visibleForTesting
void navigateFromDeepLink(Uri uri, void Function(String) go) {
  final location = deepLinkLocation(uri);
  if (location == null) {
    logger.d('DeepLink ignored (not routable): $uri');
    return;
  }
  navigateFromNotification(location, go);
}

/// 생명주기 → 앱 잠금 배선. 백그라운드로 가면 시각을 기록하고(paused),
/// 돌아오면(resumed) 유예 시간을 넘겼는지 보고 다시 잠근다.
@visibleForTesting
void applyLockLifecycle(AppLifecycleState state, AuthStateNotifier auth) {
  if (state == AppLifecycleState.paused) auth.markBackgrounded();
  if (state == AppLifecycleState.resumed) auth.relockIfBackgroundedLongerThan();
}

/// 애플리케이션의 루트 위젯입니다.
///
/// ConsumerStatefulWidget을 확장하여 Riverpod 상태 관리를 사용하고,
/// 앱의 전역 설정과 테마를 관리합니다.
class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

/// MainApp의 상태를 관리하는 클래스입니다.
///
/// WidgetsBindingObserver를 구현하여 앱의 생명주기 이벤트를 감지하고,
/// 알림, 뱃지, 스낵바 등의 전역 기능을 관리합니다.
class MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  /// 알림 서비스 인스턴스
  RaynearNotification? _notification;

  /// 딥링크 서비스 (P2-23a) — 활성화된 경우 첫 프레임 이후 start.
  DeepLinkService? _deepLink;

  /// 위젯 초기화 시 호출됩니다.
  ///
  /// 앱 생명주기 옵저버를 등록하고, 알림 서비스를 초기화하며,
  /// Firebase Analytics와 각종 Provider를 설정합니다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 부팅 때 IAP 서비스를 바로 만든다 — 앱이 꺼진 사이 도착한 거래를 받고 스토어 권리를 맞춘다.
    ref.read(inAppPurchaseServiceProvider);
    
    // 알림 기능이 활성화된 경우에만 알림 서비스 사용
    if (AppFeatureConfig.isNotificationEnabled) {
      _notification = RaynearNotification();
      
      // 재참여 알림 설정
      if (AppFeatureConfig.isReEngagementEnabled) {
        _notification?.setReEngagementNotification();
      }
      
      // 리마인더 알림 설정
      if (AppFeatureConfig.isReminderEnabled) {
        _notification?.setReminderNotification();
      }
    }

    // Firebase Analytics 초기화 확인 로깅 추가 (Firebase가 활성화된 경우에만)
    if (AppFeatureConfig.isFirebaseEnabled && AppFeatureConfig.isFirebaseAnalyticsEnabled) {
      // 부팅 동의 적용 뒤에 보낸다 — 네이티브 수집 기본이 OFF라 먼저 보내면 유실된다.
      sendAppStartAfterConsent(
        consentApplied: AppConfig.consentApplied,
        log: () => FirebaseService.logEvent(
            name: 'app_start', parameters: {'timestamp': DateTime.now().toIso8601String()}),
      );
    }

    // 앱 실행 횟수 증가
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 점검 모드·강제 업데이트 검사는 SplashView가 이동 전에 한다 — 여기서 스플래시 위에
      // pageless 다이얼로그를 띄우면 스플래시가 replace될 때 함께 제거돼 우회된다.
      await AppConfig().incrementAppLaunchCountAndCheckForReview(
        settingsNotifier: ref.read(settingsProvider.notifier),
      );
      // 첫 실행 시에는 스플래시 화면이므로 여기서는 뱃지 확인하지 않음

      // 딥링크 수신 시작 (P2-23a) — 첫 프레임 이후라 라우터 컨텍스트가 준비됨.
      // 콜드 스타트 링크는 start() 안에서 getInitialLink로 비워진다.
      if (AppFeatureConfig.isDeepLinkEnabled) {
        _deepLink = DeepLinkService(onUri: _handleDeepLink);
        await _deepLink!.start();
      }
    });

    ref.listenManual(newBadgesProvider, (previous, next) {
      if (next.isNotEmpty) {
        final badgeService = ref.read(badgeServiceProvider);
        badgeService.checkAndUpdateBadges();
      }
    });

    // 스낵바 큐 감지 및 처리
    ref.listenManual(snackBarProvider, (previous, next) {
      if (next.isNotEmpty) {
        final snackBarService = ref.read(snackBarServiceProvider);
        // 다음 프레임에서 스낵바 처리 (UI가 준비된 후)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          snackBarService.processSnackBarQueue();
        });
      }
    });
  }

  /// 들어온 딥링크 URI를 GoRouter 위치로 변환해 이동한다 (P2-23a).
  /// 화이트리스트 밖/가비지 링크는 [deepLinkLocation]이 null을 돌려 무시된다.
  void _handleDeepLink(Uri uri) {
    // 위젯 트리가 살아있을 때만 이동 — 티어다운 중 도착한 웜 링크가
    // 죽은 context로 go()해 예외가 나는 것을 막는다.
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    navigateFromDeepLink(uri, context.go);
  }

  /// 위젯이 제거될 때 호출됩니다.
  ///
  /// 앱 생명주기 옵저버를 제거하여 메모리 누수를 방지합니다.
  @override
  void dispose() {
    _deepLink?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 위젯 트리를 빌드합니다.
  ///
  /// MaterialApp.router를 반환하여 GoRouter 기반의 네비게이션을 설정하고,
  /// 테마와 다국어 설정을 적용합니다.
  @override
  Widget build(BuildContext context) {
    // Only watch the specific field we need instead of entire settings
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final (lightTheme, darkTheme, themeMode) = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    if (kDebugMode) {
      debugProfileBuildsEnabled = true;
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: kDebugMode,
      routerConfig: router,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: language,
    );
  }

  /// 앱 생명주기 상태가 변경될 때 호출됩니다.
  ///
  /// 앱이 백그라운드로 이동하거나 포그라운드로 돌아올 때
  /// 알림과 뱃지를 적절히 처리합니다.
  ///
  /// [state] - 변경된 앱 생명주기 상태
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    // 앱 잠금: 떠난 시각 기록(paused) / 유예 초과 시 재잠금(resumed). 라우터가 authState를
    // 듣고 있어 보호 화면에서는 즉시 /auth로 간다.
    applyLockLifecycle(state, ref.read(authStateProvider.notifier));

    if (state == AppLifecycleState.inactive) {
      logger.i('inactive');
    }
    if (state == AppLifecycleState.paused) {
      logger.i('paused');
    }
    if (state == AppLifecycleState.resumed) {
      logger.i('resumed');
      // 갱신·해지·환불은 앱이 꺼진 사이에 일어난다 — 돌아올 때 스토어 기준으로 다시 맞춘다.
      unawaited(ref.read(inAppPurchaseServiceProvider)?.refreshEntitlement());
      // 백그라운드 알림 제거 (메서드 내부에서 설정 확인)
      await _notification?.removeBackgroundNotification();

      // final settings = ref.read(settingsProvider);
      final badgeService = ref.read(badgeServiceProvider);
      // 뱃지 확인
      await badgeService.checkAndUpdateBadges();
    }
    if (state == AppLifecycleState.detached) {
      logger.i('detached');
    }
  }
}
