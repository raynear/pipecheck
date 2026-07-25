import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 배지 (6:3:1 비율 준수)
/// 배경(60%) - 콘텐츠(30%) - 장식(10%)
class AdaptiveBadge extends StatelessWidget {
  final Widget child;
  final String? label;
  final int? count;
  final BadgePosition position;
  final BadgeSize size;
  final BadgeVariant variant;
  final Color? customColor;
  final bool showBadge;
  final bool animate;

  const AdaptiveBadge({
    super.key,
    required this.child,
    this.label,
    this.count,
    this.position = BadgePosition.topRight,
    this.size = BadgeSize.medium,
    this.variant = BadgeVariant.standard,
    this.customColor,
    this.showBadge = true,
    this.animate = true,
  }) : assert(label != null || count != null, 'Either label or count must be provided');

  @override
  Widget build(BuildContext context) {
    if (!showBadge || (label == null && count == null)) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        _buildBadge(context),
      ],
    );
  }

  Widget _buildBadge(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Badge content
    String badgeText;
    if (label != null) {
      badgeText = label!;
    } else if (count != null) {
      badgeText = count! > 99 ? '99+' : count.toString();
    } else {
      badgeText = '';
    }

    // Size configurations
    double minSize;
    EdgeInsets padding;
    TextStyle textStyle;

    switch (size) {
      case BadgeSize.small:
        minSize = 16;
        padding = EdgeInsets.symmetric(horizontal: spacing.xs);
        textStyle = typography.labelSmall.copyWith(fontSize: 10);
        break;
      case BadgeSize.medium:
        minSize = 20;
        padding = EdgeInsets.symmetric(horizontal: spacing.xs);
        textStyle = typography.labelSmall;
        break;
      case BadgeSize.large:
        minSize = 24;
        padding = EdgeInsets.symmetric(horizontal: spacing.sm);
        textStyle = typography.labelMedium;
        break;
    }

    // Variant configurations
    Color backgroundColor;
    Color textColor;
    Border? border;

    if (customColor != null) {
      backgroundColor = customColor!;
      textColor = colors.white;
      border = null;
    } else {
      switch (variant) {
        case BadgeVariant.standard:
          backgroundColor = colors.error;
          textColor = colors.white;
          border = null;
          break;
        case BadgeVariant.primary:
          backgroundColor = colors.primary;
          textColor = colors.textOnPrimary;
          border = null;
          break;
        case BadgeVariant.secondary:
          backgroundColor = colors.gray700;
          textColor = colors.white;
          border = null;
          break;
        case BadgeVariant.outlined:
          backgroundColor = colors.backgroundPrimary;
          textColor = colors.error;
          border = Border.all(
            color: colors.error,
            width: isBoldMinimalism ? 2 : 1,
          );
          break;
      }
    }

    // Position configurations
    double? top, right, bottom, left;
    switch (position) {
      case BadgePosition.topRight:
        top = -4;
        right = -4;
        break;
      case BadgePosition.topLeft:
        top = -4;
        left = -4;
        break;
      case BadgePosition.bottomRight:
        bottom = -4;
        right = -4;
        break;
      case BadgePosition.bottomLeft:
        bottom = -4;
        left = -4;
        break;
    }

    Widget badge = Container(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? (count != null && count! <= 9 ? 0 : spacing.radiusSm) : 9999,
        ),
        border: border,
      ),
      child: Center(
        child: Text(
          badgeText,
          style: textStyle.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (animate) {
      badge = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: badge,
      );
    }

    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: badge,
    );
  }
}

/// 도트 배지
class AdaptiveDotBadge extends StatelessWidget {
  final Widget child;
  final BadgePosition position;
  final DotSize size;
  final Color? color;
  final bool showDot;
  final bool animate;
  final bool pulse;

  const AdaptiveDotBadge({
    super.key,
    required this.child,
    this.position = BadgePosition.topRight,
    this.size = DotSize.medium,
    this.color,
    this.showDot = true,
    this.animate = true,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDot) return child;

    final colors = context.colors;

    // Position configurations
    double? top, right, bottom, left;
    switch (position) {
      case BadgePosition.topRight:
        top = 0;
        right = 0;
        break;
      case BadgePosition.topLeft:
        top = 0;
        left = 0;
        break;
      case BadgePosition.bottomRight:
        bottom = 0;
        right = 0;
        break;
      case BadgePosition.bottomLeft:
        bottom = 0;
        left = 0;
        break;
    }

    // Size configurations
    double dotSize;
    switch (size) {
      case DotSize.small:
        dotSize = 6;
        break;
      case DotSize.medium:
        dotSize = 8;
        break;
      case DotSize.large:
        dotSize = 12;
        break;
    }

    Widget dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color ?? colors.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.backgroundPrimary,
          width: 2,
        ),
      ),
    );

    if (pulse) {
      dot = _PulsingDot(
        size: dotSize,
        color: color ?? colors.error,
        borderColor: colors.backgroundPrimary,
      );
    }

    if (animate) {
      dot = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: dot,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          right: right,
          bottom: bottom,
          left: left,
          child: dot,
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final double size;
  final Color color;
  final Color borderColor;

  const _PulsingDot({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _opacityAnimation.value * 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.borderColor,
              width: 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// 아이콘 배지
class AdaptiveIconBadge extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final BadgePosition position;
  final BadgeSize size;
  final Color? iconColor;
  final double? iconSize;

  const AdaptiveIconBadge({
    super.key,
    required this.icon,
    this.badge,
    this.position = BadgePosition.topRight,
    this.size = BadgeSize.small,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    final iconWidget = Icon(
      icon,
      color: iconColor ?? colors.textPrimary,
      size: iconSize ?? spacing.iconMd,
    );

    if (badge == null) return iconWidget;

    return AdaptiveBadge(
      label: badge,
      position: position,
      size: size,
      child: iconWidget,
    );
  }
}

enum BadgePosition { topRight, topLeft, bottomRight, bottomLeft }

enum BadgeSize { small, medium, large }

enum BadgeVariant { standard, primary, secondary, outlined }

enum DotSize { small, medium, large }
