/// Screenshot Configuration
library;

import 'package:flutter/material.dart';

/// Screenshot configuration settings
class ScreenshotConfig {
  /// Singleton instance
  static final ScreenshotConfig instance = ScreenshotConfig._();
  ScreenshotConfig._();

  /// 하니스 dart-define (P1-17b) — ./run screenshot(tools/cli)이 주입.
  /// SCREENSHOT_OUTPUT: 출력 베이스 디렉토리 (절대경로).
  /// SCREENSHOT_LANGUAGE: 단일 언어 실행 필터 ('ko'|'en' 등).
  /// SCREENSHOT_MODE: 하니스 실행 여부.
  static const definedOutput = String.fromEnvironment('SCREENSHOT_OUTPUT');
  static const definedLanguage =
      String.fromEnvironment('SCREENSHOT_LANGUAGE');
  static const isScreenshotMode =
      bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);

  /// Output directory for screenshots.
  ///
  /// 경로 SSOT (P1-17b): 최종 산출물은
  /// `<root>/screenshots/{platform}/{language}/{name}.png` —
  /// iOS는 deliver `screenshots_path`(`<root>/screenshots/ios`)가
  /// 그대로 읽는 레이아웃이다. flutter drive의 cwd가 app/이므로
  /// 독립 실행 기본값은 `../screenshots`.
  /// (구 기본값 'app/store_data/screenshots'는 cwd=app 기준
  ///  app/app/store_data 이중 경로를 만드는 잠복 버그였음)
  String outputDir =
      definedOutput.isNotEmpty ? definedOutput : '../screenshots';

  /// Supported languages for screenshots
  List<ScreenshotLocale> supportedLocales = [
    ScreenshotLocale(locale: const Locale('ko', 'KR'), code: 'ko', name: 'Korean'),
    ScreenshotLocale(locale: const Locale('en', 'US'), code: 'en', name: 'English'),
  ];

  /// Supported themes for screenshots
  List<ScreenshotTheme> supportedThemes = [
    ScreenshotTheme(mode: ThemeMode.dark, name: 'dark'),
    ScreenshotTheme(mode: ThemeMode.light, name: 'light'),
  ];

  /// Default theme for screenshots
  ThemeMode defaultTheme = ThemeMode.dark;

  /// Default locale for screenshots
  Locale defaultLocale = const Locale('ko', 'KR');

  /// Wait time after navigation (milliseconds)
  int navigationWaitMs = 1000;

  /// Number of pump frames after navigation
  int pumpFrameCount = 30;

  /// Frame interval for pumping (milliseconds)
  int pumpIntervalMs = 100;

  /// Timeout for waiting widgets to appear
  Duration widgetTimeout = const Duration(seconds: 10);

  /// Whether to continue on screenshot failure
  bool continueOnFailure = true;

  /// Screenshot quality (0.0 - 1.0, only for JPEG)
  double screenshotQuality = 1.0;

  /// Configure the screenshot settings
  void configure({
    String? outputDir,
    List<ScreenshotLocale>? supportedLocales,
    List<ScreenshotTheme>? supportedThemes,
    ThemeMode? defaultTheme,
    Locale? defaultLocale,
    int? navigationWaitMs,
    int? pumpFrameCount,
    int? pumpIntervalMs,
    Duration? widgetTimeout,
    bool? continueOnFailure,
    double? screenshotQuality,
  }) {
    if (outputDir != null) this.outputDir = outputDir;
    if (supportedLocales != null) this.supportedLocales = supportedLocales;
    if (supportedThemes != null) this.supportedThemes = supportedThemes;
    if (defaultTheme != null) this.defaultTheme = defaultTheme;
    if (defaultLocale != null) this.defaultLocale = defaultLocale;
    if (navigationWaitMs != null) this.navigationWaitMs = navigationWaitMs;
    if (pumpFrameCount != null) this.pumpFrameCount = pumpFrameCount;
    if (pumpIntervalMs != null) this.pumpIntervalMs = pumpIntervalMs;
    if (widgetTimeout != null) this.widgetTimeout = widgetTimeout;
    if (continueOnFailure != null) this.continueOnFailure = continueOnFailure;
    if (screenshotQuality != null) this.screenshotQuality = screenshotQuality;
  }

  /// Reset to default configuration
  void reset() {
    outputDir = definedOutput.isNotEmpty ? definedOutput : '../screenshots';
    supportedLocales = [
      ScreenshotLocale(locale: const Locale('ko', 'KR'), code: 'ko', name: 'Korean'),
      ScreenshotLocale(locale: const Locale('en', 'US'), code: 'en', name: 'English'),
    ];
    supportedThemes = [
      ScreenshotTheme(mode: ThemeMode.dark, name: 'dark'),
      ScreenshotTheme(mode: ThemeMode.light, name: 'light'),
    ];
    defaultTheme = ThemeMode.dark;
    defaultLocale = const Locale('ko', 'KR');
    navigationWaitMs = 1000;
    pumpFrameCount = 30;
    pumpIntervalMs = 100;
    widgetTimeout = const Duration(seconds: 10);
    continueOnFailure = true;
    screenshotQuality = 1.0;
  }
}

/// Locale configuration for screenshots
class ScreenshotLocale {
  final Locale locale;
  final String code;
  final String name;

  const ScreenshotLocale({
    required this.locale,
    required this.code,
    required this.name,
  });
}

/// Theme configuration for screenshots
class ScreenshotTheme {
  final ThemeMode mode;
  final String name;

  const ScreenshotTheme({
    required this.mode,
    required this.name,
  });
}

/// Screenshot scene definition
/// Represents a single screenshot to capture
class ScreenshotScene {
  /// Unique identifier for ordering (e.g., '01', '02')
  final String id;

  /// Name of the screenshot (e.g., 'home_idle', 'settings')
  final String name;

  /// Description for logging
  final String description;

  /// Route to navigate to (if null, uses current screen)
  final String? route;

  /// Theme override for this scene (uses default if null)
  final ThemeMode? themeOverride;

  /// Additional setup function to run before capture
  final Future<void> Function()? setup;

  /// Widget finder to wait for before capturing
  final Type? waitForWidget;

  /// Tab index to select (for tabbed screens)
  final int? tabIndex;

  const ScreenshotScene({
    required this.id,
    required this.name,
    this.description = '',
    this.route,
    this.themeOverride,
    this.setup,
    this.waitForWidget,
    this.tabIndex,
  });

  /// Generate full screenshot name with prefix
  String get fullName => '${id}_$name';

  /// Generate screenshot name with theme suffix
  String fullNameWithTheme(ThemeMode theme) {
    if (theme == ThemeMode.light) {
      return '${fullName}_light';
    }
    return fullName;
  }
}

/// Screenshot scenario - a collection of scenes for a specific locale/theme
class ScreenshotScenario {
  final String name;
  final Locale locale;
  final ThemeMode theme;
  final List<ScreenshotScene> scenes;

  const ScreenshotScenario({
    required this.name,
    required this.locale,
    required this.theme,
    required this.scenes,
  });
}
