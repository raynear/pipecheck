import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 원형 프로그레스 인디케이터
class AdaptiveCircularProgress extends StatelessWidget {
  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final String? label;
  final ProgressVariant variant;

  const AdaptiveCircularProgress({
    super.key,
    this.value,
    this.size = 48,
    this.strokeWidth = 4,
    this.color,
    this.backgroundColor,
    this.label,
    this.variant = ProgressVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    switch (variant) {
      case ProgressVariant.standard:
        return _buildStandardProgress(context, isBoldMinimalism);
      case ProgressVariant.withLabel:
        return _buildLabeledProgress(context, isBoldMinimalism);
      case ProgressVariant.button:
        return _buildButtonProgress(context, isBoldMinimalism);
    }
  }

  Widget _buildStandardProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: isBoldMinimalism ? strokeWidth * 1.5 : strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? colors.primary,
        ),
        backgroundColor: backgroundColor ?? colors.gray200,
      ),
    );
  }

  Widget _buildLabeledProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStandardProgress(context, isBoldMinimalism),
        if (label != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            label!,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildButtonProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? colors.textOnPrimary,
        ),
      ),
    );
  }
}

/// 적응형 선형 프로그레스 인디케이터
class AdaptiveLinearProgress extends StatelessWidget {
  final double? value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final String? label;
  final bool showPercentage;
  final LinearProgressVariant variant;

  const AdaptiveLinearProgress({
    super.key,
    this.value,
    this.height = 4,
    this.color,
    this.backgroundColor,
    this.label,
    this.showPercentage = false,
    this.variant = LinearProgressVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    switch (variant) {
      case LinearProgressVariant.standard:
        return _buildStandardProgress(context, isBoldMinimalism);
      case LinearProgressVariant.withLabel:
        return _buildLabeledProgress(context, isBoldMinimalism);
      case LinearProgressVariant.segmented:
        return _buildSegmentedProgress(context, isBoldMinimalism);
    }
  }

  Widget _buildStandardProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        isBoldMinimalism ? 0 : height / 2,
      ),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? colors.primary,
        ),
        backgroundColor: backgroundColor ?? colors.gray200,
      ),
    );
  }

  Widget _buildLabeledProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final percentage = value != null ? (value! * 100).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: typography.labelMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              if (showPercentage && value != null)
                Text(
                  '$percentage%',
                  style: typography.labelMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        if (label != null || showPercentage) SizedBox(height: spacing.xs),
        _buildStandardProgress(context, isBoldMinimalism),
      ],
    );
  }

  Widget _buildSegmentedProgress(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;

    const segmentCount = 5;
    final activeSegments = value != null ? (value! * segmentCount).floor() : 0;

    return Row(
      children: List.generate(segmentCount, (index) {
        final isActive = index < activeSegments;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(
              right: index < segmentCount - 1 ? spacing.xs : 0,
            ),
            decoration: BoxDecoration(
              color: isActive ? colors.primary : colors.gray200,
              borderRadius: BorderRadius.circular(
                isBoldMinimalism ? 0 : height / 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 적응형 로딩 오버레이
class AdaptiveLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? overlayColor;
  final double opacity;

  const AdaptiveLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.overlayColor,
    this.opacity = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: (overlayColor ?? colors.black).withValues(alpha: opacity),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AdaptiveCircularProgress(),
                    if (message != null) ...[
                      SizedBox(height: spacing.md),
                      Text(
                        message!,
                        style: typography.bodyMedium.copyWith(
                          color: colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 스켈레톤 로더
class AdaptiveSkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final SkeletonType type;

  const AdaptiveSkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.type = SkeletonType.rectangle,
  });

  const AdaptiveSkeletonLoader.circle({
    super.key,
    double? size,
  })  : width = size,
        height = size,
        borderRadius = null,
        type = SkeletonType.circle;

  const AdaptiveSkeletonLoader.text({
    super.key,
    this.width,
    this.height = 16,
  })  : borderRadius = null,
        type = SkeletonType.text;

  @override
  State<AdaptiveSkeletonLoader> createState() => _AdaptiveSkeletonLoaderState();
}

class _AdaptiveSkeletonLoaderState extends State<AdaptiveSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    BorderRadius radius;
    switch (widget.type) {
      case SkeletonType.rectangle:
        radius = widget.borderRadius ??
            BorderRadius.circular(
              isBoldMinimalism ? 0 : spacing.radiusSm,
            );
        break;
      case SkeletonType.circle:
        radius = BorderRadius.circular(9999);
        break;
      case SkeletonType.text:
        radius = BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusXs,
        );
        break;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.gray200.withValues(alpha: _animation.value),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}

enum ProgressVariant { standard, withLabel, button }

enum LinearProgressVariant { standard, withLabel, segmented }

enum SkeletonType { rectangle, circle, text }
