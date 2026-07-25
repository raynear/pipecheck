/// Screenshot Utility Functions
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/screenshot_config.dart';

/// Take a screenshot with proper waiting and naming
///
/// [tester] - WidgetTester instance
/// [name] - Screenshot name (without extension)
/// [language] - Language code (ko, en)
/// [platform] - Platform override (auto-detected if null)
Future<void> takeScreenshot(
  WidgetTester tester,
  String name,
  String language, {
  String? platform,
}) async {
  final config = ScreenshotConfig.instance;

  // Pump frames to stabilize UI (avoid pumpAndSettle due to animations)
  for (int i = 0; i < 10; i++) {
    await tester.pump(Duration(milliseconds: config.pumpIntervalMs));
  }

  // Additional delay for any remaining animations
  await Future.delayed(const Duration(milliseconds: 500));

  // Pump again to ensure UI is stable
  await tester.pump();

  // Determine platform
  final platformName = platform ?? (Platform.isAndroid ? 'android' : 'ios');

  // Construct screenshot path: {outputDir}/{platform}/{language}/{name}
  final screenshotPath = '${config.outputDir}/$platformName/$language/$name';

  debugPrint('[Screenshot] Taking: $screenshotPath');

  try {
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(screenshotPath);
    debugPrint('[Screenshot] Saved: $screenshotPath.png');
  } catch (e) {
    debugPrint('[Screenshot] Failed: $e');
    if (!config.continueOnFailure) {
      rethrow;
    }
  }
}

/// Take a screenshot for a specific scene
Future<void> takeSceneScreenshot(
  WidgetTester tester,
  ScreenshotScene scene,
  String language, {
  String? platform,
}) async {
  await takeScreenshot(tester, scene.fullName, language, platform: platform);
}

/// Wait for a widget to appear with timeout
///
/// [tester] - WidgetTester instance
/// [finder] - Widget finder
/// [timeout] - Maximum wait time (uses config default if null)
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration? timeout,
}) async {
  final config = ScreenshotConfig.instance;
  final effectiveTimeout = timeout ?? config.widgetTimeout;
  final endTime = DateTime.now().add(effectiveTimeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(Duration(milliseconds: config.pumpIntervalMs));

    if (finder.evaluate().isNotEmpty) {
      // Pump a few more frames to stabilize
      for (int i = 0; i < 5; i++) {
        await tester.pump(Duration(milliseconds: config.pumpIntervalMs));
      }
      return;
    }
  }

  throw TimeoutException('Widget not found within timeout: $finder', effectiveTimeout);
}

/// Wait for a widget type to appear
Future<void> pumpUntilWidgetFound<T extends Widget>(
  WidgetTester tester, {
  Duration? timeout,
}) async {
  await pumpUntilFound(tester, find.byType(T), timeout: timeout);
}

/// Wait for app to be fully loaded and stable
Future<void> waitForAppReady(WidgetTester tester) async {
  final config = ScreenshotConfig.instance;

  // Initial pump frames (avoid pumpAndSettle due to animations)
  for (int i = 0; i < config.pumpFrameCount; i++) {
    await tester.pump(Duration(milliseconds: config.pumpIntervalMs));
  }

  // Wait for any async initialization
  await Future.delayed(Duration(milliseconds: config.navigationWaitMs));

  // Final pump frames
  for (int i = 0; i < 10; i++) {
    await tester.pump(Duration(milliseconds: config.pumpIntervalMs));
  }
}

/// Pump frames without pumpAndSettle (useful for screens with animations)
///
/// [tester] - WidgetTester instance
/// [frameCount] - Number of frames to pump
/// [intervalMs] - Interval between frames in milliseconds
Future<void> pumpFrames(
  WidgetTester tester, {
  int? frameCount,
  int? intervalMs,
}) async {
  final config = ScreenshotConfig.instance;
  final frames = frameCount ?? config.pumpFrameCount;
  final interval = intervalMs ?? config.pumpIntervalMs;

  for (int i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: interval));
  }
}

/// Navigate to a route and wait for it to be rendered
///
/// [tester] - WidgetTester instance
/// [context] - BuildContext for navigation
/// [route] - Route path
/// [goRouter] - GoRouter go function
/// [waitForWidget] - Optional widget type to wait for after navigation
Future<void> navigateAndWait(
  WidgetTester tester, {
  required void Function(String) navigate,
  required String route,
  Type? waitForWidget,
}) async {
  final config = ScreenshotConfig.instance;

  // Navigate
  navigate(route);

  // Wait for navigation
  await Future.delayed(Duration(milliseconds: config.navigationWaitMs));

  // Pump frames
  await pumpFrames(tester);

  // Wait for specific widget if provided
  if (waitForWidget != null) {
    await pumpUntilFound(
      tester,
      find.byType(waitForWidget),
      timeout: config.widgetTimeout,
    );
  }
}

/// Select a tab in a TabBar
///
/// [tester] - WidgetTester instance
/// [tabIndex] - Index of the tab to select (0-based)
Future<void> selectTab(WidgetTester tester, int tabIndex) async {
  final config = ScreenshotConfig.instance;

  final tabBarFinder = find.byType(TabBar);
  if (tabBarFinder.evaluate().isEmpty) {
    throw Exception('TabBar not found');
  }

  // Find tabs within the TabBar
  final tabs = find.descendant(
    of: tabBarFinder,
    matching: find.byType(Tab),
  );

  if (tabs.evaluate().length <= tabIndex) {
    throw Exception('Tab index $tabIndex out of range (${tabs.evaluate().length} tabs found)');
  }

  // Tap the tab
  await tester.tap(tabs.at(tabIndex));

  // Wait for tab animation
  for (int i = 0; i < 10; i++) {
    await tester.pump(Duration(milliseconds: config.pumpIntervalMs));
  }
}

/// Get the IntegrationTestWidgetsFlutterBinding instance
IntegrationTestWidgetsFlutterBinding ensureScreenshotBinding() {
  return IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// Get current platform name
String getCurrentPlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

/// Timeout exception for screenshot operations
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}

/// Screenshot result for tracking
class ScreenshotResult {
  final String name;
  final String language;
  final String platform;
  final bool success;
  final String? error;
  final DateTime timestamp;

  ScreenshotResult({
    required this.name,
    required this.language,
    required this.platform,
    required this.success,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    final status = success ? '✅' : '❌';
    return '$status $platform/$language/$name${error != null ? ' - $error' : ''}';
  }
}

/// Screenshot session for tracking multiple screenshots
class ScreenshotSession {
  final List<ScreenshotResult> results = [];
  final DateTime startTime = DateTime.now();

  void addResult(ScreenshotResult result) {
    results.add(result);
  }

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
  int get totalCount => results.length;

  Duration get duration => DateTime.now().difference(startTime);

  void printSummary() {
    debugPrint('\n=== Screenshot Session Summary ===');
    debugPrint('Duration: ${duration.inSeconds}s');
    debugPrint('Total: $totalCount | Success: $successCount | Failed: $failureCount');

    if (failureCount > 0) {
      debugPrint('\nFailed screenshots:');
      for (final result in results.where((r) => !r.success)) {
        debugPrint('  ${result.toString()}');
      }
    }

    debugPrint('================================\n');
  }
}
