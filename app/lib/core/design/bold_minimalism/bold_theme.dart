import 'package:pipecheck/core/design/bold_minimalism/bold_colors.dart';
import 'package:pipecheck/core/design/bold_minimalism/bold_spacing.dart';
import 'package:pipecheck/core/design/bold_minimalism/bold_typography.dart';
import 'package:pipecheck/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Bold Minimalism 디자인 시스템
/// 강렬하고 미니멀한 디자인 언어
class BoldMinimalismDesign implements DesignSystem {
  final BoldColors _colors = BoldColors();
  final BoldSpacing _spacing = BoldSpacing();
  final BoldTypography _typography = BoldTypography();

  @override
  String get name => 'Bold Minimalism';

  @override
  String get description => '강렬한 대비와 넓은 여백을 활용한 미니멀 디자인 시스템';

  @override
  DesignColors get colors => _colors;

  @override
  DesignSpacing get spacing => _spacing;

  @override
  DesignTypography get typography => _typography;

  @override
  ThemeData get lightTheme => ThemeData(
        useMaterial3: false, // Bold Minimalism은 Material3를 따르지 않음
        brightness: Brightness.light,

        // ================== Color Scheme ==================
        colorScheme: ColorScheme.light(
          primary: _colors.primary,
          primaryContainer: _colors.primaryLight,
          onPrimary: _colors.textOnPrimary,
          secondary: _colors.secondary,
          secondaryContainer: _colors.secondaryLight,
          onSecondary: _colors.textOnSecondary,
          error: _colors.error,
          onError: _colors.white,
          surface: _colors.backgroundPrimary,
          onSurface: _colors.textPrimary,
          onSurfaceVariant: _colors.textSecondary,
          outline: _colors.border,
          shadow: _colors.shadow,
        ),

        // ================== Background Colors ==================
        scaffoldBackgroundColor: _colors.backgroundPrimary,

        // ================== Typography ==================
        textTheme: TextTheme(
          displayLarge: _typography.displayLarge,
          displayMedium: _typography.displayMedium,
          displaySmall: _typography.displaySmall,
          headlineLarge: _typography.headlineLarge,
          headlineMedium: _typography.headlineMedium,
          headlineSmall: _typography.headlineSmall,
          titleLarge: _typography.titleLarge,
          titleMedium: _typography.titleMedium,
          titleSmall: _typography.titleSmall,
          bodyLarge: _typography.bodyLarge,
          bodyMedium: _typography.bodyMedium,
          bodySmall: _typography.bodySmall,
          labelLarge: _typography.labelLarge,
          labelMedium: _typography.labelMedium,
          labelSmall: _typography.labelSmall,
        ),

        // ================== AppBar Theme ==================
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false, // Left aligned for minimalism
          backgroundColor: _colors.backgroundPrimary,
          foregroundColor: _colors.textPrimary,
          titleTextStyle: _typography.headlineSmall.copyWith(
            color: _colors.textPrimary,
          ),
          iconTheme: IconThemeData(
            color: _colors.textPrimary,
            size: _spacing.iconLg,
          ),
        ),

        // ================== Elevated Button Theme ==================
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.primary,
            foregroundColor: _colors.white,
            disabledBackgroundColor: _colors.gray300,
            disabledForegroundColor: _colors.textDisabled,
            elevation: 0,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56), // Larger buttons
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, // Sharp corners
              side: BorderSide(color: _colors.primary, width: 2),
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Text Button Theme ==================
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _colors.primary,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Outlined Button Theme ==================
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _colors.primary,
            side: BorderSide(color: _colors.primary, width: 2),
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Input Decoration Theme ==================
        inputDecorationTheme: InputDecorationTheme(
          filled: false, // No fill for minimalism
          contentPadding: _spacing.inputPadding,
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.border, width: 2),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.borderLight, width: 2),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.primary, width: 3),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.error, width: 2),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.error, width: 3),
          ),
          labelStyle: _typography.bodyMedium,
          hintStyle: _typography.hint,
          errorStyle: _typography.error,
        ),

        // ================== Card Theme ==================
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: _colors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: _colors.border, width: 2),
          ),
        ),

        // ================== Dialog Theme ==================
        dialogTheme: DialogThemeData(
          backgroundColor: _colors.backgroundPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          titleTextStyle: _typography.headlineSmall,
          contentTextStyle: _typography.bodyLarge,
        ),

        // ================== Divider Theme ==================
        dividerTheme: DividerThemeData(
          color: _colors.divider,
          thickness: 2,
          space: _spacing.lg,
        ),

        // ================== Icon Theme ==================
        iconTheme: IconThemeData(
          color: _colors.textPrimary,
          size: _spacing.iconMd,
        ),
      );

  @override
  ThemeData get darkTheme => ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,

        // ================== Color Scheme ==================
        colorScheme: ColorScheme.dark(
          primary: _colors.white, // Inverted for dark theme
          primaryContainer: _colors.gray200,
          onPrimary: _colors.black,
          secondary: _colors.secondary,
          secondaryContainer: _colors.secondaryDark,
          onSecondary: _colors.white,
          error: _colors.error,
          onError: _colors.white,
          surface: _colors.black,
          onSurface: _colors.white,
          onSurfaceVariant: _colors.gray300,
          outline: _colors.white,
          shadow: _colors.shadow,
        ),

        // ================== Background Colors ==================
        scaffoldBackgroundColor: _colors.black,

        // ================== Typography ==================
        textTheme: TextTheme(
          displayLarge: _typography.displayLarge.copyWith(color: _colors.white),
          displayMedium: _typography.displayMedium.copyWith(color: _colors.white),
          displaySmall: _typography.displaySmall.copyWith(color: _colors.white),
          headlineLarge: _typography.headlineLarge.copyWith(color: _colors.white),
          headlineMedium: _typography.headlineMedium.copyWith(color: _colors.white),
          headlineSmall: _typography.headlineSmall.copyWith(color: _colors.white),
          titleLarge: _typography.titleLarge.copyWith(color: _colors.white),
          titleMedium: _typography.titleMedium.copyWith(color: _colors.white),
          titleSmall: _typography.titleSmall.copyWith(color: _colors.white),
          bodyLarge: _typography.bodyLarge.copyWith(color: _colors.white),
          bodyMedium: _typography.bodyMedium.copyWith(color: _colors.white),
          bodySmall: _typography.bodySmall.copyWith(color: _colors.gray300),
          labelLarge: _typography.labelLarge.copyWith(color: _colors.white),
          labelMedium: _typography.labelMedium.copyWith(color: _colors.white),
          labelSmall: _typography.labelSmall.copyWith(color: _colors.gray300),
        ),

        // ================== AppBar Theme ==================
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: _colors.black,
          foregroundColor: _colors.white,
          titleTextStyle: _typography.headlineSmall.copyWith(
            color: _colors.white,
          ),
          iconTheme: IconThemeData(
            color: _colors.white,
            size: _spacing.iconLg,
          ),
        ),

        // ================== Elevated Button Theme ==================
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.white,
            foregroundColor: _colors.black,
            disabledBackgroundColor: _colors.gray700,
            disabledForegroundColor: _colors.gray500,
            elevation: 0,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: _colors.white, width: 2),
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Text Button Theme ==================
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _colors.white,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Outlined Button Theme ==================
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _colors.white,
            side: BorderSide(color: _colors.white, width: 2),
            padding: _spacing.buttonPadding,
            minimumSize: const Size(120, 56),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Input Decoration Theme ==================
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          contentPadding: _spacing.inputPadding,
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.gray500, width: 2),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.gray500, width: 2),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.white, width: 3),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.error, width: 2),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _colors.error, width: 3),
          ),
          labelStyle: _typography.bodyMedium.copyWith(color: _colors.gray300),
          hintStyle: _typography.hint.copyWith(color: _colors.gray500),
          errorStyle: _typography.error,
        ),

        // ================== Card Theme ==================
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: _colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: _colors.white, width: 2),
          ),
        ),

        // ================== Dialog Theme ==================
        dialogTheme: DialogThemeData(
          backgroundColor: _colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: _colors.white, width: 2),
          ),
          titleTextStyle: _typography.headlineSmall.copyWith(color: _colors.white),
          contentTextStyle: _typography.bodyLarge.copyWith(color: _colors.white),
        ),

        // ================== Divider Theme ==================
        dividerTheme: DividerThemeData(
          color: _colors.gray600,
          thickness: 2,
          space: _spacing.lg,
        ),

        // ================== Bottom Navigation Bar Theme ==================
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _colors.black,
          selectedItemColor: _colors.white,
          unselectedItemColor: _colors.gray500,
          selectedLabelStyle: _typography.labelSmall,
          unselectedLabelStyle: _typography.labelSmall,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),

        // ================== Icon Theme ==================
        iconTheme: IconThemeData(
          color: _colors.white,
          size: _spacing.iconMd,
        ),
      );

  @override
  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  ColorScheme colorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  @override
  TextTheme textTheme(BuildContext context) {
    return Theme.of(context).textTheme;
  }
}
