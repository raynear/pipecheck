import 'package:flutter/material.dart';

/// 디자인 시스템의 추상 인터페이스
abstract class DesignSystem {
  /// 디자인 시스템의 이름
  String get name;
  
  /// 디자인 시스템의 설명
  String get description;
  
  /// 색상 시스템
  DesignColors get colors;
  
  /// 간격 시스템
  DesignSpacing get spacing;
  
  /// 타이포그래피 시스템
  DesignTypography get typography;
  
  /// 라이트 테마
  ThemeData get lightTheme;
  
  /// 다크 테마
  ThemeData get darkTheme;
  
  /// 현재 테마가 다크 모드인지 확인
  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  /// 테마 색상 접근 헬퍼
  ColorScheme colorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }
  
  /// 테마 텍스트 스타일 접근 헬퍼
  TextTheme textTheme(BuildContext context) {
    return Theme.of(context).textTheme;
  }
}

/// 색상 시스템 인터페이스
abstract class DesignColors {
  // Brand Colors
  Color get primary;
  Color get primaryLight;
  Color get primaryDark;
  Color get secondary;
  Color get secondaryLight;
  Color get secondaryDark;
  
  // Semantic Colors
  Color get success;
  Color get successLight;
  Color get successDark;
  Color get error;
  Color get errorLight;
  Color get errorDark;
  Color get warning;
  Color get warningLight;
  Color get warningDark;
  Color get info;
  Color get infoLight;
  Color get infoDark;
  
  // Neutral Colors
  Color get white;
  Color get black;
  Color get gray50;
  Color get gray100;
  Color get gray200;
  Color get gray300;
  Color get gray400;
  Color get gray500;
  Color get gray600;
  Color get gray700;
  Color get gray800;
  Color get gray900;
  
  // Background Colors
  Color get backgroundPrimary;
  Color get backgroundSecondary;
  Color get backgroundTertiary;
  Color get backgroundElevated;
  Color get backgroundOverlay;
  
  // Text Colors
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textDisabled;
  Color get textOnPrimary;
  Color get textOnSecondary;
  Color get textOnError;
  
  // Border Colors
  Color get border;
  Color get borderLight;
  Color get borderDark;
  
  // Special Colors
  Color get divider;
  Color get shadow;
  Color get overlay;
  
  // Component Specific
  Color get buttonPrimary;
  Color get buttonSecondary;
  Color get buttonDisabled;
  Color get inputBackground;
  Color get inputBorder;
  Color get inputBorderFocused;
  Color get inputBorderError;
  Color get cardBackground;
  Color get cardBorder;
  
  // Dark Theme
  Color get darkBackgroundPrimary;
  Color get darkBackgroundSecondary;
  Color get darkTextPrimary;
  Color get darkTextSecondary;
}

/// 간격 시스템 인터페이스
abstract class DesignSpacing {
  // Spacing Scale
  double get zero;
  double get xxs;
  double get xs;
  double get sm;
  double get md;
  double get lg;
  double get xl;
  double get xxl;
  double get xxxl;
  double get huge;
  double get massive;
  
  // Component Specific
  double get cardPadding;
  EdgeInsets get buttonPadding;
  EdgeInsets get inputPadding;
  EdgeInsets get screenPadding;
  EdgeInsets get listItemPadding;
  EdgeInsets get dialogPadding;
  
  // Layout Helpers
  SizedBox vertical(double height) => SizedBox(height: height);
  SizedBox horizontal(double width) => SizedBox(width: width);
  
  // Border Radius
  double get radiusXs;
  double get radiusSm;
  double get radiusMd;
  double get radiusLg;
  double get radiusXl;
  double get radiusXxl;
  double get radiusFull;
  
  BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);
  BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);
  
  // Icon Sizes
  double get iconXs;
  double get iconSm;
  double get iconMd;
  double get iconLg;
  double get iconXl;
  double get iconXxl;
}

/// 타이포그래피 시스템 인터페이스
abstract class DesignTypography {
  String get fontFamily;
  
  // Display Styles
  TextStyle get displayLarge;
  TextStyle get displayMedium;
  TextStyle get displaySmall;
  
  // Headline Styles
  TextStyle get headlineLarge;
  TextStyle get headlineMedium;
  TextStyle get headlineSmall;
  
  // Title Styles
  TextStyle get titleLarge;
  TextStyle get titleMedium;
  TextStyle get titleSmall;
  
  // Body Styles
  TextStyle get bodyLarge;
  TextStyle get bodyMedium;
  TextStyle get bodySmall;
  
  // Label Styles
  TextStyle get labelLarge;
  TextStyle get labelMedium;
  TextStyle get labelSmall;
  
  // Custom Styles
  TextStyle get button;
  TextStyle get link;
  TextStyle get error;
  TextStyle get hint;
  TextStyle get caption;
  TextStyle get overline;
  
  // Font Weights
  FontWeight get thin;
  FontWeight get light;
  FontWeight get regular;
  FontWeight get medium;
  FontWeight get semiBold;
  FontWeight get bold;
  FontWeight get extraBold;
  FontWeight get black;
}