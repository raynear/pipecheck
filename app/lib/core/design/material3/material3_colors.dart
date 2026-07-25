import 'package:pipecheck/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Material3 색상 시스템
/// Google의 Material Design 3 가이드라인을 따르는 색상 체계
class Material3Colors implements DesignColors {
  // ================== Brand Colors ==================
  @override
  Color get primary => const Color(0xFF2196F3);

  @override
  Color get primaryLight => const Color(0xFF64B5F6);

  @override
  Color get primaryDark => const Color(0xFF1976D2);

  @override
  Color get secondary => const Color(0xFF4CAF50);

  @override
  Color get secondaryLight => const Color(0xFF81C784);

  @override
  Color get secondaryDark => const Color(0xFF388E3C);

  // ================== Semantic Colors ==================
  @override
  Color get success => const Color(0xFF4CAF50);

  @override
  Color get error => const Color(0xFFF44336);

  @override
  Color get warning => const Color(0xFFFF9800);

  @override
  Color get info => const Color(0xFF2196F3);

  // ================== Neutral Colors ==================
  @override
  Color get white => const Color(0xFFFFFFFF);

  @override
  Color get black => const Color(0xFF000000);

  @override
  Color get gray50 => const Color(0xFFFAFAFA);

  @override
  Color get gray100 => const Color(0xFFF5F5F5);

  @override
  Color get gray200 => const Color(0xFFEEEEEE);

  @override
  Color get gray300 => const Color(0xFFE0E0E0);

  @override
  Color get gray400 => const Color(0xFFBDBDBD);

  @override
  Color get gray500 => const Color(0xFF9E9E9E);

  @override
  Color get gray600 => const Color(0xFF757575);

  @override
  Color get gray700 => const Color(0xFF616161);

  @override
  Color get gray800 => const Color(0xFF424242);

  @override
  Color get gray900 => const Color(0xFF212121);

  // ================== Background Colors ==================
  @override
  Color get backgroundPrimary => white;

  @override
  Color get backgroundSecondary => gray50;

  @override
  Color get backgroundTertiary => gray100;

  // ================== Text Colors ==================
  @override
  Color get textPrimary => gray900;

  @override
  Color get textSecondary => gray700;

  @override
  Color get textTertiary => gray500;

  @override
  Color get textDisabled => gray400;

  @override
  Color get textOnPrimary => white;

  @override
  Color get textOnSecondary => white;

  // ================== Border Colors ==================
  @override
  Color get border => gray300;

  @override
  Color get borderLight => gray200;

  @override
  Color get borderDark => gray400;

  // ================== Special Colors ==================
  @override
  Color get divider => gray200;

  @override
  Color get shadow => const Color(0x1A000000); // 10% opacity

  @override
  Color get overlay => const Color(0x8A000000); // 54% opacity

  // ================== Additional Material3 Specific Colors ==================
  @override
  Color get successLight => const Color(0xFF81C784);
  @override
  Color get successDark => const Color(0xFF388E3C);

  @override
  Color get errorLight => const Color(0xFFE57373);
  @override
  Color get errorDark => const Color(0xFFD32F2F);

  @override
  Color get warningLight => const Color(0xFFFFB74D);
  @override
  Color get warningDark => const Color(0xFFF57C00);

  @override
  Color get infoLight => const Color(0xFF64B5F6);
  @override
  Color get infoDark => const Color(0xFF1976D2);

  @override
  Color get backgroundElevated => white;
  @override
  Color get backgroundOverlay => const Color(0x8A000000); // 54% opacity

  @override
  Color get textOnError => white;

  // Component specific colors
  @override
  Color get buttonPrimary => primary;
  @override
  Color get buttonSecondary => secondary;
  @override
  Color get buttonDisabled => gray300;

  @override
  Color get inputBackground => gray50;
  @override
  Color get inputBorder => gray300;
  @override
  Color get inputBorderFocused => primary;
  @override
  Color get inputBorderError => error;

  @override
  Color get cardBackground => white;
  @override
  Color get cardBorder => gray200;

  // Dark theme support
  @override
  Color get darkBackgroundPrimary => const Color(0xFF121212);
  @override
  Color get darkBackgroundSecondary => const Color(0xFF1E1E1E);
  @override
  Color get darkTextPrimary => const Color(0xFFE0E0E0);
  @override
  Color get darkTextSecondary => const Color(0xFFB0B0B0);
}
