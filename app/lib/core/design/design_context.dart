import 'package:pipecheck/core/design/design_system.dart';
import 'package:pipecheck/core/design/design_system_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// BuildContext extension for easy access to design system
extension DesignContext on BuildContext {
  /// 현재 디자인 시스템을 가져옵니다
  DesignSystem get design {
    // ProviderScope.containerOf를 사용하여 Provider에 접근
    final container = ProviderScope.containerOf(this);
    return container.read(designSystemProvider);
  }

  /// 현재 디자인 시스템의 색상을 가져옵니다
  DesignColors get colors => design.colors;

  /// 현재 디자인 시스템의 간격을 가져옵니다
  DesignSpacing get spacing => design.spacing;

  /// 현재 디자인 시스템의 타이포그래피를 가져옵니다
  DesignTypography get typography => design.typography;

  /// 현재 테마가 다크모드인지 확인합니다
  bool get isDarkMode => design.isDark(this);

  /// 현재 ColorScheme을 가져옵니다
  ColorScheme get colorScheme => design.colorScheme(this);

  /// 현재 TextTheme을 가져옵니다
  TextTheme get textTheme => design.textTheme(this);
}
