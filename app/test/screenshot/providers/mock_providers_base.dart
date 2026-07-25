/// Mock Providers Base Classes
library;

import 'package:boilerplate/core/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Base Mock Settings Notifier
// ============================================================================

/// Base mock SettingsNotifier for screenshot testing
///
/// Provides a pre-configured Settings state for screenshots.
/// Extend this class to customize settings for your app.
///
/// Example:
/// ```dart
/// class MyMockSettingsNotifier extends MockSettingsNotifier {
///   MyMockSettingsNotifier({
///     required super.locale,
///     super.themeMode,
///     super.isPremium,
///   });
///
///   @override
///   Settings build() => super.build().copyWith(
///     // Add your app-specific settings here
///     customSetting: true,
///   );
/// }
/// ```
class MockSettingsNotifier extends SettingsNotifier {
  final Locale _locale;
  final ThemeMode _themeMode;
  final bool _isPremium;
  final String _themeColor;

  MockSettingsNotifier({
    required Locale locale,
    ThemeMode themeMode = ThemeMode.dark,
    bool isPremium = true,
    String themeColor = 'teal',
  })  : _locale = locale,
        _themeMode = themeMode,
        _isPremium = isPremium,
        _themeColor = themeColor;

  @override
  Settings build() => Settings(
        onBoard: true, // Skip onboarding for screenshots
        displayMode: _themeMode,
        themeColor: _themeColor,
        bodyFont: 'Noto Sans',
        fontSize: 14,
        bold: false,
        language: _locale,
        userAuthOption: UserAuthOption.none,
        useICloud: false,
        useNotification: false,
        useReminder: false,
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        subscriptionExpiryDate: _isPremium ? DateTime.now().add(const Duration(days: 365)) : null,
        appLaunchCount: 100,
      );
}

// ============================================================================
// Mock Data Provider Base
// ============================================================================

/// Base class for providing mock data in screenshots
///
/// Extend this class to provide app-specific mock data.
///
/// Example:
/// ```dart
/// class MyMockDataProvider extends MockDataProviderBase {
///   @override
///   List<MyModel> getMockItems() => [
///     MyModel(id: '1', name: 'Item 1'),
///     MyModel(id: '2', name: 'Item 2'),
///   ];
/// }
/// ```
abstract class MockDataProviderBase {
  final Locale locale;

  MockDataProviderBase({this.locale = const Locale('ko', 'KR')});

  /// Check if the current locale is Korean
  bool get isKorean => locale.languageCode == 'ko';

  /// Check if the current locale is English
  bool get isEnglish => locale.languageCode == 'en';

  /// Get localized text based on current locale
  String localized(String korean, String english) {
    return isKorean ? korean : english;
  }
}

// ============================================================================
// Provider Override Helpers
// ============================================================================

/// Helper class for creating provider overrides
///
/// Usage:
/// ```dart
/// final helper = ScreenshotProviderOverrides();
/// helper.addSettingsOverride(locale: locale, themeMode: ThemeMode.dark);
/// final container = helper.createContainer();
/// ```
class ScreenshotProviderOverrides {
  final List<dynamic> _overrides = [];

  /// Add an override to the list
  void add(dynamic override) {
    _overrides.add(override);
  }

  /// Add multiple overrides
  void addAll(List<dynamic> overrides) {
    _overrides.addAll(overrides);
  }

  /// Add settings override with locale and theme
  void addSettingsOverride({
    required Locale locale,
    ThemeMode themeMode = ThemeMode.dark,
    bool isPremium = true,
  }) {
    _overrides.add(
      settingsProvider.overrideWith(
        () => MockSettingsNotifier(
          locale: locale,
          themeMode: themeMode,
          isPremium: isPremium,
        ),
      ),
    );
  }

  /// Get all overrides
  List<dynamic> get overrides => List.unmodifiable(_overrides);

  /// Create a ProviderContainer with the overrides
  ProviderContainer createContainer() {
    return ProviderContainer(overrides: _overrides.cast());
  }
}

// ============================================================================
// Screenshot Test State
// ============================================================================

/// Tracks the state of a screenshot test
class ScreenshotTestState {
  final Locale locale;
  final ThemeMode themeMode;
  final ProviderContainer container;
  final Map<String, dynamic> customState;

  ScreenshotTestState({
    required this.locale,
    required this.themeMode,
    required this.container,
    Map<String, dynamic>? customState,
  }) : customState = customState ?? {};

  /// Get language code for file naming
  String get languageCode => locale.languageCode;

  /// Check if using dark theme
  bool get isDarkTheme => themeMode == ThemeMode.dark;

  /// Check if using light theme
  bool get isLightTheme => themeMode == ThemeMode.light;

  /// Dispose the container
  void dispose() {
    container.dispose();
  }
}

// ============================================================================
// Mock Category Base
// ============================================================================

/// Base class for mock categories
///
/// Provides a structure for app-specific categories used in screenshots.
class MockCategoryBase {
  final String id;
  final String nameKo;
  final String nameEn;
  final String color;
  final String icon;
  final int sortOrder;

  const MockCategoryBase({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.color,
    required this.icon,
    this.sortOrder = 0,
  });

  /// Get localized name based on locale
  String getName(Locale locale) {
    return locale.languageCode == 'ko' ? nameKo : nameEn;
  }
}

/// Default categories for screenshots
class DefaultScreenshotCategories {
  static const work = MockCategoryBase(
    id: 'cat-work',
    nameKo: '업무',
    nameEn: 'Work',
    color: '#4CAF50',
    icon: 'work',
    sortOrder: 0,
  );

  static const study = MockCategoryBase(
    id: 'cat-study',
    nameKo: '공부',
    nameEn: 'Study',
    color: '#2196F3',
    icon: 'school',
    sortOrder: 1,
  );

  static const exercise = MockCategoryBase(
    id: 'cat-exercise',
    nameKo: '운동',
    nameEn: 'Exercise',
    color: '#FF9800',
    icon: 'fitness_center',
    sortOrder: 2,
  );

  static const reading = MockCategoryBase(
    id: 'cat-reading',
    nameKo: '독서',
    nameEn: 'Reading',
    color: '#9C27B0',
    icon: 'menu_book',
    sortOrder: 3,
  );

  static const personal = MockCategoryBase(
    id: 'cat-personal',
    nameKo: '개인',
    nameEn: 'Personal',
    color: '#E91E63',
    icon: 'person',
    sortOrder: 4,
  );

  /// Get all default categories
  static List<MockCategoryBase> get all => [
        work,
        study,
        exercise,
        reading,
        personal,
      ];
}
