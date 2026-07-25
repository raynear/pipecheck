import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 디자인 시스템에 따라 자동으로 스타일이 변경되는 버튼
/// 6:3:1 비율 준수: 배경(60%) - 텍스트(30%) - 포인트(10%)
class AdaptiveButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final ButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? child;

  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = ButtonSize.medium,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.child,
  });

  @override
  State<AdaptiveButton> createState() => _AdaptiveButtonState();
}

class _AdaptiveButtonState extends State<AdaptiveButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isLoading || widget.onPressed == null ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildButton(context, isBoldMinimalism),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool isBoldMinimalism) {
    final colors = _getColors(context);
    final dimensions = _getDimensions(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.isFullWidth ? double.infinity : null,
      height: dimensions.height,
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        border: widget.variant == ButtonVariant.outlined
            ? Border.all(
                color: colors.borderColor,
                width: isBoldMinimalism ? 2 : 1,
              )
            : null,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : context.spacing.radiusMd,
        ),
        boxShadow: widget.variant == ButtonVariant.primary &&
                widget.onPressed != null &&
                !widget.isLoading &&
                !isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading || widget.onPressed == null ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : context.spacing.radiusMd,
          ),
          splashColor: colors.splashColor,
          highlightColor: colors.highlightColor,
          child: Padding(
            padding: dimensions.padding,
            child: widget.isLoading ? _buildLoadingState(context, colors) : _buildContent(context, colors, dimensions),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, _ButtonColors colors) {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colors.foregroundColor),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _ButtonColors colors, _ButtonDimensions dimensions) {
    if (widget.child != null) {
      return widget.child!;
    }

    final content = <Widget>[];

    if (widget.icon != null) {
      content.add(Icon(
        widget.icon,
        size: dimensions.iconSize,
        color: colors.foregroundColor,
      ));
      if (widget.label.isNotEmpty) {
        content.add(SizedBox(width: context.spacing.sm));
      }
    }

    if (widget.label.isNotEmpty) {
      content.add(Text(
        widget.label,
        style: dimensions.textStyle.copyWith(
          color: colors.foregroundColor,
        ),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: content,
    );
  }

  _ButtonColors _getColors(BuildContext context) {
    final colors = context.colors;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    switch (widget.variant) {
      case ButtonVariant.primary:
        return _ButtonColors(
          backgroundColor: isDisabled ? colors.buttonDisabled : colors.primary,
          foregroundColor: isDisabled ? colors.textDisabled : colors.textOnPrimary,
          borderColor: Colors.transparent,
          shadowColor: colors.primary.withValues(alpha: 0.3),
          splashColor: colors.white.withValues(alpha: 0.1),
          highlightColor: colors.white.withValues(alpha: 0.05),
        );

      case ButtonVariant.secondary:
        return _ButtonColors(
          backgroundColor: isDisabled ? colors.gray100 : colors.secondary,
          foregroundColor: isDisabled ? colors.textDisabled : colors.textOnSecondary,
          borderColor: Colors.transparent,
          shadowColor: colors.secondary.withValues(alpha: 0.3),
          splashColor: colors.white.withValues(alpha: 0.1),
          highlightColor: colors.white.withValues(alpha: 0.05),
        );

      case ButtonVariant.outlined:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          foregroundColor: isDisabled ? colors.textDisabled : colors.primary,
          borderColor: isDisabled ? colors.borderLight : colors.primary,
          shadowColor: Colors.transparent,
          splashColor: colors.primary.withValues(alpha: 0.1),
          highlightColor: colors.primary.withValues(alpha: 0.05),
        );

      case ButtonVariant.text:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          foregroundColor: isDisabled ? colors.textDisabled : colors.primary,
          borderColor: Colors.transparent,
          shadowColor: Colors.transparent,
          splashColor: colors.primary.withValues(alpha: 0.1),
          highlightColor: colors.primary.withValues(alpha: 0.05),
        );

      case ButtonVariant.ghost:
        return _ButtonColors(
          backgroundColor: _isPressed ? colors.gray100 : Colors.transparent,
          foregroundColor: isDisabled ? colors.textDisabled : colors.textPrimary,
          borderColor: Colors.transparent,
          shadowColor: Colors.transparent,
          splashColor: colors.gray200,
          highlightColor: colors.gray100,
        );
    }
  }

  _ButtonDimensions _getDimensions(BuildContext context) {
    final typography = context.typography;
    final spacing = context.spacing;

    switch (widget.size) {
      case ButtonSize.small:
        return _ButtonDimensions(
          height: 32,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.xs,
          ),
          textStyle: typography.labelSmall,
          iconSize: spacing.iconSm,
        );

      case ButtonSize.medium:
        return _ButtonDimensions(
          height: 40,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          textStyle: typography.labelMedium,
          iconSize: spacing.iconMd,
        );

      case ButtonSize.large:
        return _ButtonDimensions(
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xl,
            vertical: spacing.md,
          ),
          textStyle: typography.labelLarge,
          iconSize: spacing.iconMd,
        );
    }
  }
}

enum ButtonSize { small, medium, large }

enum ButtonVariant { primary, secondary, outlined, text, ghost }

class _ButtonColors {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Color splashColor;
  final Color highlightColor;

  const _ButtonColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.splashColor,
    required this.highlightColor,
  });
}

class _ButtonDimensions {
  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final double iconSize;

  const _ButtonDimensions({
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.iconSize,
  });
}
