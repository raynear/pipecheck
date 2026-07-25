/// Screenshot Test Base
library;

import 'package:pipecheck/config/app_feature_config.dart';
import 'package:pipecheck/main.dart' as app;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/screenshot_config.dart';
import 'utils/screenshot_utils.dart';

export 'config/screenshot_config.dart';
export 'providers/mock_providers_base.dart';
export 'utils/screenshot_utils.dart';

/// Base class for screenshot tests
///
/// Provides common functionality for setting up and capturing screenshots.
/// Extend this class and implement [buildProviderOverrides] and [getScenes]
/// for your app-specific screenshot tests.
///
/// Example:
/// ```dart
/// class MyScreenshotTest extends ScreenshotTestBase {
///   @override
///   List<Override> buildProviderOverrides(ScreenshotTestState state) {
///     return [
///       myProvider.overrideWith(() => MockMyProvider()),
///     ];
///   }
///
///   @override
///   List<ScreenshotScene> getScenes() {
///     return [
///       ScreenshotScene(id: '01', name: 'home'),
///       ScreenshotScene(id: '02', name: 'settings'),
///     ];
///   }
/// }
/// ```
abstract class ScreenshotTestBase {
  late IntegrationTestWidgetsFlutterBinding binding;
  final ScreenshotSession session = ScreenshotSession();

  /// Initialize the screenshot test binding
  void initBinding() {
    binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Configure app feature flags for screenshot testing
  ///
  /// Override this method to customize feature flags for your app.
  void configureFeatureFlags() {
    // Disable features that might interfere with screenshots
    AppFeatureConfig.isAuthenticationEnabled = false;
    AppFeatureConfig.isBiometricAuthEnabled = false;
    AppFeatureConfig.isOnboardingEnabled = false;
    AppFeatureConfig.isAdsEnabled = false;
  }

  /// Build provider overrides for the test
  ///
  /// Implement this method to provide app-specific provider overrides.
  /// The [state] parameter contains the current locale, theme, and container.
  List<dynamic> buildProviderOverrides(Locale locale, ThemeMode themeMode);

  /// Get the list of screenshot scenes to capture
  ///
  /// Implement this method to define the screenshots for your app.
  List<ScreenshotScene> getScenes();

  /// Get supported locales for screenshots
  ///
  /// Override this method to customize the supported locales.
  List<Locale> getSupportedLocales() {
    return ScreenshotConfig.instance.supportedLocales.map((l) => l.locale).toList();
  }

  /// Get the language path for easy_localization
  String getLanguagePath() => 'assets/languages';

  /// Get the default locale for easy_localization
  Locale getDefaultLocale() => ScreenshotConfig.instance.defaultLocale;

  /// Capture all screenshots for a given locale
  ///
  /// [tester] - WidgetTester instance
  /// [locale] - Target locale
  /// [themeMode] - Theme mode (default from config)
  Future<void> captureScreenshotsForLocale(
    WidgetTester tester, {
    required Locale locale,
    ThemeMode? themeMode,
  }) async {
    final config = ScreenshotConfig.instance;
    final effectiveTheme = themeMode ?? config.defaultTheme;
    final languageCode = locale.languageCode;

    debugPrint('\n=== Capturing screenshots for $languageCode (${effectiveTheme.name}) ===\n');

    for (final scene in getScenes()) {
      await _captureScene(
        tester,
        scene: scene,
        locale: locale,
        themeMode: scene.themeOverride ?? effectiveTheme,
      );
    }

    debugPrint('\n=== All $languageCode screenshots completed! ===\n');
  }

  /// Capture a single screenshot scene
  Future<void> _captureScene(
    WidgetTester tester, {
    required ScreenshotScene scene,
    required Locale locale,
    required ThemeMode themeMode,
  }) async {
    final config = ScreenshotConfig.instance;
    final languageCode = locale.languageCode;

    debugPrint('=== Capturing: ${scene.description.isNotEmpty ? scene.description : scene.name} ===');

    // Build overrides and create provider container
    final container = ProviderContainer(
      overrides: buildProviderOverrides(locale, themeMode).cast(),
    );

    try {
      // Build the app
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: getSupportedLocales(),
            path: getLanguagePath(),
            fallbackLocale: getDefaultLocale(),
            startLocale: locale,
            child: const app.MainApp(),
          ),
        ),
      );

      // Wait for initial render
      await Future.delayed(Duration(milliseconds: config.navigationWaitMs));
      await pumpFrames(tester);

      // Wait for specific widget if defined
      if (scene.waitForWidget != null) {
        await pumpUntilFound(
          tester,
          find.byType(scene.waitForWidget!),
          timeout: config.widgetTimeout,
        );
      }

      // Run setup function if provided
      if (scene.setup != null) {
        await scene.setup!();
      }

      // Navigate to route if specified
      if (scene.route != null) {
        // Navigation logic would be implemented here
        // This requires access to GoRouter context
      }

      // Select tab if specified
      if (scene.tabIndex != null) {
        await selectTab(tester, scene.tabIndex!);
      }

      // Additional frames after setup
      await pumpFrames(tester, frameCount: 10);

      // Take screenshot
      final screenshotName = scene.fullNameWithTheme(themeMode);
      await takeScreenshot(tester, screenshotName, languageCode);

      // Track result
      session.addResult(ScreenshotResult(
        name: screenshotName,
        language: languageCode,
        platform: getCurrentPlatform(),
        success: true,
      ));
    } catch (e) {
      debugPrint('[Screenshot] Error capturing ${scene.name}: $e');

      session.addResult(ScreenshotResult(
        name: scene.fullName,
        language: languageCode,
        platform: getCurrentPlatform(),
        success: false,
        error: e.toString(),
      ));

      if (!config.continueOnFailure) {
        rethrow;
      }
    } finally {
      container.dispose();
    }
  }

  /// Run all screenshot tests
  ///
  /// Call this method in your test file to run all screenshot scenarios.
  void runAllScreenshotTests() {
    initBinding();

    for (final localeConfig in ScreenshotConfig.instance.supportedLocales) {
      testWidgets('${localeConfig.name} App Store Screenshots', (tester) async {
        configureFeatureFlags();
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();

        await captureScreenshotsForLocale(
          tester,
          locale: localeConfig.locale,
        );

        session.printSummary();
      });
    }
  }
}

/// Simple screenshot test runner
///
/// Use this for quick screenshot tests without extending [ScreenshotTestBase].
///
/// Example:
/// ```dart
/// void main() {
///   runScreenshotTests(
///     scenes: [
///       ScreenshotScene(id: '01', name: 'home'),
///       ScreenshotScene(id: '02', name: 'settings'),
///     ],
///     buildOverrides: (locale, theme) => [
///       myProvider.overrideWith(() => MockMyProvider()),
///     ],
///   );
/// }
/// ```
void runScreenshotTests({
  required List<ScreenshotScene> scenes,
  required List<dynamic> Function(Locale locale, ThemeMode themeMode) buildOverrides,
  void Function()? configureFeatures,
  List<Locale>? locales,
}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final config = ScreenshotConfig.instance;
  final effectiveLocales = locales ?? config.supportedLocales.map((l) => l.locale).toList();

  for (final locale in effectiveLocales) {
    final langCode = locale.languageCode;

    testWidgets('$langCode App Store Screenshots', (tester) async {
      // Configure features
      if (configureFeatures != null) {
        configureFeatures();
      } else {
        AppFeatureConfig.isAuthenticationEnabled = false;
        AppFeatureConfig.isOnboardingEnabled = false;
        AppFeatureConfig.isAdsEnabled = false;
      }

      SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();

      for (final scene in scenes) {
        debugPrint('=== Capturing: ${scene.name} ===');

        final themeMode = scene.themeOverride ?? config.defaultTheme;
        final container = ProviderContainer(
          overrides: buildOverrides(locale, themeMode).cast(),
        );

        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: EasyLocalization(
                supportedLocales: effectiveLocales,
                path: 'assets/languages',
                fallbackLocale: config.defaultLocale,
                startLocale: locale,
                child: const app.MainApp(),
              ),
            ),
          );

          await Future.delayed(Duration(milliseconds: config.navigationWaitMs));
          await pumpFrames(tester);

          if (scene.waitForWidget != null) {
            await pumpUntilFound(
              tester,
              find.byType(scene.waitForWidget!),
              timeout: config.widgetTimeout,
            );
          }

          if (scene.tabIndex != null) {
            await selectTab(tester, scene.tabIndex!);
          }

          await pumpFrames(tester, frameCount: 10);

          final screenshotName = scene.fullNameWithTheme(themeMode);
          await takeScreenshot(tester, screenshotName, langCode);
        } finally {
          container.dispose();
        }
      }

      debugPrint('=== All $langCode screenshots completed! ===');
    });
  }
}
