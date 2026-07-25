import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 슬라이더 (6:3:1 비율 준수)
/// 트랙(60%) - 활성 트랙(30%) - 썸(10%)
class AdaptiveSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;
  final SliderSize size;
  final bool showLabel;
  final bool showValue;

  const AdaptiveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.size = SliderSize.medium,
    this.showLabel = false,
    this.showValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    double trackHeight;
    double thumbRadius;
    TextStyle valueStyle;

    switch (size) {
      case SliderSize.small:
        trackHeight = 2;
        thumbRadius = 10;
        valueStyle = typography.labelSmall;
        break;
      case SliderSize.medium:
        trackHeight = 4;
        thumbRadius = 12;
        valueStyle = typography.labelMedium;
        break;
      case SliderSize.large:
        trackHeight = 6;
        thumbRadius = 14;
        valueStyle = typography.labelLarge;
        break;
    }

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: activeColor ?? colors.primary,
        inactiveTrackColor: inactiveColor ?? colors.gray200,
        thumbColor: activeColor ?? colors.primary,
        overlayColor: (activeColor ?? colors.primary).withValues(alpha: 0.2),
        thumbShape: isBoldMinimalism
            ? _SquareSliderThumbShape(size: thumbRadius * 2)
            : RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
        trackHeight: trackHeight,
        trackShape: isBoldMinimalism ? _SquareSliderTrackShape() : const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        min: min,
        max: max,
        divisions: divisions,
        label: showLabel ? label ?? value.toStringAsFixed(1) : null,
      ),
    );

    if (showValue) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Text(
                label!,
                style: typography.labelMedium,
              ),
            ),
          Row(
            children: [
              Expanded(child: slider),
              SizedBox(width: spacing.sm),
              Container(
                constraints: const BoxConstraints(minWidth: 48),
                child: Text(
                  value.toStringAsFixed(divisions != null ? 0 : 1),
                  style: valueStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return slider;
  }
}

/// 범위 슬라이더
class AdaptiveRangeSlider extends StatelessWidget {
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final ValueChanged<RangeValues>? onChangeStart;
  final ValueChanged<RangeValues>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final RangeLabels? labels;
  final Color? activeColor;
  final Color? inactiveColor;
  final SliderSize size;
  final bool showLabels;
  final bool showValues;

  const AdaptiveRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.labels,
    this.activeColor,
    this.inactiveColor,
    this.size = SliderSize.medium,
    this.showLabels = false,
    this.showValues = false,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final typography = context.typography;

    // Size configurations
    double trackHeight;
    double thumbRadius;
    TextStyle valueStyle;

    switch (size) {
      case SliderSize.small:
        trackHeight = 2;
        thumbRadius = 10;
        valueStyle = typography.labelSmall;
        break;
      case SliderSize.medium:
        trackHeight = 4;
        thumbRadius = 12;
        valueStyle = typography.labelMedium;
        break;
      case SliderSize.large:
        trackHeight = 6;
        thumbRadius = 14;
        valueStyle = typography.labelLarge;
        break;
    }

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: activeColor ?? colors.primary,
        inactiveTrackColor: inactiveColor ?? colors.gray200,
        thumbColor: activeColor ?? colors.primary,
        overlayColor: (activeColor ?? colors.primary).withValues(alpha: 0.2),
        rangeThumbShape: isBoldMinimalism
            ? _SquareRangeSliderThumbShape(size: thumbRadius * 2)
            : RoundRangeSliderThumbShape(enabledThumbRadius: thumbRadius),
        trackHeight: trackHeight,
        rangeTrackShape: isBoldMinimalism ? _SquareRangeSliderTrackShape() : const RoundedRectRangeSliderTrackShape(),
      ),
      child: RangeSlider(
        values: values,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        min: min,
        max: max,
        divisions: divisions,
        labels: showLabels
            ? labels ??
                RangeLabels(
                  values.start.toStringAsFixed(1),
                  values.end.toStringAsFixed(1),
                )
            : null,
      ),
    );

    if (showValues) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                values.start.toStringAsFixed(divisions != null ? 0 : 1),
                style: valueStyle,
              ),
              Expanded(child: slider),
              Text(
                values.end.toStringAsFixed(divisions != null ? 0 : 1),
                style: valueStyle,
              ),
            ],
          ),
        ],
      );
    }

    return slider;
  }
}

// Custom thumb shapes for Bold Minimalism
class _SquareSliderThumbShape extends SliderComponentShape {
  final double size;

  const _SquareSliderThumbShape({required this.size});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(size, size);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: size, height: size);

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }
}

class _SquareRangeSliderThumbShape extends RangeSliderThumbShape {
  final double size;

  const _SquareRangeSliderThumbShape({required this.size});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(size, size);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool isOnTop = false,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final Canvas canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: size, height: size);

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }
}

class _SquareSliderTrackShape extends SliderTrackShape {
  const _SquareSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blue;

    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey;

    final double thumbCenterDx = thumbCenter.dx;

    // Active track
    canvas.drawRect(
      Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        thumbCenterDx,
        trackRect.bottom,
      ),
      activePaint,
    );

    // Inactive track
    canvas.drawRect(
      Rect.fromLTRB(
        thumbCenterDx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      ),
      inactivePaint,
    );
  }
}

class _SquareRangeSliderTrackShape extends RangeSliderTrackShape {
  const _SquareRangeSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    required TextDirection textDirection,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blue;

    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.grey;

    // Left inactive track
    canvas.drawRect(
      Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        startThumbCenter.dx,
        trackRect.bottom,
      ),
      inactivePaint,
    );

    // Active track
    canvas.drawRect(
      Rect.fromLTRB(
        startThumbCenter.dx,
        trackRect.top,
        endThumbCenter.dx,
        trackRect.bottom,
      ),
      activePaint,
    );

    // Right inactive track
    canvas.drawRect(
      Rect.fromLTRB(
        endThumbCenter.dx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      ),
      inactivePaint,
    );
  }
}

enum SliderSize { small, medium, large }
