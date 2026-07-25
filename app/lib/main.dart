import 'package:boilerplate/config/app_config.dart';
import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/design/design_system_provider.dart';
import 'package:boilerplate/core/error_handler.dart';
import 'package:boilerplate/core/router.dart';
import 'package:boilerplate/core/services/badge_service.dart';
import 'package:boilerplate/core/services/deep_link_service.dart';
import 'package:boilerplate/core/services/force_update_service.dart';
import 'package:boilerplate/core/services/maintenance_service.dart';
import 'package:boilerplate/core/services/notification/notification.dart';
import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/core/services/whats_new_service.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:boilerplate/core/widgets/dialogs/whats_new_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  NotificationController.onNavigate =
      (route) => rootNavigatorKey.currentContext?.go(route);

  final appConfig = await AppConfig().initialize();
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
      FirebaseService.logEvent(name: 'app_start', parameters: {'timestamp': DateTime.now().toIso8601String()});
    }

    // 앱 실행 횟수 증가
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 점검 모드 검사 (P2-23b) — RC maintenance_mode가 켜져 있으면 앱 전체를
      // 차단하고 이후 검사(업데이트 등)는 건너뛴다. 플래그/RC 없으면 no-op.
      if (MaintenanceService.isUnderMaintenance()) {
        final maintenanceContext = rootNavigatorKey.currentContext;
        if (maintenanceContext != null && maintenanceContext.mounted) {
          await MaintenanceService.showMaintenanceScreen(maintenanceContext);
        }
        return;
      }

      await AppConfig().incrementAppLaunchCountAndCheckForReview();
      // 첫 실행 시에는 스플래시 화면이므로 여기서는 뱃지 확인하지 않음

      // 강제 업데이트 검사 (P1-14b) — RC 미초기화/네트워크 실패는 fail-open
      if (AppFeatureConfig.isForceUpdateEnabled) {
        final status = await ForceUpdateService.checkForUpdate();
        if (status == UpdateStatus.updateRequired) {
          final navigatorContext = rootNavigatorKey.currentContext;
          if (navigatorContext != null && navigatorContext.mounted) {
            await ForceUpdateService.showForceUpdateDialog(navigatorContext);
          }
        }
      }

      // 딥링크 수신 시작 (P2-23a) — 첫 프레임 이후라 라우터 컨텍스트가 준비됨.
      // 콜드 스타트 링크는 start() 안에서 getInitialLink로 비워진다.
      if (AppFeatureConfig.isDeepLinkEnabled) {
        _deepLink = DeepLinkService(onUri: _handleDeepLink);
        await _deepLink!.start();
      }

      // What's-new 다이얼로그 (P2-24) — 마이너 이상 버전 업 후 첫 실행에 1회.
      // 로컬 버전 비교라 firebase/RC 무관. 점검/강제업데이트 뒤에 둔다.
      if (AppFeatureConfig.isWhatsNewEnabled) {
        final whatsNew = ref.read(whatsNewServiceProvider);
        final showWhatsNew = await whatsNew.shouldShow();
        await whatsNew.markSeen();
        if (showWhatsNew) {
          final whatsNewContext = rootNavigatorKey.currentContext;
          if (whatsNewContext != null && whatsNewContext.mounted) {
            await WhatsNewDialog.show(whatsNewContext);
          }
        }
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
    final location = deepLinkLocation(uri);
    if (location == null) {
      logger.d('DeepLink ignored (not routable): $uri');
      return;
    }
    // 위젯 트리가 살아있을 때만 이동 — 티어다운 중 도착한 웜 링크가
    // 죽은 context로 go()해 예외가 나는 것을 막는다.
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.go(location);
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

    if (state == AppLifecycleState.inactive) {
      logger.i('inactive');
    }
    if (state == AppLifecycleState.paused) {
      logger.i('paused');
    }
    if (state == AppLifecycleState.resumed) {
      logger.i('resumed');
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
