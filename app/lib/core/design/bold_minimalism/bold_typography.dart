import 'package:boilerplate/core/design/bold_minimalism/bold_colors.dart';
import 'package:boilerplate/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Bold Minimalism 타이포그래피 시스템
/// 강렬하고 대담한 텍스트 스타일
class BoldTypography implements DesignTypography {
  final BoldColors _colors = BoldColors();

  @override
  String get fontFamily => 'Inter'; // Clean, modern sans-serif

  // ================== Display Styles ==================
  @override
  TextStyle get displayLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 96, // 매우 큰 사이즈
        fontWeight: FontWeight.w900, // Extra bold
        letterSpacing: -2.0,
        height: 1.0,
      );

  @override
  TextStyle get displayMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 72,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.1,
      );

  @override
  TextStyle get displaySmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.1,
      );

  // ================== Headline Styles ==================
  @override
  TextStyle get headlineLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      );

  @override
  TextStyle get headlineMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.2,
      );

  @override
  TextStyle get headlineSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      );

  // ================== Title Styles ==================
  @override
  TextStyle get titleLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      );

  @override
  TextStyle get titleMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.4,
      );

  @override
  TextStyle get titleSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      );

  // ================== Body Styles ==================
  @override
  TextStyle get bodyLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.6,
      );

  @override
  TextStyle get bodyMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.6,
      );

  @override
  TextStyle get bodySmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      );

  // ================== Label Styles ==================
  @override
  TextStyle get labelLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700, // Bold for labels
        letterSpacing: 1.0, // Wide letter spacing
        height: 1.4,
      );

  @override
  TextStyle get labelMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.4,
      );

  @override
  TextStyle get labelSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.4,
      );

  // ================== Custom Styles ==================
  @override
  TextStyle get button => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.4,
      );

  @override
  TextStyle get link => bodyMedium.copyWith(
        color: _colors.secondary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationThickness: 2.0,
      );

  @override
  TextStyle get error => bodySmall.copyWith(
        color: _colors.error,
        fontWeight: FontWeight.w600,
      );

  @override
  TextStyle get hint => bodyMedium.copyWith(
        color: _colors.textTertiary,
        fontWeight: FontWeight.w300,
      );

  @override
  TextStyle get caption => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
        color: _colors.textSecondary,
      );

  @override
  TextStyle get overline => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0, // Very wide letter spacing
        height: 1.6,
      );

  // ================== Font Weights ==================
  @override
  FontWeight get thin => FontWeight.w100;

  @override
  FontWeight get light => FontWeight.w300;

  @override
  FontWeight get regular => FontWeight.w400;

  @override
  FontWeight get medium => FontWeight.w500;

  @override
  FontWeight get semiBold => FontWeight.w600;

  @override
  FontWeight get bold => FontWeight.w700;

  @override
  FontWeight get extraBold => FontWeight.w800;

  @override
  FontWeight get black => FontWeight.w900;
}
