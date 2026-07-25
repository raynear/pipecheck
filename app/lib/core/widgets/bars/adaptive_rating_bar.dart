import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 평점 바 (6:3:1 비율 준수)
/// 배경(60%) - 채워진 별(30%) - 테두리(10%)
class AdaptiveRatingBar extends StatefulWidget {
  final double rating;
  final ValueChanged<double>? onRatingUpdate;
  final int itemCount;
  final double itemSize;
  final Color? color;
  final Color? borderColor;
  final Color? emptyColor;
  final IconData? filledIcon;
  final IconData? halfFilledIcon;
  final IconData? emptyIcon;
  final bool allowHalfRating;
  final bool readOnly;
  final double itemPadding;
  final RatingBarStyle style;

  const AdaptiveRatingBar({
    super.key,
    required this.rating,
    this.onRatingUpdate,
    this.itemCount = 5,
    this.itemSize = 40,
    this.color,
    this.borderColor,
    this.emptyColor,
    this.filledIcon,
    this.halfFilledIcon,
    this.emptyIcon,
    this.allowHalfRating = false,
    this.readOnly = false,
    this.itemPadding = 4,
    this.style = RatingBarStyle.star,
  });

  const AdaptiveRatingBar.readOnly({
    super.key,
    required this.rating,
    this.itemCount = 5,
    this.itemSize = 20,
    this.color,
    this.borderColor,
    this.emptyColor,
    this.filledIcon,
    this.halfFilledIcon,
    this.emptyIcon,
    this.allowHalfRating = true,
    this.itemPadding = 2,
    this.style = RatingBarStyle.star,
  })  : onRatingUpdate = null,
        readOnly = true;

  @override
  State<AdaptiveRatingBar> createState() => _AdaptiveRatingBarState();
}

class _AdaptiveRatingBarState extends State<AdaptiveRatingBar> {
  double _currentRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
  }

  @override
  void didUpdateWidget(AdaptiveRatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      setState(() {
        _currentRating = widget.rating;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;

    // Icon configurations based on style
    IconData filledIcon;
    IconData halfFilledIcon;
    IconData emptyIcon;

    switch (widget.style) {
      case RatingBarStyle.star:
        filledIcon = widget.filledIcon ?? Icons.star;
        halfFilledIcon = widget.halfFilledIcon ?? Icons.star_half;
        emptyIcon = widget.emptyIcon ?? Icons.star_border;
        break;
      case RatingBarStyle.heart:
        filledIcon = widget.filledIcon ?? Icons.favorite;
        halfFilledIcon = widget.halfFilledIcon ?? Icons.favorite;
        emptyIcon = widget.emptyIcon ?? Icons.favorite_border;
        break;
      case RatingBarStyle.circle:
        filledIcon = widget.filledIcon ?? Icons.circle;
        halfFilledIcon = widget.halfFilledIcon ?? Icons.circle;
        emptyIcon = widget.emptyIcon ?? Icons.circle_outlined;
        break;
      case RatingBarStyle.square:
        filledIcon = widget.filledIcon ?? Icons.square;
        halfFilledIcon = widget.halfFilledIcon ?? Icons.square;
        emptyIcon = widget.emptyIcon ?? Icons.square_outlined;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.itemCount, (index) {
        final double itemValue = index + 1;
        final bool isFilled = _currentRating >= itemValue;
        final bool isHalfFilled = _currentRating > index && _currentRating < itemValue;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.itemPadding / 2),
          child: GestureDetector(
            onTap: widget.readOnly
                ? null
                : () {
                    setState(() {
                      _currentRating = itemValue;
                    });
                    widget.onRatingUpdate?.call(_currentRating);
                  },
            onHorizontalDragUpdate: widget.readOnly || !widget.allowHalfRating
                ? null
                : (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final pos = box.globalToLocal(details.globalPosition);
                    final i = pos.dx / (widget.itemSize + widget.itemPadding);
                    final newRating = widget.allowHalfRating ? (i * 2).round() / 2 : i.round().toDouble();
                    if (newRating > 0 && newRating <= widget.itemCount) {
                      setState(() {
                        _currentRating = newRating;
                      });
                      widget.onRatingUpdate?.call(_currentRating);
                    }
                  },
            child: _buildRatingItem(
              isFilled: isFilled,
              isHalfFilled: isHalfFilled,
              filledIcon: filledIcon,
              halfFilledIcon: halfFilledIcon,
              emptyIcon: emptyIcon,
              colors: colors,
              isBoldMinimalism: isBoldMinimalism,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRatingItem({
    required bool isFilled,
    required bool isHalfFilled,
    required IconData filledIcon,
    required IconData halfFilledIcon,
    required IconData emptyIcon,
    required DesignColors colors,
    required bool isBoldMinimalism,
  }) {
    final color = widget.color ?? colors.warning;
    // final borderColor = widget.borderColor ?? (isBoldMinimalism ? colors.black : color);
    final emptyColor = widget.emptyColor ?? colors.gray300;

    if (isHalfFilled && widget.allowHalfRating) {
      return Stack(
        children: [
          Icon(
            emptyIcon,
            size: widget.itemSize,
            color: emptyColor,
          ),
          ClipRect(
            clipper: _HalfClipper(),
            child: Icon(
              halfFilledIcon,
              size: widget.itemSize,
              color: color,
            ),
          ),
        ],
      );
    }

    return Icon(
      isFilled ? filledIcon : emptyIcon,
      size: widget.itemSize,
      color: isFilled ? color : emptyColor,
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}

/// 평점 표시기
class AdaptiveRatingIndicator extends StatelessWidget {
  final double rating;
  final int maxRating;
  final double size;
  final Color? color;
  final Color? emptyColor;
  final bool showValue;
  final RatingBarStyle style;

  const AdaptiveRatingIndicator({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 16,
    this.color,
    this.emptyColor,
    this.showValue = true,
    this.style = RatingBarStyle.star,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final spacing = context.spacing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdaptiveRatingBar.readOnly(
          rating: rating,
          itemCount: maxRating,
          itemSize: size,
          color: color,
          emptyColor: emptyColor,
          style: style,
        ),
        if (showValue) ...[
          SizedBox(width: spacing.xs),
          Text(
            rating.toStringAsFixed(1),
            style: typography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// 적응형 스텝 바
class AdaptiveStepBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;
  final StepBarStyle style;
  final StepLabelPosition labelPosition;

  const AdaptiveStepBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
    this.activeColor,
    this.inactiveColor,
    this.style = StepBarStyle.linear,
    this.labelPosition = StepLabelPosition.below,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    // final spacing = context.spacing;
    // final typography = context.typography;

    final activeStepColor = activeColor ?? colors.primary;
    final inactiveStepColor = inactiveColor ?? colors.gray300;

    switch (style) {
      case StepBarStyle.linear:
        return _buildLinearSteps(
          context,
          activeStepColor,
          inactiveStepColor,
          isBoldMinimalism,
        );
      case StepBarStyle.circular:
        return _buildCircularSteps(
          context,
          activeStepColor,
          inactiveStepColor,
          isBoldMinimalism,
        );
    }
  }

  Widget _buildLinearSteps(
    BuildContext context,
    Color activeColor,
    Color inactiveColor,
    bool isBoldMinimalism,
  ) {
    // final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stepLabels != null && labelPosition == StepLabelPosition.above) _buildLabels(context),
        Row(
          children: List.generate(totalSteps * 2 - 1, (index) {
            if (index.isOdd) {
              // Connector
              final stepIndex = index ~/ 2;
              final isActive = stepIndex < currentStep;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isActive ? activeColor : inactiveColor,
                ),
              );
            } else {
              // Step
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= currentStep;
              // final isCurrent = stepIndex == currentStep;

              return Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  border: Border.all(
                    color: isActive ? activeColor : inactiveColor,
                    width: isBoldMinimalism ? 2 : 1,
                  ),
                  shape: isBoldMinimalism ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${stepIndex + 1}',
                    style: typography.labelSmall.copyWith(
                      color: isActive ? Colors.white : inactiveColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
          }),
        ),
        if (stepLabels != null && labelPosition == StepLabelPosition.below) _buildLabels(context),
      ],
    );
  }

  Widget _buildCircularSteps(
    BuildContext context,
    Color activeColor,
    Color inactiveColor,
    bool isBoldMinimalism,
  ) {
    final spacing = context.spacing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isCurrent = index == currentStep;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Container(
            width: isCurrent ? 12 : 8,
            height: isCurrent ? 12 : 8,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              shape: isBoldMinimalism ? BoxShape.rectangle : BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLabels(BuildContext context) {
    final typography = context.typography;
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: stepLabels!
            .map((label) => Expanded(
                  child: Text(
                    label,
                    style: typography.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

enum RatingBarStyle { star, heart, circle, square }

enum StepBarStyle { linear, circular }

enum StepLabelPosition { above, below }
