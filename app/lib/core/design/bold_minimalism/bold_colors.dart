import 'package:boilerplate/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Bold Minimalism 색상 시스템
/// 흑백 위주의 강렬한 대비와 최소한의 액센트 색상
class BoldColors implements DesignColors {
  // ================== Brand Colors ==================
  @override
  Color get primary => const Color(0xFF000000); // Pure Black

  @override
  Color get primaryLight => const Color(0xFF333333);

  @override
  Color get primaryDark => const Color(0xFF000000);

  @override
  Color get secondary => const Color(0xFFFF0000); // Bold Red Accent

  @override
  Color get secondaryLight => const Color(0xFFFF5252);

  @override
  Color get secondaryDark => const Color(0xFFCC0000);

  // ================== Semantic Colors ==================
  @override
  Color get success => const Color(0xFF000000);

  @override
  Color get successLight => const Color(0xFF333333);

  @override
  Color get successDark => const Color(0xFF000000);

  @override
  Color get error => const Color(0xFFFF0000);

  @override
  Color get errorLight => const Color(0xFFFF5252);

  @override
  Color get errorDark => const Color(0xFFCC0000);

  @override
  Color get warning => const Color(0xFF000000);

  @override
  Color get warningLight => const Color(0xFF333333);

  @override
  Color get warningDark => const Color(0xFF000000);

  @override
  Color get info => const Color(0xFF000000);

  @override
  Color get infoLight => const Color(0xFF333333);

  @override
  Color get infoDark => const Color(0xFF000000);

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
  Color get backgroundSecondary => white;

  @override
  Color get backgroundTertiary => gray100;

  @override
  Color get backgroundElevated => white;

  @override
  Color get backgroundOverlay => const Color(0xCC000000);

  // ================== Text Colors ==================
  @override
  Color get textPrimary => black;

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

  @override
  Color get textOnError => white;

  // ================== Border Colors ==================
  @override
  Color get border => black;

  @override
  Color get borderLight => gray300;

  @override
  Color get borderDark => black;

  // ================== Special Colors ==================
  @override
  Color get divider => black;

  @override
  Color get shadow => const Color(0x1A000000);

  @override
  Color get overlay => const Color(0xCC000000); // Darker overlay

  // ================== Component Specific ==================
  @override
  Color get buttonPrimary => black;

  @override
  Color get buttonSecondary => secondary;

  @override
  Color get buttonDisabled => gray300;

  @override
  Color get inputBackground => white;

  @override
  Color get inputBorder => black;

  @override
  Color get inputBorderFocused => black;

  @override
  Color get inputBorderError => error;

  @override
  Color get cardBackground => white;

  @override
  Color get cardBorder => black;

  // ================== Dark Theme ==================
  @override
  Color get darkBackgroundPrimary => black;

  @override
  Color get darkBackgroundSecondary => const Color(0xFF1A1A1A);

  @override
  Color get darkTextPrimary => white;

  @override
  Color get darkTextSecondary => gray300;
}
