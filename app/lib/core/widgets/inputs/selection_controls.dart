import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 체크박스
class AdaptiveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final String? subtitle;
  final bool tristate;
  final bool enabled;
  final CheckboxPosition position;

  const AdaptiveCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.subtitle,
    this.tristate = false,
    this.enabled = true,
    this.position = CheckboxPosition.leading,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final checkbox = Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : spacing.radiusXs,
            ),
          ),
          side: BorderSide(
            color: enabled ? colors.inputBorder : colors.borderLight,
            width: isBoldMinimalism ? 2 : 1,
          ),
        ),
      ),
      child: Checkbox(
        value: value,
        onChanged: enabled ? onChanged : null,
        tristate: tristate,
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: colors.textOnPrimary,
      ),
    );

    if (label == null && subtitle == null) {
      return checkbox;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: typography.bodyMedium.copyWith(
              color: enabled ? colors.textPrimary : colors.textDisabled,
            ),
          ),
        if (subtitle != null) ...[
          SizedBox(height: spacing.xxs),
          Text(
            subtitle!,
            style: typography.bodySmall.copyWith(
              color: enabled ? colors.textSecondary : colors.textDisabled,
            ),
          ),
        ],
      ],
    );

    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(spacing.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: spacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: position == CheckboxPosition.leading
              ? [
                  checkbox,
                  SizedBox(width: spacing.sm),
                  Expanded(child: content),
                ]
              : [
                  Expanded(child: content),
                  SizedBox(width: spacing.sm),
                  checkbox,
                ],
        ),
      ),
    );
  }
}

/// 적응형 라디오 버튼
///
/// Flutter 3.32.0+: RadioGroup 내부에서 사용하도록 설계되었습니다.
/// AdaptiveRadioGroup을 사용하여 여러 라디오 버튼을 관리하세요.
class AdaptiveRadio<T> extends StatelessWidget {
  final T value;
  final String? label;
  final String? subtitle;
  final bool enabled;

  const AdaptiveRadio({
    super.key,
    required this.value,
    this.label,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final radio = Theme(
      data: Theme.of(context).copyWith(
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.textDisabled;
            }
            if (states.contains(WidgetState.selected)) {
              return colors.primary;
            }
            return colors.inputBorder;
          }),
        ),
      ),
      child: Radio<T>(
        value: value,
      ),
    );

    if (label == null && subtitle == null) {
      return radio;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: typography.bodyMedium.copyWith(
              color: enabled ? colors.textPrimary : colors.textDisabled,
            ),
          ),
        if (subtitle != null) ...[
          SizedBox(height: spacing.xxs),
          Text(
            subtitle!,
            style: typography.bodySmall.copyWith(
              color: enabled ? colors.textSecondary : colors.textDisabled,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: spacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          radio,
          SizedBox(width: spacing.sm),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// 적응형 라디오 리스트 그룹 (Flutter 3.32.0+ RadioGroup 사용)
/// label과 subtitle을 지원하는 상세한 라디오 그룹
class AdaptiveRadioListGroup<T> extends StatelessWidget {
  final List<AdaptiveRadioOption<T>> options;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const AdaptiveRadioListGroup({
    super.key,
    required this.options,
    required this.groupValue,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = options
        .map((option) => AdaptiveRadio<T>(
              value: option.value,
              label: option.label,
              subtitle: option.subtitle,
              enabled: enabled,
            ))
        .toList();

    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: enabled && onChanged != null ? onChanged! : (_) {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 라디오 옵션 데이터 클래스
class AdaptiveRadioOption<T> {
  final T value;
  final String? label;
  final String? subtitle;

  const AdaptiveRadioOption({
    required this.value,
    this.label,
    this.subtitle,
  });
}

/// 적응형 스위치
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final bool enabled;
  final SwitchPosition position;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.subtitle,
    this.enabled = true,
    this.position = SwitchPosition.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final switchWidget = Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.primary;
        }
        return colors.gray400;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.primary.withValues(alpha: 0.5);
        }
        return colors.gray200;
      }),
    );

    if (label == null && subtitle == null) {
      return switchWidget;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: typography.bodyMedium.copyWith(
              color: enabled ? colors.textPrimary : colors.textDisabled,
            ),
          ),
        if (subtitle != null) ...[
          SizedBox(height: spacing.xxs),
          Text(
            subtitle!,
            style: typography.bodySmall.copyWith(
              color: enabled ? colors.textSecondary : colors.textDisabled,
            ),
          ),
        ],
      ],
    );

    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(spacing.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: spacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: position == SwitchPosition.leading
              ? [
                  switchWidget,
                  SizedBox(width: spacing.md),
                  Expanded(child: content),
                ]
              : [
                  Expanded(child: content),
                  SizedBox(width: spacing.md),
                  switchWidget,
                ],
        ),
      ),
    );
  }
}

/// 적응형 슬라이더
class AdaptiveSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final bool showValue;
  final bool enabled;
  final String Function(double)? valueFormatter;

  const AdaptiveSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.showValue = false,
    this.enabled = true,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    String formatValue(double value) {
      if (valueFormatter != null) {
        return valueFormatter!(value);
      }
      return value.toStringAsFixed(divisions != null ? 0 : 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showValue)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: typography.labelMedium.copyWith(
                      color: enabled ? colors.textSecondary : colors.textDisabled,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (showValue)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.gray100,
                      borderRadius: BorderRadius.circular(
                        isBoldMinimalism ? 0 : spacing.radiusSm,
                      ),
                    ),
                    child: Text(
                      formatValue(value),
                      style: typography.labelSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.gray200,
            thumbColor: colors.primary,
            overlayColor: colors.primary.withValues(alpha: 0.1),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: isBoldMinimalism ? 8 : 10,
            ),
            trackShape: RoundedRectSliderTrackShape(),
            trackHeight: isBoldMinimalism ? 4 : 3,
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
            min: min,
            max: max,
            divisions: divisions,
            label: showValue ? formatValue(value) : null,
          ),
        ),
      ],
    );
  }
}

enum CheckboxPosition { leading, trailing }

enum SwitchPosition { leading, trailing }
