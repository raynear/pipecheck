import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 칩 (6:3:1 비율 준수)
/// 배경(60%) - 라벨(30%) - 아이콘/액션(10%)
class AdaptiveChip extends StatelessWidget {
  final String label;
  final Widget? avatar;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onDeleted;
  final bool selected;
  final ChipVariant variant;
  final ChipSize size;

  const AdaptiveChip({
    super.key,
    required this.label,
    this.avatar,
    this.icon,
    this.onPressed,
    this.onDeleted,
    this.selected = false,
    this.variant = ChipVariant.filled,
    this.size = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final isClickable = onPressed != null;
    final isDeletable = onDeleted != null;

    // Size configurations
    EdgeInsets padding;
    TextStyle textStyle;
    double iconSize;

    switch (size) {
      case ChipSize.small:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        );
        textStyle = typography.labelSmall;
        iconSize = spacing.iconXs;
        break;
      case ChipSize.medium:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        );
        textStyle = typography.labelMedium;
        iconSize = spacing.iconSm;
        break;
      case ChipSize.large:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        );
        textStyle = typography.labelLarge;
        iconSize = spacing.iconMd;
        break;
    }

    // Variant configurations
    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (variant) {
      case ChipVariant.filled:
        if (selected) {
          backgroundColor = colors.primary;
          foregroundColor = colors.textOnPrimary;
        } else {
          backgroundColor = colors.gray100;
          foregroundColor = colors.textPrimary;
        }
        border = null;
        break;
      case ChipVariant.outlined:
        backgroundColor = Colors.transparent;
        if (selected) {
          foregroundColor = colors.primary;
          border = Border.all(
            color: colors.primary,
            width: isBoldMinimalism ? 2 : 1,
          );
        } else {
          foregroundColor = colors.textPrimary;
          border = Border.all(
            color: colors.border,
            width: isBoldMinimalism ? 2 : 1,
          );
        }
        break;
      case ChipVariant.tonal:
        if (selected) {
          backgroundColor = colors.primaryLight;
          foregroundColor = colors.primaryDark;
        } else {
          backgroundColor = colors.gray50;
          foregroundColor = colors.textPrimary;
        }
        border = null;
        break;
    }

    final chip = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusFull,
        ),
        side: border != null
            ? BorderSide(
                color: border.bottom.color,
                width: border.bottom.width,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isClickable ? onPressed : null,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusFull,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null)
                avatar!
              else if (icon != null)
                Icon(
                  icon,
                  size: iconSize,
                  color: foregroundColor,
                ),
              if (avatar != null || icon != null) SizedBox(width: spacing.xs),
              Text(
                label,
                style: textStyle.copyWith(
                  color: foregroundColor,
                ),
              ),
              if (isDeletable) ...[
                SizedBox(width: spacing.xs),
                InkWell(
                  onTap: onDeleted,
                  child: Icon(
                    Icons.close,
                    size: iconSize,
                    color: foregroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return chip;
  }
}

/// 필터 칩
class AdaptiveFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final IconData? icon;
  final ChipSize size;

  const AdaptiveFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.avatar,
    this.icon,
    this.size = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveChip(
      label: label,
      selected: selected,
      onPressed: onSelected != null ? () => onSelected!(!selected) : null,
      avatar: avatar,
      icon: icon,
      variant: ChipVariant.tonal,
      size: size,
    );
  }
}

/// 선택 칩
class AdaptiveChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final IconData? icon;
  final ChipSize size;

  const AdaptiveChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.avatar,
    this.icon,
    this.size = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveChip(
      label: label,
      selected: selected,
      onPressed: onSelected != null ? () => onSelected!(!selected) : null,
      avatar: avatar,
      icon: icon,
      variant: ChipVariant.filled,
      size: size,
    );
  }
}

/// 액션 칩
class AdaptiveActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? avatar;
  final IconData? icon;
  final ChipSize size;

  const AdaptiveActionChip({
    super.key,
    required this.label,
    this.onPressed,
    this.avatar,
    this.icon,
    this.size = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveChip(
      label: label,
      onPressed: onPressed,
      avatar: avatar,
      icon: icon,
      variant: ChipVariant.outlined,
      size: size,
    );
  }
}

/// 입력 칩
class AdaptiveInputChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;
  final Widget? avatar;
  final IconData? icon;
  final ChipSize size;

  const AdaptiveInputChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.avatar,
    this.icon,
    this.size = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveChip(
      label: label,
      selected: selected,
      onPressed: onSelected != null ? () => onSelected!(!selected) : null,
      onDeleted: onDeleted,
      avatar: avatar,
      icon: icon,
      variant: ChipVariant.filled,
      size: size,
    );
  }
}

/// 칩 그룹
class AdaptiveChipGroup extends StatelessWidget {
  final List<Widget> chips;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAlignment;

  const AdaptiveChipGroup({
    super.key,
    required this.chips,
    this.spacing = 8,
    this.runSpacing = 8,
    this.alignment = WrapAlignment.start,
    this.crossAlignment = WrapCrossAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAlignment,
      children: chips,
    );
  }
}

enum ChipVariant { filled, outlined, tonal }

enum ChipSize { small, medium, large }
