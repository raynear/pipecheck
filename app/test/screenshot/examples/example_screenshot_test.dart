/// Example Screenshot Test
@Tags(['screenshot'])
library;

// Run with:
//   flutter drive \
//     --driver=test/screenshot/screenshot_driver.dart \
//     --target=test/screenshot/examples/example_screenshot_test.dart \
//     -d [device_id]

import 'package:pipecheck/config/app_config.dart';
import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/core/state/settings.dart';
import 'package:pipecheck/features/home/views/home_view.dart';
import 'package:pipecheck/main.dart' as app;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:integration_test/integration_test.dart';

import '../config/screenshot_config.dart';
import '../providers/mock_providers_base.dart';
import '../utils/screenshot_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Configure screenshot settings (optional - uses defaults if not called)
  ScreenshotConfig.instance.configure(
    outputDir: '../screenshots', // 경로 SSOT (P1-17b) — 미지정 시 기본값과 동일
    navigationWaitMs: 1000,
    pumpFrameCount: 30,
  );

  // ==========================================================================
  // Korean Screenshots
  // ==========================================================================
  testWidgets('Korean App Store Screenshots', (tester) async {
    // Disable features for screenshot tests
    _configureFeatureFlags();

    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    const locale = Locale('ko', 'KR');
    const lang = 'ko';

    // Screenshot 1: Home Screen (Dark Theme)
    debugPrint('=== Capturing Screenshot 1: Home (Dark) ===');
    await _captureHomeScreenshot(
      tester,
      locale: locale,
      lang: lang,
      themeMode: ThemeMode.dark,
      screenshotName: '01_home',
    );

    // Screenshot 2: Home Screen (Light Theme)
    debugPrint('=== Capturing Screenshot 2: Home (Light) ===');
    await _captureHomeScreenshot(
      tester,
      locale: locale,
      lang: lang,
      themeMode: ThemeMode.light,
      screenshotName: '02_home_light',
    );

    // Add more screenshots here...
    // Screenshot 3: Settings
    // Screenshot 4: Feature X
    // etc.

    debugPrint('=== All Korean screenshots completed! ===');
  });

  // ==========================================================================
  // English Screenshots
  // ==========================================================================
  testWidgets('English App Store Screenshots', (tester) async {
    // Disable features for screenshot tests
    _configureFeatureFlags();

    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    const locale = Locale('en', 'US');
    const lang = 'en';

    // Screenshot 1: Home Screen (Dark Theme)
    debugPrint('=== Capturing Screenshot 1: Home (Dark) ===');
    await _captureHomeScreenshot(
      tester,
      locale: locale,
      lang: lang,
      themeMode: ThemeMode.dark,
      screenshotName: '01_home',
    );

    // Screenshot 2: Home Screen (Light Theme)
    debugPrint('=== Capturing Screenshot 2: Home (Light) ===');
    await _captureHomeScreenshot(
      tester,
      locale: locale,
      lang: lang,
      themeMode: ThemeMode.light,
      screenshotName: '02_home_light',
    );

    // Add more screenshots here...

    debugPrint('=== All English screenshots completed! ===');
  });
}

/// Configure feature flags for screenshot testing
void _configureFeatureFlags() {
  AppFeatureConfig.isAuthenticationEnabled = false;
  AppFeatureConfig.isBiometricAuthEnabled = false;
  AppFeatureConfig.isOnboardingEnabled = false;
  AppFeatureConfig.isAdsEnabled = false;
  // Splash의 ATT/동의 게이트(P1-13a/13c)가 HomeView 도달을 막지 않게 OFF
  AppFeatureConfig.isPrivacyConsentEnabled = false;
  AppFeatureConfig.isUmpConsentEnabled = false;
}

/// Capture a home screen screenshot
Future<void> _captureHomeScreenshot(
  WidgetTester tester, {
  required Locale locale,
  required String lang,
  required ThemeMode themeMode,
  required String screenshotName,
}) async {
  final config = ScreenshotConfig.instance;

  // Create provider overrides
  final container = ProviderContainer(
    overrides: [
      // App config
      appConfigProvider.overrideWith((_) => AppConfig()),

      // Settings with locale and theme
      settingsProvider.overrideWith(
        () => MockSettingsNotifier(
          locale: locale,
          themeMode: themeMode,
          isPremium: true,
        ),
      ),

      // Add your app-specific provider overrides here
      // Example:
      // myFeatureProvider.overrideWith(() => MockMyFeatureProvider()),
    ],
  );

  // Mark onboarding as complete
  container.read(settingsProvider.notifier).updateSingleSetting(onBoard: true);

  try {
    // Build the app
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: supportedLocales,
          path: 'assets/languages',
          fallbackLocale: defaultLocale,
          startLocale: locale,
          child: const app.MainApp(),
        ),
      ),
    );

    // Wait for app to initialize
    await Future.delayed(Duration(milliseconds: config.navigationWaitMs));

    // Pump frames (avoid pumpAndSettle for screens with animations)
    await pumpFrames(tester);

    // Wait for HomeView to appear
    await pumpUntilFound(
      tester,
      find.byType(HomeView),
      timeout: config.widgetTimeout,
    );

    // Additional frames to stabilize
    await pumpFrames(tester, frameCount: 10);

    // Take screenshot
    await takeScreenshot(tester, screenshotName, lang);
  } finally {
    container.dispose();
  }
}

/// Example: Capture a screenshot with navigation
///
/// Use this pattern when you need to navigate to a specific screen.
// ignore: unused_element
Future<void> _captureScreenshotWithNavigation(
  WidgetTester tester, {
  required Locale locale,
  required String lang,
  required ThemeMode themeMode,
  required String screenshotName,
  required String route,
  required Type waitForWidget,
}) async {
  final config = ScreenshotConfig.instance;

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith((_) => AppConfig()),
      settingsProvider.overrideWith(
        () => MockSettingsNotifier(
          locale: locale,
          themeMode: themeMode,
          isPremium: true,
        ),
      ),
    ],
  );

  container.read(settingsProvider.notifier).updateSingleSetting(onBoard: true);

  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: supportedLocales,
          path: 'assets/languages',
          fallbackLocale: defaultLocale,
          startLocale: locale,
          child: const app.MainApp(),
        ),
      ),
    );

    // Wait for initial render
    await Future.delayed(Duration(milliseconds: config.navigationWaitMs));
    await pumpFrames(tester);

    // Wait for HomeView first (needed to get GoRouter context)
    await pumpUntilFound(tester, find.byType(HomeView), timeout: config.widgetTimeout);
    await pumpFrames(tester, frameCount: 5);

    // Navigate using GoRouter
    // Note: You need to find a widget that has access to GoRouter context
    // final homeViewFinder = find.byType(HomeView);
    // final context = tester.element(homeViewFinder.first);
    // context.go(route);

    // Wait for target screen
    await pumpUntilFound(tester, find.byType(waitForWidget), timeout: config.widgetTimeout);
    await pumpFrames(tester, frameCount: 10);

    // Take screenshot
    await takeScreenshot(tester, screenshotName, lang);
  } finally {
    container.dispose();
  }
}

/// Example: Capture a screenshot with tab selection
///
/// Use this pattern for screens with TabBar.
// ignore: unused_element
Future<void> _captureScreenshotWithTab(
  WidgetTester tester, {
  required Locale locale,
  required String lang,
  required ThemeMode themeMode,
  required String screenshotName,
  required int tabIndex,
  required Type screenWidget,
}) async {
  final config = ScreenshotConfig.instance;

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith((_) => AppConfig()),
      settingsProvider.overrideWith(
        () => MockSettingsNotifier(
          locale: locale,
          themeMode: themeMode,
          isPremium: true,
        ),
      ),
    ],
  );

  container.read(settingsProvider.notifier).updateSingleSetting(onBoard: true);

  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: supportedLocales,
          path: 'assets/languages',
          fallbackLocale: defaultLocale,
          startLocale: locale,
          child: const app.MainApp(),
        ),
      ),
    );

    await Future.delayed(Duration(milliseconds: config.navigationWaitMs));
    await pumpFrames(tester);

    // Wait for the screen with tabs
    await pumpUntilFound(tester, find.byType(screenWidget), timeout: config.widgetTimeout);
    await pumpFrames(tester, frameCount: 5);

    // Select the tab
    if (tabIndex > 0) {
      await selectTab(tester, tabIndex);
    }

    await pumpFrames(tester, frameCount: 10);

    // Take screenshot
    await takeScreenshot(tester, screenshotName, lang);
  } finally {
    container.dispose();
  }
}
