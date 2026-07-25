import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// Feature Configuration 화면
/// 
/// 개발자가 앱의 각 기능을 ON/OFF할 수 있는 설정 화면입니다.
/// 디버그 모드에서만 접근 가능하며, 프로덕션 빌드에서는 숨겨집니다.
class FeatureConfigView extends ConsumerStatefulWidget {
  const FeatureConfigView({super.key});

  @override
  ConsumerState<FeatureConfigView> createState() => _FeatureConfigViewState();
}

class _FeatureConfigViewState extends ConsumerState<FeatureConfigView> {
  late Map<String, bool> _features;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    _features = AppFeatureConfig.toMap();
  }

  void _updateFeature(String key, bool value) {
    setState(() {
      _features[key] = value;
    });
    
    // AppFeatureConfig에 즉시 반영
    switch (key) {
      // Notification
      case 'isNotificationEnabled':
        AppFeatureConfig.isNotificationEnabled = value;
        break;
      case 'isReEngagementEnabled':
        AppFeatureConfig.isReEngagementEnabled = value;
        break;
      case 'isReminderEnabled':
        AppFeatureConfig.isReminderEnabled = value;
        break;
      case 'isBackgroundNotificationEnabled':
        AppFeatureConfig.isBackgroundNotificationEnabled = value;
        break;
      
      
      // Authentication
      case 'isAuthenticationEnabled':
        AppFeatureConfig.isAuthenticationEnabled = value;
        break;
      case 'isBiometricAuthEnabled':
        AppFeatureConfig.isBiometricAuthEnabled = value;
        break;
      case 'isEmailAuthEnabled':
        AppFeatureConfig.isEmailAuthEnabled = value;
        break;

      // Cloud Services
      case 'isFirebaseEnabled':
        AppFeatureConfig.isFirebaseEnabled = value;
        break;
      case 'isFirebaseAnalyticsEnabled':
        AppFeatureConfig.isFirebaseAnalyticsEnabled = value;
        break;
      case 'isFirebaseCrashlyticsEnabled':
        AppFeatureConfig.isFirebaseCrashlyticsEnabled = value;
        break;
      case 'isFirebaseRemoteConfigEnabled':
        AppFeatureConfig.isFirebaseRemoteConfigEnabled = value;
        break;
      case 'isFirebaseMessagingEnabled':
        AppFeatureConfig.isFirebaseMessagingEnabled = value;
        break;
      
      // In-App Features
      case 'isInAppPurchaseEnabled':
        AppFeatureConfig.isInAppPurchaseEnabled = value;
        break;
      case 'isSubscriptionEnabled':
        AppFeatureConfig.isSubscriptionEnabled = value;
        break;
      case 'isAdsEnabled':
        AppFeatureConfig.isAdsEnabled = value;
        break;
      
      // Analytics & Tracking
      case 'isABTestingEnabled':
        AppFeatureConfig.isABTestingEnabled = value;
        break;

      // Other Features
      case 'isLocationEnabled':
        AppFeatureConfig.isLocationEnabled = value;
        break;
      case 'isDarkModeEnabled':
        AppFeatureConfig.isDarkModeEnabled = value;
        break;
      case 'isMultiLanguageEnabled':
        AppFeatureConfig.isMultiLanguageEnabled = value;
        break;
    }
    
    logger.d('Feature $key updated to $value');
  }

  Widget _buildFeatureSection(String title, List<MapEntry<String, bool>> features) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...features.map((entry) => ListTile(
          title: Text(
            _formatFeatureName(entry.key),
            style: textTheme.bodyMedium,
          ),
          trailing: Switch.adaptive(
            value: entry.value,
            onChanged: (value) => _updateFeature(entry.key, value),
          ),
        )),
        const Divider(),
      ],
    );
  }

  String _formatFeatureName(String key) {
    // Remove 'is' prefix and 'Enabled' suffix, then add spaces
    String formatted = key
        .replaceFirst('is', '')
        .replaceAll('Enabled', '')
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
    
    // Capitalize first letter
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }
    
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 디버그 모드가 아니면 빈 화면 표시
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Not Available'),
        ),
        body: const Center(
          child: Text('This feature is only available in debug mode'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Feature Configuration'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'enable_all':
                  AppFeatureConfig.enableAllFeatures();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'disable_all':
                  AppFeatureConfig.disableAllFeatures();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'profile_minimal':
                  AppProfile.minimal.apply();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'profile_standard':
                  AppProfile.standard.apply();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'profile_premium':
                  AppProfile.premium.apply();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'profile_enterprise':
                  AppProfile.enterprise.apply();
                  _loadCurrentConfig();
                  setState(() {});
                  break;
                case 'print_summary':
                  AppFeatureConfig.printFeatureSummary();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'enable_all',
                child: Text('Enable All'),
              ),
              const PopupMenuItem(
                value: 'disable_all',
                child: Text('Disable All'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile_minimal',
                child: Text('Profile: minimal'),
              ),
              const PopupMenuItem(
                value: 'profile_standard',
                child: Text('Profile: standard'),
              ),
              const PopupMenuItem(
                value: 'profile_premium',
                child: Text('Profile: premium'),
              ),
              const PopupMenuItem(
                value: 'profile_enterprise',
                child: Text('Profile: enterprise'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'print_summary',
                child: Text('Print Summary'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Notification Features
            _buildFeatureSection(
              'Notification Features',
              _features.entries
                  .where((e) => e.key.contains('Notification') || 
                              e.key.contains('Reminder') || 
                              e.key.contains('ReEngagement'))
                  .toList(),
            ),
            
            // Database Features
            _buildFeatureSection(
              'Database Features',
              _features.entries
                  .where((e) => e.key.contains('Database') || 
                              e.key.contains('Sync'))
                  .toList(),
            ),
            
            // Authentication Features
            _buildFeatureSection(
              'Authentication Features',
              _features.entries
                  .where((e) => e.key.contains('Auth'))
                  .toList(),
            ),
            
            // Cloud Services
            _buildFeatureSection(
              'Cloud Services',
              _features.entries
                  .where((e) => e.key.contains('Firebase') || 
                              e.key.contains('ICloud'))
                  .toList(),
            ),
            
            // In-App Features
            _buildFeatureSection(
              'In-App Features',
              _features.entries
                  .where((e) => e.key.contains('Purchase') || 
                              e.key.contains('Subscription') || 
                              e.key.contains('Ads'))
                  .toList(),
            ),
            
            // Analytics & Tracking
            _buildFeatureSection(
              'Analytics & Tracking',
              _features.entries
                  .where((e) => e.key.contains('Analytics') || 
                              e.key.contains('ABTesting') || 
                              e.key.contains('CrashReporting'))
                  .toList(),
            ),
            
            // Other Features
            _buildFeatureSection(
              'Other Features',
              _features.entries
                  .where((e) => e.key.contains('Camera') || 
                              e.key.contains('Location') || 
                              e.key.contains('FileStorage') || 
                              e.key.contains('Badge') ||
                              e.key.contains('DarkMode') ||
                              e.key.contains('MultiLanguage'))
                  .toList(),
            ),
            
            // Developer Features
            _buildFeatureSection(
              'Developer Features',
              _features.entries
                  .where((e) => e.key.contains('Debug') || 
                              e.key.contains('Developer') || 
                              e.key.contains('Logging'))
                  .toList(),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}