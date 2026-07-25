import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 기본 커스텀 카드
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Border? border;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.onTap,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: backgroundColor ?? context.colors.cardBackground,
        elevation: elevation ?? 1,
        borderRadius: borderRadius ?? context.spacing.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? context.spacing.borderRadiusMd,
          child: Container(
            padding: padding ?? EdgeInsets.all(context.spacing.cardPadding),
            decoration: BoxDecoration(
              border: border ?? Border.all(color: context.colors.cardBorder),
              borderRadius: borderRadius ?? context.spacing.borderRadiusMd,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 정보 카드
class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(context.spacing.sm),
              decoration: BoxDecoration(
                color: (iconColor ?? context.colors.primary).withValues(alpha: 0.1),
                borderRadius: context.spacing.borderRadiusSm,
              ),
              child: Icon(
                icon,
                color: iconColor ?? context.colors.primary,
                size: context.spacing.iconMd,
              ),
            ),
            SizedBox(width: context.spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typography.titleSmall,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: context.spacing.xs),
                  Text(
                    subtitle!,
                    style: context.typography.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onTap != null && trailing == null)
            Icon(
              Icons.chevron_right,
              color: context.colors.textTertiary,
            ),
        ],
      ),
    );
  }
}

/// 통계 카드
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? trend;
  final bool isPositive;
  final Widget? chart;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.trend,
    this.isPositive = true,
    this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = isPositive ? context.colors.success : context.colors.error;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: color ?? context.colors.primary,
                  size: context.spacing.iconMd,
                ),
              if (trend != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.sm,
                    vertical: context.spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.1),
                    borderRadius: context.spacing.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: context.spacing.iconXs,
                        color: trendColor,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        trend!,
                        style: context.typography.labelSmall.copyWith(
                          color: trendColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Text(
            value,
            style: context.typography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? context.colors.textPrimary,
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            label,
            style: context.typography.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (chart != null) ...[
            SizedBox(height: context.spacing.md),
            SizedBox(
              height: 50,
              child: chart,
            ),
          ],
        ],
      ),
    );
  }
}

/// 이미지가 있는 카드
class ImageCard extends StatelessWidget {
  final String? imageUrl;
  final Widget? imageWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double imageHeight;
  final BoxFit imageFit;

  const ImageCard({
    super.key,
    this.imageUrl,
    this.imageWidget,
    required this.title,
    this.subtitle,
    this.onTap,
    this.imageHeight = 200,
    this.imageFit = BoxFit.cover,
  }) : assert(imageUrl != null || imageWidget != null);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.spacing.radiusMd),
            ),
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: imageWidget ??
                  (imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: imageFit,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: context.colors.gray200,
                            child: Icon(
                              Icons.broken_image,
                              color: context.colors.gray400,
                            ),
                          ),
                        )
                      : Container(
                          color: context.colors.gray200,
                        )),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.spacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: context.spacing.sm),
                  Text(
                    subtitle!,
                    style: context.typography.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
