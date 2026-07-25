import 'package:boilerplate/config/app_feature_config.dart';
import 'package:boilerplate/core/design/bold_minimalism/bold_theme.dart';
import 'package:boilerplate/core/design/design_system.dart';
import 'package:boilerplate/core/design/material3/material3_theme.dart';
import 'package:boilerplate/core/state/settings.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// 사용 가능한 디자인 시스템
enum DesignSystemType {
  material3('Material 3', 'Google의 공식 Material Design 3 시스템'),
  boldMinimalism('Bold Minimalism', '강렬하고 미니멀한 디자인 시스템');

  final String displayName;
  final String description;

  const DesignSystemType(this.displayName, this.description);
}

/// 현재 선택된 디자인 시스템을 제공하는 Provider
final designSystemProvider = Provider<DesignSystem>((ref) {
  // Only watch the specific field we need to avoid unnecessary rebuilds
  final designSystemType = ref.watch(
    settingsProvider.select((settings) => settings.designSystem),
  );

  switch (designSystemType) {
    case DesignSystemType.material3:
      return Material3Design();
    case DesignSystemType.boldMinimalism:
      return BoldMinimalismDesign();
  }
});

/// 언어별 폰트 설정
/// 현재는 모든 언어에 동일한 폰트 사용 (추후 언어별 최적화 가능)
final languageFontList = _createDefaultFontConfig();

/// 기본 폰트 설정 생성 (중복 제거)
Map<String, Map<String, String>> _createDefaultFontConfig() {
  const defaultFonts = {
    'display': 'Kalam',
    'headline': 'Kalam',
    'title': 'Kalam',
    'label': 'Kalam',
  };

  return {
    'en': defaultFonts,
    'ko': defaultFonts,
    'ja': defaultFonts,
    'zh': defaultFonts,
  };
}

/// FlexScheme 색상 정의
final themeColors = {
  'pink': FlexScheme.pinkM3,
  'red': FlexScheme.redM3,
  'deepOrange': FlexScheme.deepOrangeM3,
  'orange': FlexScheme.orangeM3,
  'yellow': FlexScheme.yellowM3,
  'lime': FlexScheme.limeM3,
  'green': FlexScheme.greenM3,
  'teal': FlexScheme.tealM3,
  'cyan': FlexScheme.cyanM3,
  'blue': FlexScheme.blueM3,
  'indigo': FlexScheme.indigoM3,
  'purple': FlexScheme.purpleM3,
};

/// 테마 제공자 - main.dart에서 사용
final themeProvider = Provider<(ThemeData, ThemeData, ThemeMode)>((ref) {
  final settings = ref.watch(settingsProvider);
  final designSystem = ref.watch(designSystemProvider);

  // 디자인 시스템이 Material3가 아닌 경우, 디자인 시스템의 테마 사용
  if (settings.designSystem != DesignSystemType.material3) {
    // 다크모드가 비활성화된 경우 항상 라이트 모드 사용
    final effectiveThemeMode = AppFeatureConfig.isDarkModeEnabled
        ? settings.displayMode
        : ThemeMode.light;
    return (designSystem.lightTheme, designSystem.darkTheme, effectiveThemeMode);
  }

  // Material3인 경우 동적으로 생성 (FlexScheme, 언어별 폰트 지원)
  final lightTheme = _createMaterial3Theme(Brightness.light, settings);
  final darkTheme = _createMaterial3Theme(Brightness.dark, settings);

  // 다크모드가 비활성화된 경우 항상 라이트 모드 사용
  final effectiveThemeMode = AppFeatureConfig.isDarkModeEnabled
      ? settings.displayMode
      : ThemeMode.light;

  return (lightTheme, darkTheme, effectiveThemeMode);
});

/// Material3 테마 생성 (FlexScheme 및 언어별 폰트 지원)
ThemeData _createMaterial3Theme(Brightness brightness, Settings settings) {
  final lang = settings.language.languageCode;

  final displayFont = languageFontList[lang]!['display']!;
  final headlineFont = languageFontList[lang]!['headline']!;
  final titleFont = languageFontList[lang]!['title']!;
  final labelFont = languageFontList[lang]!['label']!;

  // FlexScheme 사용하여 기본 테마 생성
  final baseTheme = brightness == Brightness.light
      ? FlexThemeData.light(scheme: themeColors[settings.themeColor] ?? FlexScheme.blueM3)
      : FlexThemeData.dark(scheme: themeColors[settings.themeColor] ?? FlexScheme.blueM3);

  // 텍스트 스타일 생성 헬퍼 함수 (중복 제거)
  TextStyle createTextStyle(double sizeOffset, [String? fontFamily]) {
    return TextStyle(
      fontWeight: FontWeight.normal,
      fontSize: (settings.fontSize + sizeOffset).toDouble(),
      fontFamily: fontFamily,
    );
  }

  // 텍스트 테마 - 언어별 폰트 적용
  final textTheme = GoogleFonts.getTextTheme(
    settings.bodyFont,
    TextTheme(
      displayLarge: createTextStyle(43, displayFont),
      displayMedium: createTextStyle(31, displayFont),
      displaySmall: createTextStyle(22, displayFont),
      headlineLarge: createTextStyle(18, headlineFont),
      headlineMedium: createTextStyle(14, headlineFont),
      headlineSmall: createTextStyle(10, headlineFont),
      titleLarge: createTextStyle(8, titleFont),
      titleMedium: createTextStyle(2, titleFont),
      titleSmall: createTextStyle(0, titleFont),
      bodyLarge: createTextStyle(2),
      bodyMedium: createTextStyle(0),
      bodySmall: createTextStyle(-2),
      labelLarge: createTextStyle(0, labelFont),
      labelMedium: createTextStyle(-2, labelFont),
      labelSmall: createTextStyle(-3, labelFont),
    ),
  );

  // 최종 테마 반환
  return baseTheme.copyWith(
    primaryTextTheme: textTheme,
  );
}
