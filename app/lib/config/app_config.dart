import 'dart:async';
import 'dart:io';

import 'package:ads/ads.dart';
import 'package:authentication/authentication.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/config/firebase_options.dart';
import 'package:pipecheck/core/services/ab_test_service.dart';
import 'package:pipecheck/core/services/app_review_service.dart';
import 'package:pipecheck/core/services/notification/notification.dart';
import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:easy_localization/easy_localization.dart';
// firebase_core도 'FirebaseService'를 export하므로 숨긴다 — 여기선
// firebase_services 패키지의 FirebaseService(Analytics 파사드)를 쓴다.
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_services/firebase_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:orange/orange.dart';
import 'package:positioning/positioning.dart';
import 'package:utils/utils.dart';

enum Environment { debug, profile, release }

class AppConfig {
  final Environment environment;
  static Map<String, dynamic> _config = {};
  static List<ProductDetails> _products = [];

  AppConfig._({required this.environment});

  factory AppConfig() {
    return AppConfig._(environment: _determineEnvironment());
  }

  Future<AppConfig> initialize() async {
    try {
      logger.i('Starting app initialization...');

      WidgetsFlutterBinding.ensureInitialized();
      logger.i('Flutter binding initialized');

      // env 로드가 끝난 뒤에만 서비스 초기화 — 병렬 실행 시 서비스가
      // dotenv.load 완료 전에 dotenv.env를 읽는 race가 있었음
      await _loadEnvFile();
      logger.i('Env file loaded successfully');

      // 기능 플래그는 반드시 서비스 초기화 전에 확정 — release에서 init 후
      // enableAllFeatures()로 덮던 구조가 미초기화 서비스 크래시의 뿌리(P0-4).
      // RC→플래그 override(P2-23.5b)도 이 단계에서(서비스 init 전) 적용된다.
      await _applyFeatureConfig();

      // 네트워크 의존적인 초기화는 타임아웃 설정
      await _initializeServices()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              logger.w('Services initialization timed out, continuing with defaults');
              return null;
            },
          )
          .then((_) => logger.i('Services initialized'));

      logger.i('Starting EasyLocalization initialization...');
      await EasyLocalization.ensureInitialized();
      EasyLocalization.logger = easyLogger;
      logger.i('EasyLocalization initialized');

      logger.i('App initialization completed successfully');
      return AppConfig._(environment: environment);
    } catch (e, stack) {
      logger.e('Initialization error: $e');
      logger.e('Stack trace: $stack');
      // 기본 설정으로 폴백
      logger.w('Falling back to default configuration');
      return AppConfig._(environment: environment);
    }
  }

  static Environment _determineEnvironment() {
    if (kReleaseMode) {
      return Environment.release;
    } else {
      return kDebugMode ? Environment.debug : Environment.profile;
    }
  }

  static Future<void> _loadEnvFile() async {
    final env = _determineEnvironment();
    String fileName;
    switch (env) {
      case Environment.debug:
        fileName = 'config/env/.env.debug';
        break;
      case Environment.profile:
        fileName = 'config/env/.env.profile';
        break;
      case Environment.release:
        fileName = 'config/env/.env.release';
        break;
    }
    await dotenv.load(fileName: fileName);
    _config = dotenv.env;
  }

  /// env 산출물의 APP_PROFILE/FF_* 키로 기능 플래그를 적용합니다.
  ///
  /// 값의 출처는 app_config.yaml(profile, features) → ./build(gen-env) 산출물.
  /// yaml 적용 후, 서비스 init 전에 Remote Config override를 한 번 얹는다
  /// (RC→플래그 브리지, P2-23.5b): yaml profile → RC override → freeze.
  static Future<void> _applyFeatureConfig() async {
    final overrides = <String, bool>{};
    for (final entry in dotenv.env.entries) {
      if (entry.key.startsWith('FF_')) {
        overrides[entry.key.substring(3)] =
            entry.value.toLowerCase() == 'true';
      }
    }
    AppFeatureConfig.applyBootConfig(
      profileName: dotenv.env['APP_PROFILE'],
      overrides: overrides,
    );

    // RC→플래그 override (P2-23.5b): 원격으로 기능을 끄거나(kill-switch)
    // 능력 가드를 통과하면 켤 수 있다. firebase+RC가 yaml에서 켜진 경우에만
    // 시도 — 아니면 추가 부팅 비용 0.
    if (AppFeatureConfig.isFirebaseEnabled &&
        AppFeatureConfig.isFirebaseRemoteConfigEnabled) {
      final remote = await _fetchRemoteFlagOverrides();
      if (remote.isNotEmpty) {
        AppFeatureConfig.applyRemoteOverrides(
          remote,
          onGuards: _remoteFlagOnGuards(),
        );
      }
    }
  }

  /// Remote Config에서 서버가 명시적으로 설정한 `feature_<flag>` override를 읽는다.
  ///
  /// 부팅 임계 경로이므로 짧은 timeout으로 가두고, 어떤 실패/오프라인/첫 실행에도
  /// 빈 맵으로 폴백한다(= yaml 값 유지, 부팅을 절대 막지 않음). RC는 여기서
  /// 초기화되며, 이후 _initializeNonCriticalServices의 initialize() 호출은
  /// 멱등이라 no-op이다.
  static Future<Map<String, bool>> _fetchRemoteFlagOverrides() async {
    try {
      return await _fetchRemoteFlagOverridesInner()
          .timeout(const Duration(seconds: 4), onTimeout: () => const {});
    } catch (e) {
      logger.w('Remote flag override fetch failed: $e');
      return const {};
    }
  }

  static Future<Map<String, bool>> _fetchRemoteFlagOverridesInner() async {
    // RC는 Firebase 앱이 필요 — 아직이면 지금 초기화한다(멱등 가드 존재).
    // 이후 _initializeServices의 Firebase.initializeApp은 Firebase.apps.isEmpty로
    // 스킵된다. 자격증명이 placeholder면 throw → 상위에서 빈 맵 폴백.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await RemoteConfigService.instance.initialize();
    return RemoteConfigService.instance.remoteFeatureOverrides();
  }

  /// 원격 ON override 능력 가드 — ON은 사전 셋업이 갖춰진 플래그만 허용한다.
  /// OFF(kill-switch)는 가드 없이 항상 적용된다. 포크는 자신의 셋업에 맞춰
  /// 이 맵을 확장한다(P2-23.5b).
  static Map<String, bool Function()> _remoteFlagOnGuards() => {
        // 광고: 플랫폼 광고 단위 ID가 실제 해석될 때만 ON 허용
        // (없으면 AdMob SDK init 크래시 — P0-4류 방지).
        'isAdsEnabled': () => _resolveAdUnitId('BANNER') != null,
        // Firebase: 여기 도달했다면 Firebase 앱 초기화에 성공한 상태 → ON 허용.
        'isFirebaseEnabled': () => Firebase.apps.isNotEmpty,
      };

  /// 플랫폼별 광고 단위 ID를 .env 산출물에서 해석한다 (ads 패키지에 주입).
  /// 패키지는 dotenv 키 명명을 알지 못한다 — 해석은 앱(소비자) 책임 (P2-20c).
  static String? _resolveAdUnitId(String adType) {
    final prefix = Platform.isIOS ? 'IOS' : 'AOS';
    final id = dotenv.env['${prefix}_${adType}_AD_ID'];
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> _initializeServices() async {
    try {
      // firebase_services 엔진에 기능 플래그 주입 (가드용). 플래그는
      // initialize()의 _applyFeatureConfig에서 이미 확정됨 (서비스 init 전).
      final firebaseConfig = FirebaseServicesConfig(
        firebaseEnabled: AppFeatureConfig.isFirebaseEnabled,
        analyticsEnabled: AppFeatureConfig.isFirebaseAnalyticsEnabled,
        crashlyticsEnabled: AppFeatureConfig.isFirebaseCrashlyticsEnabled,
      );
      FirebaseService.configure(firebaseConfig);
      CrashReporter.configure(firebaseConfig);

      // 위치(positioning) 엔진 플래그 주입 (P2 location 패키지화).
      LocationService.configure(LocationConfig(
        locationEnabled: AppFeatureConfig.isLocationEnabled,
      ));

      // 소셜 인증 Google OAuth 자격증명 주입 (포크별 — 미설정 시 null) (P2-21.5b).
      if (AppFeatureConfig.isSocialAuthEnabled) {
        SocialAuthService.configureGoogle(
          clientId: dotenv.env['GOOGLE_CLIENT_ID'],
          serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
        );
      }

      // 중요 서비스 동기 초기화
      await Orange.init();

      List<Future> initTasks = [Settings.updateSupportedLocale()];

      // Firebase는 항상 초기화 (Analytics 등 때문에)
      // 하지만 FCM은 조건부로 처리
      // 이미 초기화된 경우 중복 초기화 방지
      if (AppFeatureConfig.isFirebaseEnabled && Firebase.apps.isEmpty) {
        initTasks.add(Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform));
      }

      await Future.wait(initTasks);

      // Firebase 초기화 완료 후 appInitializedProvider 업데이트
      // 외부 Provider를 참조하면 의존성 문제가 발생할 수 있으므로 main.dart에서 처리하도록 수정
      // final container = ProviderContainer();
      // container.read(appInitializedProvider.notifier).state = true;

      // 비중요 서비스 초기화 - 에러 핸들링 추가
      _initializeNonCriticalServices().catchError((error) {
        logger.e('Non-critical services initialization error: $error');
      });
    } catch (e) {
      logger.e('Critical services initialization error: $e');
      rethrow; // 중요 서비스 실패는 앱 시작에 치명적이므로 재발생
    }
  }

  Future<void> _initializeNonCriticalServices() async {
    try {
      // Firebase Analytics 설정 — 플래그·초기화 가드는 FirebaseService가 한다
      // (firebase_services 패키지). 비활성화 시 각 호출은 안전하게 no-op.
      if (kDebugMode) {
        // 디버그 모드 설정
        await FirebaseService.setAnalyticsCollectionEnabled(true);
        await FirebaseService.setSessionTimeoutDuration(const Duration(seconds: 30)); // 디버그용 짧은 세션 타임아웃
        await FirebaseService.setConsent(
          analyticsStorageConsentGranted: true,
          adStorageConsentGranted: true,
        );
        await FirebaseService.setUserProperty(name: 'debug_mode', value: 'true'); // 디버그 사용자 프로퍼티

        // 디버그 이벤트에 추가 파라미터 포함
        FirebaseService.logEvent(
          name: 'debug_app_open',
          parameters: {'debug_timestamp': DateTime.now().toIso8601String(), 'debug_build_number': '개발 버전'},
        );
      } else {
        // 프로덕션 모드 설정
        await FirebaseService.setAnalyticsCollectionEnabled(true);
        await FirebaseService.setSessionTimeoutDuration(const Duration(minutes: 30)); // 프로덕션용 긴 세션 타임아웃
        await FirebaseService.setConsent(
          analyticsStorageConsentGranted: true,
          adStorageConsentGranted: true,
        );
      }

      // Firebase Crashlytics 설정 — 플래그·초기화 가드는 CrashReporter가 한다.
      // FlutterError.onError는 여기서 할당하지 않는다 — main()의
      // ErrorHandler.setupGlobalErrorHandling()이 단일 소유자 (P1-14b).
      // 여기서 다시 할당하면 전역 핸들러를 덮어쓴다.
      await CrashReporter.setCollectionEnabled(true);
      await _setCrashClassificationKeys();

      // 광고 서비스 초기화 (광고가 활성화된 경우에만).
      // 플래그·해석된 광고 단위 ID·개인화 동의 콜백을 ads 패키지에 주입한 뒤 초기화.
      if (AppFeatureConfig.isAdsEnabled) {
        AdService().configure(
          config: AdsConfig(
            adsEnabled: AppFeatureConfig.isAdsEnabled,
            appOpenAdEnabled: AppFeatureConfig.isAppOpenAdEnabled,
            umpConsentEnabled: AppFeatureConfig.isUmpConsentEnabled,
            childDirectedAdsEnabled: AppFeatureConfig.isChildDirectedAdsEnabled,
            underAgeOfConsentEnabled: AppFeatureConfig.isUnderAgeOfConsentEnabled,
          ),
          adUnitIds: AdUnitIds(
            banner: _resolveAdUnitId('BANNER'),
            rewarded: _resolveAdUnitId('REWARDED'),
            rewardedInterstitial: _resolveAdUnitId('REWARDED_INTERSTITIAL'),
            interstitial: _resolveAdUnitId('INTERSTITIAL'),
            native: _resolveAdUnitId('NATIVE'),
            appOpen: _resolveAdUnitId('APP_OPEN'),
          ),
          personalizedAds: () =>
              !AppFeatureConfig.isPrivacyConsentEnabled ||
              PrivacyConsentService.personalizedAdsAllowedSync(),
        );
        await AdService().initialize();
      }

      // Remote Config 초기화 (Firebase가 활성화되고 Remote Config가 활성화된 경우에만).
      // RC→플래그 override 브리지(P2-23.5b)가 부팅 패스에서 이미 초기화했으면
      // 이 호출은 멱등 no-op이다.
      if (AppFeatureConfig.isFirebaseEnabled && AppFeatureConfig.isFirebaseRemoteConfigEnabled) {
        await RemoteConfigService.instance.initialize();
      }

      // A/B 테스팅 초기화 (P1-14a: ABTestService가 SSOT — 로컬 할당이라
      // Firebase 미필수, RC 킬스위치는 서비스 내부에서 RC 플래그로 가드)
      if (AppFeatureConfig.isABTestingEnabled) {
        await abTestService.initialize();
      }

      // Push Notification 초기화 (알림이 활성화된 경우에만).
      // 플래그를 notifications 패키지에 주입한 뒤 초기화 (P2-20c PR3).
      if (AppFeatureConfig.isNotificationEnabled) {
        NotificationService.configure(const NotificationsConfig(
          notificationEnabled: true,
        ));
        FcmNotificationService.configure(FcmConfig(
          firebaseEnabled: AppFeatureConfig.isFirebaseEnabled,
          messagingEnabled: AppFeatureConfig.isFirebaseMessagingEnabled,
        ));
        await RaynearNotification().initialize();
      }

      // 인앱 구매 초기화 (인앱 구매가 활성화된 경우에만)
      if (AppFeatureConfig.isInAppPurchaseEnabled) {
        await _loadProducts();
      }
    } catch (e) {
      logger.e('Error in non-critical services: $e');
      // 비중요 서비스 실패는 앱 실행에 영향을 주지 않도록 처리
    }
  }

  static String get apiUrl => _config['API_URL'] ?? '';
  static String get apiKey => _config['API_KEY'] ?? '';

  // ── 앱 정체성/카피 (P1-15, gen_env 주입) ──
  /// 프라이버시 정책 URL — 비어 있으면 gen_env가 legal-pages(P1-13e)
  /// Pages 컨벤션으로 repository에서 도출해 채운다.
  static String get privacyPolicyUrl => dotenv.env['PRIVACY_POLICY_URL'] ?? '';
  static String get termsOfServiceUrl =>
      dotenv.env['TERMS_OF_SERVICE_URL'] ?? '';

  /// App Store 숫자 ID (project.yaml listing.apple_app_id) —
  /// 강제 업데이트 스토어 링크에 사용. 비어 있으면 iOS 스토어 열기 불가.
  static String get appleAppStoreId => dotenv.env['APPLE_APP_STORE_ID'] ?? '';

  /// 구독 화면 카피 (project.yaml iap.headline_copy/benefits_copy) —
  /// 비어 있으면 뷰가 기본 번역 키를 사용.
  static String get subscriptionHeadline =>
      dotenv.env['SUBSCRIPTION_HEADLINE'] ?? '';
  static String get subscriptionBenefits =>
      dotenv.env['SUBSCRIPTION_BENEFITS'] ?? '';

  /// GoRouter 등에 연결할 네비게이션 옵저버 (firebase_services 제공).
  /// Analytics 비활성화 시 null — 옵저버를 연결하지 않는다.
  static NavigatorObserver? get observer => FirebaseService.navigatorObserver;

  /// crash 리포트 분류 메타데이터 (P1-14c).
  ///
  /// 포크/프로파일/플래그 구성이 제각각인 파생 앱들의 크래시를
  /// 구성 단위로 묶어 보기 위한 키. AB variant 키는 ABTestService가
  /// 초기화 시점에 별도로 설정한다 (`ab_<experiment>`).
  Future<void> _setCrashClassificationKeys() async {
    try {
      await CrashReporter.setCustomKey('flavor', environment.name);
      await CrashReporter.setCustomKey(
          'app_profile', dotenv.env['APP_PROFILE'] ?? 'unknown');
      await CrashReporter.setCustomKey(
          'template_version', dotenv.env['TEMPLATE_VERSION'] ?? 'unknown');

      final enabledFlags = AppFeatureConfig.toMap()
          .entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .join(',');
      // Crashlytics 커스텀 키 값 한도 1024자
      await CrashReporter.setCustomKey(
          'enabled_flags',
          enabledFlags.length > 1024
              ? enabledFlags.substring(0, 1024)
              : enabledFlags);
    } catch (e) {
      logger.w('Crash classification keys setup failed: $e');
    }
  }

  // 앱 실행 횟수 증가 및 리뷰 확인 (P1-14b: AppReviewService 통합 —
  // 세션 추적 + 재요청 간격 제한, 플래그로 제어 가능)
  Future<void> incrementAppLaunchCountAndCheckForReview() async {
    final settingsNotifier = ProviderContainer().read(settingsProvider.notifier);
    await settingsNotifier.incrementAppLaunchCount();

    if (!AppFeatureConfig.isAppReviewPromptEnabled) return;

    final reviewService = AppReviewService();
    await reviewService.incrementSessionCount();
    if (await reviewService.shouldRequestReview()) {
      final requested = await reviewService.requestReview();
      logger.d('In-app review ${requested ? "requested" : "skipped"}');
    }
  }

  final Map<String, String> _productIds = {
    'monthly': _config['MONTHLY'] ?? '',
    'yearly': _config['YEARLY'] ?? '',
    'lifetime': _config['LIFETIME'] ?? '',
  };

  Map<String, String> get productIds => _productIds;

  static Future<void> _loadProducts() async {
    // 인앱 구매가 비활성화된 경우 조기 종료
    if (!AppFeatureConfig.isInAppPurchaseEnabled) {
      logger.d('In-App Purchases are disabled by feature flag');
      _products = [];
      return;
    }

    try {
      // Google Play 결제 사용 가능 여부 확인
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        logger.w('In-app purchases are not available on this device');
        _products = [];
        return;
      }

      final appConfig = AppConfig();
      final productIds = appConfig.productIds.values.toSet();
      final response = await InAppPurchase.instance.queryProductDetails(productIds);
      _products = response.productDetails;
    } catch (e) {
      logger.e('Error occurred while loading product information: $e');
      _products = [];
    }
  }

  static List<ProductDetails> get products => _products;

  // 전체 config에 접근하기 위한 getter
  static Map<String, dynamic> get config => Map.unmodifiable(_config);

  // 특정 키로 config 값을 가져오는 generic getter
  static T? getValue<T>(String key) => _config[key] as T?;
}

final appConfigProvider = Provider<AppConfig>((ref) => throw UnimplementedError());
