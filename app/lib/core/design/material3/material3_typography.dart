import 'package:pipecheck/core/design/design_system.dart';
import 'package:pipecheck/core/design/material3/material3_colors.dart';
import 'package:flutter/material.dart';

/// Material3 타이포그래피 시스템
/// Google의 Material Design 3의 타입 스케일을 기반으로 합니다.
class Material3Typography implements DesignTypography {
  final Material3Colors _colors = Material3Colors();

  @override
  String get fontFamily => 'Roboto';

  // ================== Display Styles ==================
  @override
  TextStyle get displayLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
      );

  @override
  TextStyle get displayMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
      );

  @override
  TextStyle get displaySmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.22,
      );

  // ================== Headline Styles ==================
  @override
  TextStyle get headlineLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
      );

  @override
  TextStyle get headlineMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
      );

  @override
  TextStyle get headlineSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
      );

  // ================== Title Styles ==================
  @override
  TextStyle get titleLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.27,
      );

  @override
  TextStyle get titleMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
      );

  @override
  TextStyle get titleSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      );

  // ================== Body Styles ==================
  @override
  TextStyle get bodyLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      );

  @override
  TextStyle get bodyMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      );

  @override
  TextStyle get bodySmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      );

  // ================== Label Styles ==================
  @override
  TextStyle get labelLarge => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      );

  @override
  TextStyle get labelMedium => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      );

  @override
  TextStyle get labelSmall => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      );

  // ================== Custom Styles ==================
  @override
  TextStyle get button => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        height: 1.43,
      );

  @override
  TextStyle get link => bodyMedium.copyWith(
        color: _colors.primary,
        decoration: TextDecoration.underline,
      );

  @override
  TextStyle get error => bodySmall.copyWith(
        color: _colors.error,
      );

  @override
  TextStyle get hint => bodyMedium.copyWith(
        color: _colors.textTertiary,
      );

  @override
  TextStyle get caption => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
        color: _colors.textSecondary,
      );

  @override
  TextStyle get overline => TextStyle(
        fontFamily: fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
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
