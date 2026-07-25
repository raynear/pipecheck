import 'package:boilerplate/core/design/design_system.dart';
import 'package:boilerplate/core/design/material3/material3_colors.dart';
import 'package:boilerplate/core/design/material3/material3_spacing.dart';
import 'package:boilerplate/core/design/material3/material3_typography.dart';
import 'package:flutter/material.dart';

/// Material3 디자인 시스템
/// Google의 Material Design 3 가이드라인을 따르는 디자인 시스템
class Material3Design implements DesignSystem {
  final Material3Colors _colors = Material3Colors();
  final Material3Spacing _spacing = Material3Spacing();
  final Material3Typography _typography = Material3Typography();

  @override
  String get name => 'Material Design 3';

  @override
  String get description => 'Google의 Material Design 3 가이드라인을 따르는 공식 디자인 시스템';

  @override
  DesignColors get colors => _colors;

  @override
  DesignSpacing get spacing => _spacing;

  @override
  DesignTypography get typography => _typography;

  @override
  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        // ================== Color Scheme ==================
        colorScheme: ColorScheme.light(
          primary: _colors.primary,
          primaryContainer: _colors.primaryLight,
          onPrimary: _colors.white,
          secondary: _colors.secondary,
          secondaryContainer: _colors.secondaryLight,
          onSecondary: _colors.white,
          error: _colors.error,
          errorContainer: _colors.errorLight,
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
          centerTitle: true,
          backgroundColor: _colors.backgroundPrimary,
          foregroundColor: _colors.textPrimary,
          titleTextStyle: _typography.titleLarge.copyWith(
            color: _colors.textPrimary,
          ),
          iconTheme: IconThemeData(
            color: _colors.textPrimary,
            size: _spacing.iconMd,
          ),
        ),

        // ================== Elevated Button Theme ==================
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.primary,
            foregroundColor: _colors.white,
            disabledBackgroundColor: _colors.buttonDisabled,
            disabledForegroundColor: _colors.textDisabled,
            elevation: 0,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Text Button Theme ==================
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _colors.primary,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Outlined Button Theme ==================
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _colors.primary,
            side: BorderSide(color: _colors.primary),
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Input Decoration Theme ==================
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _colors.inputBackground,
          contentPadding: _spacing.inputPadding,
          border: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.inputBorderFocused, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.inputBorderError),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.inputBorderError, width: 2),
          ),
          labelStyle: _typography.bodyMedium,
          hintStyle: _typography.hint,
          errorStyle: _typography.error,
        ),

        // ================== Card Theme ==================
        cardTheme: CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
          color: _colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusMd,
            side: BorderSide(color: _colors.cardBorder, width: 1),
          ),
        ),

        // ================== Dialog Theme ==================
        dialogTheme: DialogThemeData(
          backgroundColor: _colors.backgroundElevated,
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusLg,
          ),
          titleTextStyle: _typography.titleLarge,
          contentTextStyle: _typography.bodyMedium,
        ),

        // ================== Divider Theme ==================
        dividerTheme: DividerThemeData(
          color: _colors.divider,
          thickness: 1,
          space: 0,
        ),

        // ================== Bottom Navigation Bar Theme ==================
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _colors.backgroundPrimary,
          selectedItemColor: _colors.primary,
          unselectedItemColor: _colors.textTertiary,
          selectedLabelStyle: _typography.labelSmall,
          unselectedLabelStyle: _typography.labelSmall,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // ================== Floating Action Button Theme ==================
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _colors.primary,
          foregroundColor: _colors.white,
          elevation: 4,
          highlightElevation: 8,
        ),

        // ================== Chip Theme ==================
        chipTheme: ChipThemeData(
          backgroundColor: _colors.gray100,
          selectedColor: _colors.primaryLight,
          disabledColor: _colors.gray200,
          labelStyle: _typography.labelMedium,
          padding: EdgeInsets.symmetric(horizontal: _spacing.md, vertical: _spacing.xs),
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusFull,
          ),
        ),

        // ================== Icon Theme ==================
        iconTheme: IconThemeData(
          color: _colors.textPrimary,
          size: _spacing.iconMd,
        ),
      );

  @override
  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // ================== Color Scheme ==================
        colorScheme: ColorScheme.dark(
          primary: _colors.primary,
          primaryContainer: _colors.primaryDark,
          onPrimary: _colors.white,
          secondary: _colors.secondary,
          secondaryContainer: _colors.secondaryDark,
          onSecondary: _colors.white,
          error: _colors.error,
          errorContainer: _colors.errorDark,
          onError: _colors.white,
          surface: _colors.darkBackgroundPrimary,
          onSurface: _colors.darkTextPrimary,
          onSurfaceVariant: _colors.darkTextSecondary,
          outline: _colors.gray600,
          shadow: _colors.shadow,
        ),

        // ================== Background Colors ==================
        scaffoldBackgroundColor: _colors.darkBackgroundPrimary,

        // ================== Typography ==================
        textTheme: TextTheme(
          displayLarge: _typography.displayLarge.copyWith(color: _colors.darkTextPrimary),
          displayMedium: _typography.displayMedium.copyWith(color: _colors.darkTextPrimary),
          displaySmall: _typography.displaySmall.copyWith(color: _colors.darkTextPrimary),
          headlineLarge: _typography.headlineLarge.copyWith(color: _colors.darkTextPrimary),
          headlineMedium: _typography.headlineMedium.copyWith(color: _colors.darkTextPrimary),
          headlineSmall: _typography.headlineSmall.copyWith(color: _colors.darkTextPrimary),
          titleLarge: _typography.titleLarge.copyWith(color: _colors.darkTextPrimary),
          titleMedium: _typography.titleMedium.copyWith(color: _colors.darkTextPrimary),
          titleSmall: _typography.titleSmall.copyWith(color: _colors.darkTextPrimary),
          bodyLarge: _typography.bodyLarge.copyWith(color: _colors.darkTextPrimary),
          bodyMedium: _typography.bodyMedium.copyWith(color: _colors.darkTextPrimary),
          bodySmall: _typography.bodySmall.copyWith(color: _colors.darkTextSecondary),
          labelLarge: _typography.labelLarge.copyWith(color: _colors.darkTextPrimary),
          labelMedium: _typography.labelMedium.copyWith(color: _colors.darkTextPrimary),
          labelSmall: _typography.labelSmall.copyWith(color: _colors.darkTextSecondary),
        ),

        // ================== AppBar Theme ==================
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: _colors.darkBackgroundPrimary,
          foregroundColor: _colors.darkTextPrimary,
          titleTextStyle: _typography.titleLarge.copyWith(
            color: _colors.darkTextPrimary,
          ),
          iconTheme: IconThemeData(
            color: _colors.darkTextPrimary,
            size: _spacing.iconMd,
          ),
        ),

        // ================== Elevated Button Theme ==================
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.primary,
            foregroundColor: _colors.white,
            disabledBackgroundColor: _colors.gray700,
            disabledForegroundColor: _colors.gray500,
            elevation: 0,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Text Button Theme ==================
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _colors.primaryLight,
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Outlined Button Theme ==================
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _colors.primaryLight,
            side: BorderSide(color: _colors.primaryLight),
            padding: _spacing.buttonPadding,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: _spacing.borderRadiusMd,
            ),
            textStyle: _typography.button,
          ),
        ),

        // ================== Input Decoration Theme ==================
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _colors.darkBackgroundSecondary,
          contentPadding: _spacing.inputPadding,
          border: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.gray600),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.gray600),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: _spacing.borderRadiusMd,
            borderSide: BorderSide(color: _colors.error, width: 2),
          ),
          labelStyle: _typography.bodyMedium.copyWith(color: _colors.darkTextSecondary),
          hintStyle: _typography.hint.copyWith(color: _colors.gray500),
          errorStyle: _typography.error,
        ),

        // ================== Card Theme ==================
        cardTheme: CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
          color: _colors.darkBackgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusMd,
            side: BorderSide(color: _colors.gray700, width: 1),
          ),
        ),

        // ================== Dialog Theme ==================
        dialogTheme: DialogThemeData(
          backgroundColor: _colors.darkBackgroundSecondary,
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusLg,
          ),
          titleTextStyle: _typography.titleLarge.copyWith(color: _colors.darkTextPrimary),
          contentTextStyle: _typography.bodyMedium.copyWith(color: _colors.darkTextPrimary),
        ),

        // ================== Divider Theme ==================
        dividerTheme: DividerThemeData(
          color: _colors.gray700,
          thickness: 1,
          space: 0,
        ),

        // ================== Bottom Navigation Bar Theme ==================
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _colors.darkBackgroundPrimary,
          selectedItemColor: _colors.primary,
          unselectedItemColor: _colors.gray500,
          selectedLabelStyle: _typography.labelSmall,
          unselectedLabelStyle: _typography.labelSmall,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // ================== Floating Action Button Theme ==================
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _colors.primary,
          foregroundColor: _colors.white,
          elevation: 4,
          highlightElevation: 8,
        ),

        // ================== Chip Theme ==================
        chipTheme: ChipThemeData(
          backgroundColor: _colors.gray800,
          selectedColor: _colors.primaryDark,
          disabledColor: _colors.gray700,
          labelStyle: _typography.labelMedium.copyWith(color: _colors.darkTextPrimary),
          padding: EdgeInsets.symmetric(horizontal: _spacing.md, vertical: _spacing.xs),
          shape: RoundedRectangleBorder(
            borderRadius: _spacing.borderRadiusFull,
          ),
        ),

        // ================== Icon Theme ==================
        iconTheme: IconThemeData(
          color: _colors.darkTextPrimary,
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
