import 'package:flutter/material.dart';

/// Color 관련 유틸리티 확장 함수들을 제공합니다.
extension ColorUtils on Color {
  /// 알파 값을 변경한 새로운 Color 인스턴스를 반환합니다.
  ///
  /// [alpha] - 0.0부터 1.0 사이의 값으로, 투명도를 결정합니다.
  Color withValues({double? alpha, int? red, int? green, int? blue}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : a.toInt(),
      red ?? r.toInt(),
      green ?? g.toInt(),
      blue ?? b.toInt(),
    );
  }

  /// 색상의 밝기를 조정합니다.
  ///
  /// [amount] - -1.0부터 1.0 사이의 값으로, 음수는 어둡게, 양수는 밝게 조정합니다.
  Color adjustBrightness(double amount) {
    assert(amount >= -1 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  /// 현재 색상의 보색을 생성합니다.
  Color generateComplementaryColor(Brightness brightness) {
    final HSLColor hslColor = HSLColor.fromColor(this);
    final double newHue = (hslColor.hue + 180) % 360;
    final double newSaturation = (brightness == Brightness.dark)
        ? (hslColor.saturation * 1.3).clamp(0.0, 1.0)
        : (hslColor.saturation * 1.8).clamp(0.0, 1.0);
    final double newLightness = (brightness == Brightness.dark)
        ? (hslColor.lightness * 1.0).clamp(0.0, 1.0)
        : (hslColor.lightness * 1.0).clamp(0.0, 1.0);

    return HSLColor.fromAHSL(1, newHue, newSaturation, newLightness).toColor();
  }

  /// 색상 변화 단계 생성 - 히트맵 등에 사용
  static Map<int, Color> generateColorGradient(
      {required Color baseColor, required int steps, double maxOpacity = 1.0}) {
    final Map<int, Color> colorMap = {};
    for (int i = 0; i <= steps; i++) {
      final opacity = (i / steps * maxOpacity).clamp(0.1, maxOpacity);
      colorMap[i] = baseColor.withValues(alpha: opacity);
    }
    return colorMap;
  }
}
