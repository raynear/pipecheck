import 'package:pipecheck/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Bold Minimalism 간격 시스템
/// 넓은 여백과 극적인 공간 활용
class BoldSpacing implements DesignSpacing {
  // ================== Base Unit ==================
  /// 기본 단위 (12px - Material3보다 50% 더 큼)
  static const double unit = 12.0;

  // ================== Spacing Scale ==================
  @override
  double get zero => 0.0;

  @override
  double get xxs => 4.0;

  @override
  double get xs => 8.0;

  @override
  double get sm => 12.0; // 기본 단위

  @override
  double get md => 16.0;

  @override
  double get lg => 24.0;

  @override
  double get xl => 36.0;

  @override
  double get xxl => 48.0;

  @override
  double get xxxl => 60.0;

  @override
  double get huge => 72.0;

  @override
  double get massive => 96.0;

  // ================== Component Specific ==================
  @override
  double get cardPadding => xl; // 더 넓은 패딩

  @override
  EdgeInsets get buttonPadding => EdgeInsets.symmetric(
        horizontal: xl,
        vertical: lg,
      );

  @override
  EdgeInsets get inputPadding => EdgeInsets.symmetric(
        horizontal: lg,
        vertical: lg,
      );

  @override
  EdgeInsets get screenPadding => EdgeInsets.all(xl);

  @override
  EdgeInsets get listItemPadding => EdgeInsets.symmetric(
        horizontal: xl,
        vertical: lg,
      );

  @override
  EdgeInsets get dialogPadding => EdgeInsets.all(xxl);

  // ================== Layout Helpers ==================
  @override
  SizedBox vertical(double height) => SizedBox(height: height);

  @override
  SizedBox horizontal(double width) => SizedBox(width: width);

  // ================== Border Radius ==================
  @override
  double get radiusXs => 0.0; // Sharp corners

  @override
  double get radiusSm => 0.0;

  @override
  double get radiusMd => 0.0;

  @override
  double get radiusLg => 0.0;

  @override
  double get radiusXl => 0.0;

  @override
  double get radiusXxl => 0.0;

  @override
  double get radiusFull => 9999.0; // 원형은 유지

  // ================== Icon Sizes ==================
  @override
  double get iconXs => 20.0;

  @override
  double get iconSm => 24.0;

  @override
  double get iconMd => 32.0;

  @override
  double get iconLg => 40.0;

  @override
  double get iconXl => 48.0;

  @override
  double get iconXxl => 64.0;

  // ================== Border Radius Getters ==================
  @override
  BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);

  @override
  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);

  @override
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);

  @override
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);

  @override
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  @override
  BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);

  @override
  BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);
}
