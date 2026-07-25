import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 스위치 (6:3:1 비율 준수)
/// 배경(60%) - 트랙(30%) - 썸(10%)
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final String? label;
  final IconData? activeIcon;
  final IconData? inactiveIcon;
  final SwitchSize size;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.label,
    this.activeIcon,
    this.inactiveIcon,
    this.size = SwitchSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    double scale;
    TextStyle? labelStyle;

    switch (size) {
      case SwitchSize.small:
        scale = 0.8;
        labelStyle = typography.labelSmall;
        break;
      case SwitchSize.medium:
        scale = 1.0;
        labelStyle = typography.labelMedium;
        break;
      case SwitchSize.large:
        scale = 1.2;
        labelStyle = typography.labelLarge;
        break;
    }

    Widget switchWidget = Transform.scale(
      scale: scale,
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return activeColor ?? colors.primary;
          }
          return inactiveColor ?? colors.gray400;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return activeTrackColor ?? colors.primaryLight;
          }
          return inactiveTrackColor ?? colors.gray200;
        }),
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
          if (states.contains(WidgetState.selected)) {
            return activeIcon != null ? Icon(activeIcon, size: 16, color: colors.white) : null;
          }
          return inactiveIcon != null ? Icon(inactiveIcon, size: 16, color: colors.gray600) : null;
        }),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        overlayColor: isBoldMinimalism ? WidgetStateProperty.all(Colors.transparent) : null,
      ),
    );

    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switchWidget,
          SizedBox(width: spacing.sm),
          Text(
            label!,
            style: labelStyle,
          ),
        ],
      );
    }

    return switchWidget;
  }
}

/// 적응형 체크박스 (6:3:1 비율 준수)
/// 배경(60%) - 테두리(30%) - 체크마크(10%)
class AdaptiveCheckbox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final Color? activeColor;
  final Color? checkColor;
  final String? label;
  final CheckboxSize size;
  final CheckboxShape shape;

  const AdaptiveCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.activeColor,
    this.checkColor,
    this.label,
    this.size = CheckboxSize.medium,
    this.shape = CheckboxShape.square,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    double scale;
    TextStyle? labelStyle;

    switch (size) {
      case CheckboxSize.small:
        scale = 0.8;
        labelStyle = typography.labelSmall;
        break;
      case CheckboxSize.medium:
        scale = 1.0;
        labelStyle = typography.labelMedium;
        break;
      case CheckboxSize.large:
        scale = 1.2;
        labelStyle = typography.labelLarge;
        break;
    }

    Widget checkbox = Transform.scale(
      scale: scale,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        tristate: tristate,
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return activeColor ?? colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: checkColor ?? colors.white,
        shape: shape == CheckboxShape.circle
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  isBoldMinimalism ? 0 : spacing.radiusXs,
                ),
              ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        overlayColor: isBoldMinimalism ? WidgetStateProperty.all(Colors.transparent) : null,
      ),
    );

    if (label != null) {
      return InkWell(
        onTap: onChanged != null ? () => onChanged!(value == true ? false : true) : null,
        borderRadius: BorderRadius.circular(spacing.radiusSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            checkbox,
            SizedBox(width: spacing.xs),
            Text(
              label!,
              style: labelStyle,
            ),
          ],
        ),
      );
    }

    return checkbox;
  }
}

/// 적응형 라디오 버튼 (6:3:1 비율 준수)
/// 배경(60%) - 테두리(30%) - 선택 표시(10%)
///
/// Flutter 3.32.0+: RadioGroup 내부에서 사용됩니다.
/// 단독 사용시 groupValue와 onChanged는 상위 RadioGroup이 관리합니다.
class AdaptiveRadio<T> extends StatelessWidget {
  final T value;
  final Color? activeColor;
  final String? label;
  final RadioSize size;

  const AdaptiveRadio({
    super.key,
    required this.value,
    this.activeColor,
    this.label,
    this.size = RadioSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    double scale;
    TextStyle? labelStyle;

    switch (size) {
      case RadioSize.small:
        scale = 0.8;
        labelStyle = typography.labelSmall;
        break;
      case RadioSize.medium:
        scale = 1.0;
        labelStyle = typography.labelMedium;
        break;
      case RadioSize.large:
        scale = 1.2;
        labelStyle = typography.labelLarge;
        break;
    }

    Widget radio = Transform.scale(
      scale: scale,
      child: Radio<T>(
        value: value,
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return activeColor ?? colors.primary;
          }
          return colors.gray400;
        }),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        overlayColor: isBoldMinimalism ? WidgetStateProperty.all(Colors.transparent) : null,
      ),
    );

    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          radio,
          SizedBox(width: spacing.xs),
          Text(
            label!,
            style: labelStyle,
          ),
        ],
      );
    }

    return radio;
  }
}

/// 적응형 라디오 그룹 (Flutter 3.32.0+ RadioGroup 사용)
/// groupValue와 onChanged를 관리하는 RadioGroup 래퍼
class AdaptiveRadioGroup<T> extends StatelessWidget {
  final List<RadioOption<T>> options;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Axis direction;
  final RadioSize size;
  final double spacing;

  const AdaptiveRadioGroup({
    super.key,
    required this.options,
    required this.groupValue,
    required this.onChanged,
    this.direction = Axis.vertical,
    this.size = RadioSize.medium,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final children = options
        .map((option) => AdaptiveRadio<T>(
              value: option.value,
              label: option.label,
              size: size,
            ))
        .toList();

    final content = direction == Axis.horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: children
                .map((child) => Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: child,
                    ))
                .toList(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((child) => Padding(
                      padding: EdgeInsets.only(bottom: spacing),
                      child: child,
                    ))
                .toList(),
          );

    // onChanged가 null이면 빈 핸들러 제공 (disabled 상태)
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged ?? (_) {},
      child: content,
    );
  }
}

/// 적응형 토글 버튼
class AdaptiveToggleButtons extends StatelessWidget {
  final List<Widget> children;
  final List<bool> isSelected;
  final ValueChanged<int>? onPressed;
  final bool allowMultipleSelection;
  final ToggleButtonsSize size;
  final ToggleButtonsVariant variant;

  const AdaptiveToggleButtons({
    super.key,
    required this.children,
    required this.isSelected,
    this.onPressed,
    this.allowMultipleSelection = false,
    this.size = ToggleButtonsSize.medium,
    this.variant = ToggleButtonsVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    // Size configurations
    EdgeInsets padding;
    BorderRadius borderRadius;

    switch (size) {
      case ToggleButtonsSize.small:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        );
        break;
      case ToggleButtonsSize.medium:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        );
        break;
      case ToggleButtonsSize.large:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        );
        break;
    }

    borderRadius = BorderRadius.circular(
      isBoldMinimalism ? 0 : spacing.radiusMd,
    );

    // Variant configurations
    Color? fillColor;
    Color? selectedColor;
    Color? selectedBorderColor;
    Color? borderColor;

    switch (variant) {
      case ToggleButtonsVariant.standard:
        fillColor = null;
        selectedColor = colors.primary;
        selectedBorderColor = colors.primary;
        borderColor = colors.border;
        break;
      case ToggleButtonsVariant.filled:
        fillColor = colors.primary;
        selectedColor = colors.white;
        selectedBorderColor = colors.primary;
        borderColor = colors.border;
        break;
      case ToggleButtonsVariant.tonal:
        fillColor = colors.primaryLight;
        selectedColor = colors.primaryDark;
        selectedBorderColor = colors.primaryLight;
        borderColor = colors.border;
        break;
    }

    return ToggleButtons(
      isSelected: isSelected,
      onPressed: (index) {
        if (allowMultipleSelection) {
          onPressed?.call(index);
        } else {
          // Single selection
          if (!isSelected[index]) {
            onPressed?.call(index);
          }
        }
      },
      borderRadius: borderRadius,
      selectedBorderColor: selectedBorderColor,
      selectedColor: selectedColor,
      fillColor: fillColor,
      color: colors.textPrimary,
      borderColor: borderColor,
      borderWidth: isBoldMinimalism ? 2 : 1,
      constraints: BoxConstraints(
        minHeight: 36,
        minWidth: 48,
      ),
      children: children
          .map((child) => Padding(
                padding: padding,
                child: child,
              ))
          .toList(),
    );
  }
}

class RadioOption<T> {
  final T value;
  final String label;

  const RadioOption({
    required this.value,
    required this.label,
  });
}

enum SwitchSize { small, medium, large }

enum CheckboxSize { small, medium, large }

enum CheckboxShape { square, circle }

enum RadioSize { small, medium, large }

enum ToggleButtonsSize { small, medium, large }

enum ToggleButtonsVariant { standard, filled, tonal }
