import 'package:flutter/foundation.dart';
import 'package:utils/utils.dart';

/// 앱의 모든 기능을 중앙에서 관리하는 설정 클래스
///
/// 각 기능을 ON/OFF 할 수 있도록 static 변수로 관리하여
/// 개발/테스트 환경에서 필요한 기능만 활성화할 수 있습니다.
///
/// 플래그 체계는 docs/MODULES.md가 운영 기준입니다 (P1-16):
/// - 코어 셸 플래그 12개(현행 8 + 예약 4)만 장기 유지
/// - `[two-phase → packages/X]` 표기 플래그는 P2-20 추출 시 해당 패키지
///   설정으로 이동 (그 전까지 여기서 동작 유지)
/// - reader 0인 플래그는 만들지 않는다 (예약 플래그는 소비자와 같은 PR에서)
///
/// 사용 예시:
/// ```dart
/// if (AppFeatureConfig.isNotificationEnabled) {
///   // 알림 기능 실행
/// }
/// ```
class AppFeatureConfig {
  AppFeatureConfig._();

  // ========== Notification Features ==========
  // [two-phase → packages/notifications] (P2-20)
  static bool isNotificationEnabled = false;
  static bool isReEngagementEnabled = true;
  static bool isReminderEnabled = true;
  static bool isBackgroundNotificationEnabled = true;

  // ========== Database Features ==========
  // (Drift 로컬 DB는 무조건 생성 — 플래그 없음. local-only가 공식 기본,
  //  docs/MODULES.md §1-4. supabase는 P1-16.5a에서 철거됨)

  // ========== Authentication Features ==========
  static bool isAuthenticationEnabled = true;
  // [two-phase → packages/authentication] (P2-20)
  static bool isBiometricAuthEnabled = true;
  // 로컬 PIN 잠금 (P2-23h). 기본 OFF(opt-in) — 켜는 포크는 설정 화면의
  // 보안 섹션에서 PIN을 설정한 뒤 잠금 방식으로 선택한다. PIN 엔진은
  // PinService(secure_storage, 점진 잠금)다. 생체와 독립 능력 가드.
  static bool isPinAuthEnabled = false;
  // 서버 백엔드 없음(16.5a 철거) — P1-16.5b Firebase Auth 전환 시 재배선.
  // 그 전까지 켜도 로그인/가입은 항상 실패 반환 (크래시 없음).
  static bool isEmailAuthEnabled = false;
  // 소셜 인증 (Google/Apple → Firebase signInWithCredential, P2-21.5b).
  // 기본 OFF — 켜는 포크는 OAuth 자격증명(Google 클라ID/Apple Service ID) 설정 필요.
  // [two-phase → packages/authentication] (P2-20)
  static bool isSocialAuthEnabled = false;
  // 스토어 컴플라이언스: 서버 계정(email/social)이 켜진 앱은 계정 삭제 진입점 필수.
  // 기본 ON(opt-out) — 끄려면 컴플라이언스 영향 검토 후 명시적으로 끌 것.
  // [two-phase → packages/authentication] (P2-20)
  static bool isAccountDeletionEnabled = true;

  // ========== Cloud Services ==========
  // [two-phase → packages/firebase] (P2-20, Messaging은 notifications 공동)
  static bool isFirebaseEnabled = true;
  static bool isFirebaseAnalyticsEnabled = true;
  static bool isFirebaseCrashlyticsEnabled = true;
  static bool isFirebaseRemoteConfigEnabled = true;
  static bool isFirebaseMessagingEnabled = true;

  // ========== In-App Features ==========
  // [two-phase → packages/monetization] (P2-20, 항목 21 하드 게이트)
  static bool isInAppPurchaseEnabled = false;
  static bool isSubscriptionEnabled = false;
  // [two-phase → packages/ads] (P2-20, UMP/COPPA/TFUA 노브 동반 이동)
  static bool isAdsEnabled = false;
  static bool isSplashInterstitialAdEnabled = true;
  static bool isAppOpenAdEnabled = false;
  // UMP/EEA 동의 수집 (스토어 컴플라이언스). 기본 ON(opt-out) —
  // 끄면 EEA 사용자에게 동의 없이 광고가 나가므로 영향 검토 후 끌 것.
  static bool isUmpConsentEnabled = true;
  // COPPA 노브: 아동 대상 앱(child-directed)이면 켤 것.
  // 켜면 tagForChildDirectedTreatment=yes + maxAdContentRating=G.
  static bool isChildDirectedAdsEnabled = false;
  // TFUA 노브: EEA 동의 연령 미만 사용자 대상이면 켤 것.
  // COPPA 노브와 동시에 켜면 COPPA가 우선한다 (AdConsentManager 참조).
  static bool isUnderAgeOfConsentEnabled = false;

  // ========== Analytics & Tracking ==========
  // (isAnalyticsEnabled/isCrashReportingEnabled는 isFirebase* 중복으로 삭제 — P1-16)
  // [two-phase → packages/ab_testing] (P2-20)
  static bool isABTestingEnabled = false;

  // ========== Other Features ==========
  static bool isOnboardingEnabled = true;
  // [two-phase → packages/location] (P2-20)
  static bool isLocationEnabled = false;
  // 딥링크 (P2-23a): app_links로 커스텀 스킴/유니버설 링크를 수신해 GoRouter로
  // 라우팅. 기본 OFF(opt-in) — 켜는 포크는 project.yaml deep_link로 네이티브
  // 스킴/도메인을 선언하고 ./run generate-deeplink(Stage 1b)로 매니페스트 생성.
  static bool isDeepLinkEnabled = false;
  static bool isDarkModeEnabled = true;
  static bool isMultiLanguageEnabled = true;
  static bool isForceUpdateEnabled = true;
  // 점검 모드 (P2-23b): RC `maintenance_mode`가 true면 앱 전체를 MaintenanceView로
  // 차단. RC 의존(아래 _dependencies) — firebase/RC 없는 포크는 자동 OFF(no-op).
  // 기본 ON이라도 RC 값이 false면 점검 화면은 뜨지 않는다(운영이 켤 때만 발동).
  static bool isMaintenanceModeEnabled = true;
  static bool isAppReviewPromptEnabled = true;
  static bool isNetworkMonitoringEnabled = true;
  static bool isPrivacyConsentEnabled = true;
  // 데이터 내보내기 (GDPR 이동권, P2-23f): 로컬 Drift → JSON 파일 공유.
  // 로컬 DB는 항상 존재하므로 의존성 없음. 기본 ON(opt-out, 컴플라이언스 친화).
  static bool isDataExportEnabled = true;

  // 백업/복원 (P2-24): 로컬 Drift → JSON 파일 백업 + merge(현재 우선) 복원.
  // 로컬 DB는 항상 존재하므로 의존성 없음. opt-in 기본 OFF.
  static bool isBackupRestoreEnabled = false;

  // What's-new 다이얼로그 (P2-24): 마이너 이상 버전 업 후 첫 실행에 1회.
  // 로컬 버전 비교(SharedPreferences) — firebase/RC 무관. opt-in 기본 OFF.
  static bool isWhatsNewEnabled = false;

  // 홈 위젯 (iOS WidgetKit / Android App Widget): App Group 공유 컨테이너로
  // 위젯 데이터 read/write. 네이티브 위젯 확장 셋업이 필요하므로 opt-in 기본 OFF.
  static bool isHomeWidgetEnabled = false;

  // 학습/활동 이력·스트릭 (WS-B): 세션 기록에서 스트릭·이번달 지표를 파생하는
  // 리텐션 엔진. 카운터 미저장(이벤트 소싱), SharedPreferences 로컬 — 의존성 없음.
  // 학습·습관·피트니스 등 세션 기반 앱용. opt-in 기본 OFF.
  static bool isStudyHistoryEnabled = false;

  // ========== Developer Features ==========
  // (isTestMode/isDebugMode/isVerboseLoggingEnabled는 reader 0으로 삭제 — P1-16)
  static bool isDeveloperOptionsEnabled = kDebugMode;

  // ========== Field Registry ==========

  static final Map<String, _FieldAccessor> _fields = {
    'isNotificationEnabled': _FieldAccessor(() => isNotificationEnabled, (v) => isNotificationEnabled = v),
    'isReEngagementEnabled': _FieldAccessor(() => isReEngagementEnabled, (v) => isReEngagementEnabled = v),
    'isReminderEnabled': _FieldAccessor(() => isReminderEnabled, (v) => isReminderEnabled = v),
    'isBackgroundNotificationEnabled': _FieldAccessor(() => isBackgroundNotificationEnabled, (v) => isBackgroundNotificationEnabled = v),
    'isAuthenticationEnabled': _FieldAccessor(() => isAuthenticationEnabled, (v) => isAuthenticationEnabled = v),
    'isBiometricAuthEnabled': _FieldAccessor(() => isBiometricAuthEnabled, (v) => isBiometricAuthEnabled = v),
    'isPinAuthEnabled': _FieldAccessor(() => isPinAuthEnabled, (v) => isPinAuthEnabled = v),
    'isEmailAuthEnabled': _FieldAccessor(() => isEmailAuthEnabled, (v) => isEmailAuthEnabled = v),
    'isSocialAuthEnabled': _FieldAccessor(() => isSocialAuthEnabled, (v) => isSocialAuthEnabled = v),
    'isAccountDeletionEnabled': _FieldAccessor(() => isAccountDeletionEnabled, (v) => isAccountDeletionEnabled = v),
    'isFirebaseEnabled': _FieldAccessor(() => isFirebaseEnabled, (v) => isFirebaseEnabled = v),
    'isFirebaseAnalyticsEnabled': _FieldAccessor(() => isFirebaseAnalyticsEnabled, (v) => isFirebaseAnalyticsEnabled = v),
    'isFirebaseCrashlyticsEnabled': _FieldAccessor(() => isFirebaseCrashlyticsEnabled, (v) => isFirebaseCrashlyticsEnabled = v),
    'isFirebaseRemoteConfigEnabled': _FieldAccessor(() => isFirebaseRemoteConfigEnabled, (v) => isFirebaseRemoteConfigEnabled = v),
    'isFirebaseMessagingEnabled': _FieldAccessor(() => isFirebaseMessagingEnabled, (v) => isFirebaseMessagingEnabled = v),
    'isInAppPurchaseEnabled': _FieldAccessor(() => isInAppPurchaseEnabled, (v) => isInAppPurchaseEnabled = v),
    'isSubscriptionEnabled': _FieldAccessor(() => isSubscriptionEnabled, (v) => isSubscriptionEnabled = v),
    'isAdsEnabled': _FieldAccessor(() => isAdsEnabled, (v) => isAdsEnabled = v),
    'isSplashInterstitialAdEnabled': _FieldAccessor(() => isSplashInterstitialAdEnabled, (v) => isSplashInterstitialAdEnabled = v),
    'isAppOpenAdEnabled': _FieldAccessor(() => isAppOpenAdEnabled, (v) => isAppOpenAdEnabled = v),
    'isUmpConsentEnabled': _FieldAccessor(() => isUmpConsentEnabled, (v) => isUmpConsentEnabled = v),
    'isChildDirectedAdsEnabled': _FieldAccessor(() => isChildDirectedAdsEnabled, (v) => isChildDirectedAdsEnabled = v),
    'isUnderAgeOfConsentEnabled': _FieldAccessor(() => isUnderAgeOfConsentEnabled, (v) => isUnderAgeOfConsentEnabled = v),
    'isABTestingEnabled': _FieldAccessor(() => isABTestingEnabled, (v) => isABTestingEnabled = v),
    'isOnboardingEnabled': _FieldAccessor(() => isOnboardingEnabled, (v) => isOnboardingEnabled = v),
    'isLocationEnabled': _FieldAccessor(() => isLocationEnabled, (v) => isLocationEnabled = v),
    'isDeepLinkEnabled': _FieldAccessor(() => isDeepLinkEnabled, (v) => isDeepLinkEnabled = v),
    'isDarkModeEnabled': _FieldAccessor(() => isDarkModeEnabled, (v) => isDarkModeEnabled = v),
    'isMultiLanguageEnabled': _FieldAccessor(() => isMultiLanguageEnabled, (v) => isMultiLanguageEnabled = v),
    'isForceUpdateEnabled': _FieldAccessor(() => isForceUpdateEnabled, (v) => isForceUpdateEnabled = v),
    'isMaintenanceModeEnabled': _FieldAccessor(() => isMaintenanceModeEnabled, (v) => isMaintenanceModeEnabled = v),
    'isAppReviewPromptEnabled': _FieldAccessor(() => isAppReviewPromptEnabled, (v) => isAppReviewPromptEnabled = v),
    'isNetworkMonitoringEnabled': _FieldAccessor(() => isNetworkMonitoringEnabled, (v) => isNetworkMonitoringEnabled = v),
    'isPrivacyConsentEnabled': _FieldAccessor(() => isPrivacyConsentEnabled, (v) => isPrivacyConsentEnabled = v),
    'isDataExportEnabled': _FieldAccessor(() => isDataExportEnabled, (v) => isDataExportEnabled = v),
    'isBackupRestoreEnabled': _FieldAccessor(() => isBackupRestoreEnabled, (v) => isBackupRestoreEnabled = v),
    'isWhatsNewEnabled': _FieldAccessor(() => isWhatsNewEnabled, (v) => isWhatsNewEnabled = v),
    'isHomeWidgetEnabled': _FieldAccessor(() => isHomeWidgetEnabled, (v) => isHomeWidgetEnabled = v),
    'isStudyHistoryEnabled': _FieldAccessor(() => isStudyHistoryEnabled, (v) => isStudyHistoryEnabled = v),
    'isDeveloperOptionsEnabled': _FieldAccessor(() => isDeveloperOptionsEnabled, (v) => isDeveloperOptionsEnabled = v),
  };

  // ========== Dependency Rules ==========
  // child -> parent: if parent is OFF, child is forced OFF.

  static const Map<String, String> _dependencies = {
    'isFirebaseAnalyticsEnabled': 'isFirebaseEnabled',
    'isFirebaseCrashlyticsEnabled': 'isFirebaseEnabled',
    'isFirebaseRemoteConfigEnabled': 'isFirebaseEnabled',
    'isFirebaseMessagingEnabled': 'isFirebaseEnabled',
    'isReEngagementEnabled': 'isNotificationEnabled',
    'isReminderEnabled': 'isNotificationEnabled',
    'isBackgroundNotificationEnabled': 'isNotificationEnabled',
    'isBiometricAuthEnabled': 'isAuthenticationEnabled',
    'isPinAuthEnabled': 'isAuthenticationEnabled',
    'isEmailAuthEnabled': 'isAuthenticationEnabled',
    'isSocialAuthEnabled': 'isAuthenticationEnabled',
    'isAccountDeletionEnabled': 'isAuthenticationEnabled',
    'isSplashInterstitialAdEnabled': 'isAdsEnabled',
    'isAppOpenAdEnabled': 'isAdsEnabled',
    'isUmpConsentEnabled': 'isAdsEnabled',
    'isChildDirectedAdsEnabled': 'isAdsEnabled',
    'isUnderAgeOfConsentEnabled': 'isAdsEnabled',
    'isABTestingEnabled': 'isFirebaseRemoteConfigEnabled',
    'isMaintenanceModeEnabled': 'isFirebaseRemoteConfigEnabled',
  };

  /// 의존성을 해소합니다.
  /// 부모 기능이 OFF이면 자식 기능도 자동으로 OFF됩니다.
  static void resolveDependencies() {
    for (final entry in _dependencies.entries) {
      final child = _fields[entry.key];
      final parent = _fields[entry.value];
      if (child != null && parent != null && !parent.get()) {
        child.set(false);
      }
    }
  }

  // ========== Configuration Methods ==========

  static void enableAllFeatures() {
    _setAll(true);
    logger.d('All features enabled');
  }

  static void disableAllFeatures() {
    _setAll(false);
    logger.d('All features disabled');
  }

  /// 부팅 설정을 적용합니다 — app_config.yaml의 profile/features가
  /// env 산출물(APP_PROFILE, FF_*)을 거쳐 전달됩니다.
  ///
  /// 서비스 초기화 **전에** 호출되어야 합니다. 이전의
  /// applyProductionConfig()=enableAllFeatures()는 release에서 모든 플래그를
  /// 서비스 init 후 강제 ON해 미초기화 서비스 크래시(AdService 등)를 만들었음.
  static void applyBootConfig({
    String? profileName,
    Map<String, bool> overrides = const {},
  }) {
    final profile = AppProfile.values
        .where((p) => p.name == profileName)
        .firstOrNull ??
        AppProfile.standard;
    profile.apply();

    if (overrides.isNotEmpty) {
      fromMap(overrides);
    }

    // 개발자 플래그는 yaml이 아니라 빌드 모드가 결정
    isDeveloperOptionsEnabled = kDebugMode;

    resolveDependencies();
    logger.i('Boot config applied: profile=${profile.name}, '
        'overrides=${overrides.keys.toList()}');
  }

  /// 원격(Remote Config) 기능 플래그 override를 적용한다 (RC→플래그 브리지, P2-23.5b).
  ///
  /// 부팅 패스에서 [applyBootConfig](yaml profile + FF_*) **후**, 서비스 init
  /// **전**에 호출한다 — P0-4의 "플래그 freeze 후 서비스 init" 불변식을 유지한다.
  ///
  /// 방향별 정책:
  /// - **OFF(false)**: 무조건 적용 (kill-switch — 끄는 데는 사전 셋업이 필요 없다).
  /// - **ON(true)**: [onGuards]에 등록된 능력 가드가 통과할 때만 적용. 가드가
  ///   없거나 실패하면 거부한다 — 포크가 셋업하지 않은 서비스를 원격으로 강제
  ///   기동해 미초기화 크래시(P0-4류: 광고 ID 없는데 AdService init 등)가 나는
  ///   것을 막는다.
  ///
  /// [remote]의 키는 `feature_` 접두사를 제거한 플래그명이다
  /// (`{'isAdsEnabled': false}`). 알 수 없는 키는 무시한다.
  static void applyRemoteOverrides(
    Map<String, bool> remote, {
    Map<String, bool Function()> onGuards = const {},
  }) {
    for (final entry in remote.entries) {
      final accessor = _fields[entry.key];
      if (accessor == null) {
        logger.w('Remote override: unknown flag "${entry.key}" ignored');
        continue;
      }
      if (!entry.value) {
        accessor.set(false); // kill-switch — 항상 허용
        logger.i('Remote override: ${entry.key} forced OFF');
      } else {
        final guard = onGuards[entry.key];
        if (guard != null && guard()) {
          accessor.set(true);
          logger.i('Remote override: ${entry.key} forced ON (capability OK)');
        } else {
          logger.w('Remote override: ${entry.key} ON denied '
              '(no capability guard or guard failed)');
        }
      }
    }
    // 의존성 재해소 — 부모가 꺼지면 자식도 OFF (예: firebase kill → analytics OFF)
    resolveDependencies();
  }

  static Map<String, bool> toMap() {
    return _fields.map((key, accessor) => MapEntry(key, accessor.get()));
  }

  static void fromMap(Map<String, bool> config) {
    for (final entry in config.entries) {
      _fields[entry.key]?.set(entry.value);
    }
  }

  static void printFeatureSummary() {
    const groups = <String, List<String>>{
      'Notification': ['isNotificationEnabled', 'isReEngagementEnabled', 'isReminderEnabled', 'isBackgroundNotificationEnabled'],
      'Authentication': ['isAuthenticationEnabled', 'isBiometricAuthEnabled', 'isPinAuthEnabled', 'isEmailAuthEnabled', 'isSocialAuthEnabled', 'isAccountDeletionEnabled'],
      'Cloud Services': ['isFirebaseEnabled', 'isFirebaseAnalyticsEnabled', 'isFirebaseCrashlyticsEnabled', 'isFirebaseRemoteConfigEnabled', 'isFirebaseMessagingEnabled'],
      'Monetization': ['isInAppPurchaseEnabled', 'isSubscriptionEnabled', 'isAdsEnabled', 'isSplashInterstitialAdEnabled', 'isAppOpenAdEnabled', 'isUmpConsentEnabled', 'isChildDirectedAdsEnabled', 'isUnderAgeOfConsentEnabled'],
      'Analytics': ['isABTestingEnabled'],
      'Other Features': ['isOnboardingEnabled', 'isLocationEnabled', 'isDeepLinkEnabled', 'isDarkModeEnabled', 'isMultiLanguageEnabled', 'isForceUpdateEnabled', 'isMaintenanceModeEnabled', 'isAppReviewPromptEnabled', 'isNetworkMonitoringEnabled', 'isPrivacyConsentEnabled', 'isDataExportEnabled', 'isBackupRestoreEnabled', 'isWhatsNewEnabled', 'isHomeWidgetEnabled', 'isStudyHistoryEnabled'],
      'Developer': ['isDeveloperOptionsEnabled'],
    };

    logger.d('========== Feature Configuration Summary ==========');
    for (final group in groups.entries) {
      logger.d('${group.key}:');
      for (final key in group.value) {
        final value = _fields[key]?.get() ?? false;
        final label = key.replaceAll('is', '').replaceAll('Enabled', '');
        logger.d('  - $label: ${value ? "ON" : "OFF"}');
      }
    }
    logger.d('===================================================');
  }

  static void _setAll(bool value) {
    for (final accessor in _fields.values) {
      accessor.set(value);
    }
  }
}

// ========== App Profiles ==========

/// Profile presets for quick feature configuration.
///
/// ```dart
/// AppProfile.minimal.apply();   // Simple utility app
/// AppProfile.premium.apply();   // Monetized app
/// ```
enum AppProfile {
  /// Auth + Local DB only. No cloud services.
  minimal,
  /// Firebase + Analytics + Crashlytics. No monetization.
  standard,
  /// Standard + Ads + IAP + Subscription + Push Notifications.
  premium,
  /// Everything enabled.
  enterprise,
}

extension AppProfileExtension on AppProfile {
  void apply() {
    AppFeatureConfig.disableAllFeatures();

    switch (this) {
      case AppProfile.minimal:
        _applyMinimal();
      case AppProfile.standard:
        _applyMinimal();
        _applyStandard();
      case AppProfile.premium:
        _applyMinimal();
        _applyStandard();
        _applyPremium();
      case AppProfile.enterprise:
        AppFeatureConfig.enableAllFeatures();
    }

    AppFeatureConfig.resolveDependencies();
    logger.i('AppProfile: $name applied');
  }

  String get description {
    switch (this) {
      case AppProfile.minimal:
        return 'Auth + Local DB (유틸리티 앱)';
      case AppProfile.standard:
        return 'Firebase + Analytics (일반 앱)';
      case AppProfile.premium:
        return 'Ads + IAP + Push (수익화 앱)';
      case AppProfile.enterprise:
        return '전체 기능 (엔터프라이즈)';
    }
  }

  List<String> get enabledCategories {
    switch (this) {
      case AppProfile.minimal:
        return ['Auth', 'Local DB', 'Onboarding'];
      case AppProfile.standard:
        return ['Auth', 'Local DB', 'Firebase', 'Analytics', 'Crashlytics', 'Onboarding'];
      case AppProfile.premium:
        return [
          'Auth', 'Local DB', 'Firebase', 'Analytics', 'Crashlytics',
          'Remote Config', 'Push', 'Ads', 'IAP', 'Subscription', 'Onboarding',
        ];
      case AppProfile.enterprise:
        return ['All Features'];
    }
  }
}

void _applyMinimal() {
  AppFeatureConfig.isAuthenticationEnabled = true;
  AppFeatureConfig.isBiometricAuthEnabled = true;
  AppFeatureConfig.isAccountDeletionEnabled = true;
  AppFeatureConfig.isAppReviewPromptEnabled = true;
  AppFeatureConfig.isOnboardingEnabled = true;
  AppFeatureConfig.isDarkModeEnabled = true;
  AppFeatureConfig.isMultiLanguageEnabled = true;
  // GDPR 데이터 내보내기 — 로컬 데이터가 있는 모든 프로파일의 기본 기능 (P2-23f)
  AppFeatureConfig.isDataExportEnabled = true;
}

void _applyStandard() {
  AppFeatureConfig.isFirebaseEnabled = true;
  AppFeatureConfig.isFirebaseAnalyticsEnabled = true;
  AppFeatureConfig.isFirebaseCrashlyticsEnabled = true;
  AppFeatureConfig.isFirebaseRemoteConfigEnabled = true;
  // RC가 있으면 점검 모드 안전망도 기본 ON — 실제 차단은 RC 값이 결정 (P2-23b)
  AppFeatureConfig.isMaintenanceModeEnabled = true;
}

void _applyPremium() {
  AppFeatureConfig.isAdsEnabled = true;
  AppFeatureConfig.isSplashInterstitialAdEnabled = true;
  // 컴플라이언스: 광고가 켜지면 UMP 동의 수집도 함께 켠다 (opt-out)
  AppFeatureConfig.isUmpConsentEnabled = true;
  AppFeatureConfig.isInAppPurchaseEnabled = true;
  AppFeatureConfig.isSubscriptionEnabled = true;
  AppFeatureConfig.isNotificationEnabled = true;
  AppFeatureConfig.isReEngagementEnabled = true;
  AppFeatureConfig.isReminderEnabled = true;
  AppFeatureConfig.isFirebaseMessagingEnabled = true;
  AppFeatureConfig.isABTestingEnabled = true;
}

class _FieldAccessor {
  _FieldAccessor(this.get, this.set);
  final bool Function() get;
  final void Function(bool) set;
}
