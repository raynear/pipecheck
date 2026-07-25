/// 기능 정의
class FeatureDefinition {
  final String name;
  final String displayName;
  final List<String> configFlags;
  final List<String> packages;
  final List<String> filesToBackup;
  final List<String> dependencies;

  const FeatureDefinition({
    required this.name,
    required this.displayName,
    required this.configFlags,
    this.packages = const [],
    this.filesToBackup = const [],
    this.dependencies = const [],
  });
}

/// 지원하는 기능 목록
final Map<String, FeatureDefinition> featureDefinitions = {
  'ads': FeatureDefinition(
    name: 'ads',
    displayName: 'Ads (광고)',
    configFlags: ['isAdsEnabled'],
    packages: ['google_mobile_ads'],
    filesToBackup: [
      'lib/core/services/ad_service.dart',
      'lib/core/widgets/ads/',
    ],
  ),
  'subscription': FeatureDefinition(
    name: 'subscription',
    displayName: 'Subscription/IAP (구독/인앱 결제)',
    configFlags: ['isSubscriptionEnabled', 'isInAppPurchaseEnabled'],
    packages: ['in_app_purchase'],
    filesToBackup: [
      'lib/features/subscription/',
      'lib/core/services/in_app_purchase_service.dart',
    ],
  ),
  'firebase': FeatureDefinition(
    name: 'firebase',
    displayName: 'Firebase (분석/크래시)',
    configFlags: [
      'isFirebaseEnabled',
      'isFirebaseAnalyticsEnabled',
      'isFirebaseCrashlyticsEnabled',
      'isFirebaseRemoteConfigEnabled',
      'isFirebaseMessagingEnabled',
    ],
    packages: [
      'firebase_core',
      'firebase_analytics',
      'firebase_crashlytics',
      'firebase_remote_config',
      'firebase_messaging',
    ],
    filesToBackup: [
      'lib/core/services/firebase_service.dart',
      'lib/firebase_options.dart',
    ],
  ),
  'notification': FeatureDefinition(
    name: 'notification',
    displayName: 'Notifications (알림)',
    configFlags: ['isNotificationEnabled'],
    packages: ['awesome_notifications'],
    filesToBackup: [
      'lib/core/services/notification_service.dart',
    ],
  ),
  'biometric': FeatureDefinition(
    name: 'biometric',
    displayName: 'Biometric Auth (생체 인증)',
    configFlags: ['isBiometricAuthEnabled'],
    packages: ['local_auth'],
    filesToBackup: [
      'lib/core/services/authentication_service.dart',
    ],
  ),
  'location': FeatureDefinition(
    name: 'location',
    displayName: 'Location (위치)',
    configFlags: ['isLocationEnabled'],
    packages: ['geolocator', 'geocoding'],
    filesToBackup: [],
  ),
  'onboarding': FeatureDefinition(
    name: 'onboarding',
    displayName: 'Onboarding (온보딩)',
    configFlags: ['isOnboardingEnabled'],
    packages: [],
    filesToBackup: [
      'lib/features/onboarding/',
    ],
  ),
  'reEngagement': FeatureDefinition(
    name: 'reEngagement',
    displayName: 'Re-Engagement Notifications (재참여 알림)',
    configFlags: ['isReEngagementEnabled'],
    packages: [],
    filesToBackup: [
      'lib/core/services/notification_service.dart',
    ],
    dependencies: ['notification'],
  ),
  'reminder': FeatureDefinition(
    name: 'reminder',
    displayName: 'Reminder Notifications (리마인더 알림)',
    configFlags: ['isReminderEnabled'],
    packages: [],
    filesToBackup: [
      'lib/core/services/notification_service.dart',
    ],
    dependencies: ['notification'],
  ),
  'backgroundNotification': FeatureDefinition(
    name: 'backgroundNotification',
    displayName: 'Background Notifications (백그라운드 알림)',
    configFlags: ['isBackgroundNotificationEnabled'],
    packages: [],
    filesToBackup: [
      'lib/core/services/notification_service.dart',
    ],
    dependencies: ['notification'],
  ),
  'darkMode': FeatureDefinition(
    name: 'darkMode',
    displayName: 'Dark Mode (다크 모드)',
    configFlags: ['isDarkModeEnabled'],
    packages: ['flex_color_scheme'],
    filesToBackup: [
      'lib/core/design/design_system_provider.dart',
    ],
  ),
  'multiLanguage': FeatureDefinition(
    name: 'multiLanguage',
    displayName: 'Multi-Language Support (다국어 지원)',
    configFlags: ['isMultiLanguageEnabled'],
    packages: ['easy_localization', 'flutter_localized_locales'],
    filesToBackup: [
      'assets/languages/',
      'lib/core/state/settings.dart',
    ],
  ),
  'abTesting': FeatureDefinition(
    name: 'abTesting',
    displayName: 'A/B Testing (A/B 테스팅)',
    configFlags: ['isABTestingEnabled'],
    packages: [],
    filesToBackup: [
      'lib/core/services/ab_test_service.dart',
    ],
  ),
  'crashReporting': FeatureDefinition(
    name: 'crashReporting',
    displayName: 'Crash Reporting (크래시 리포팅)',
    configFlags: ['isFirebaseCrashlyticsEnabled'],
    packages: ['firebase_crashlytics'],
    filesToBackup: [
      'lib/core/services/firebase_service.dart',
    ],
    dependencies: ['firebase'],
  ),
  'splashAd': FeatureDefinition(
    name: 'splashAd',
    displayName: 'Splash Interstitial Ad (스플래시 전면 광고)',
    configFlags: ['isSplashInterstitialAdEnabled'],
    packages: [],
    filesToBackup: [
      'lib/core/services/ad_service.dart',
    ],
    dependencies: ['ads'],
  ),
};
