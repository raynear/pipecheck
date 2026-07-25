import 'package:boilerplate/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Material3 간격 시스템
/// Google의 Material Design 3의 8dp 기반 spacing 시스템
class Material3Spacing implements DesignSpacing {
  // ================== Base Unit ==================
  /// 기본 단위 (8px)
  static const double unit = 8.0;

  // ================== Spacing Scale ==================
  @override
  double get zero => 0.0;

  @override
  double get xxs => 2.0;

  @override
  double get xs => 4.0;

  @override
  double get sm => 8.0;

  @override
  double get md => 12.0;

  @override
  double get lg => 16.0;

  @override
  double get xl => 24.0;

  @override
  double get xxl => 32.0;

  @override
  double get xxxl => 40.0;

  @override
  double get huge => 48.0;

  @override
  double get massive => 64.0;

  // ================== Component Specific ==================
  @override
  double get cardPadding => lg;

  @override
  EdgeInsets get buttonPadding => EdgeInsets.symmetric(
        horizontal: lg,
        vertical: md,
      );

  @override
  EdgeInsets get inputPadding => EdgeInsets.symmetric(
        horizontal: lg,
        vertical: md,
      );

  @override
  EdgeInsets get screenPadding => EdgeInsets.all(lg);

  @override
  EdgeInsets get listItemPadding => EdgeInsets.symmetric(
        horizontal: lg,
        vertical: md,
      );

  @override
  EdgeInsets get dialogPadding => EdgeInsets.all(xl);

  // ================== Layout Helpers ==================
  @override
  SizedBox vertical(double height) => SizedBox(height: height);

  @override
  SizedBox horizontal(double width) => SizedBox(width: width);

  // ================== Border Radius ==================
  @override
  double get radiusXs => 4.0;

  @override
  double get radiusSm => 8.0;

  @override
  double get radiusMd => 12.0;

  @override
  double get radiusLg => 16.0;

  @override
  double get radiusXl => 24.0;

  @override
  double get radiusXxl => 32.0;

  @override
  double get radiusFull => 9999.0; // 완전한 원

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

  // ================== Icon Sizes ==================
  @override
  double get iconXs => 16.0;

  @override
  double get iconSm => 20.0;

  @override
  double get iconMd => 24.0;

  @override
  double get iconLg => 32.0;

  @override
  double get iconXl => 40.0;

  @override
  double get iconXxl => 48.0;

  // ================== Additional Material3 Helpers ==================
  /// 자주 사용되는 수직 간격들
  SizedBox get verticalXxs => vertical(xxs);
  SizedBox get verticalXs => vertical(xs);
  SizedBox get verticalSm => vertical(sm);
  SizedBox get verticalMd => vertical(md);
  SizedBox get verticalLg => vertical(lg);
  SizedBox get verticalXl => vertical(xl);
  SizedBox get verticalXxl => vertical(xxl);
  SizedBox get verticalXxxl => vertical(xxxl);

  /// 자주 사용되는 수평 간격들
  SizedBox get horizontalXxs => horizontal(xxs);
  SizedBox get horizontalXs => horizontal(xs);
  SizedBox get horizontalSm => horizontal(sm);
  SizedBox get horizontalMd => horizontal(md);
  SizedBox get horizontalLg => horizontal(lg);
  SizedBox get horizontalXl => horizontal(xl);
  SizedBox get horizontalXxl => horizontal(xxl);
  SizedBox get horizontalXxxl => horizontal(xxxl);

  /// 그리드 시스템
  double get gridGutter => lg;
  int get gridColumns => 12;
}
