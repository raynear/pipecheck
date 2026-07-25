import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 확장 가능한 FAB (6:3:1 비율 준수)
class AdaptiveFAB extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool mini;
  final bool extended;
  final FABPosition position;

  const AdaptiveFAB({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.mini = false,
    this.extended = false,
    this.position = FABPosition.bottomRight,
  });

  @override
  State<AdaptiveFAB> createState() => _AdaptiveFABState();
}

class _AdaptiveFABState extends State<AdaptiveFAB> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    return Positioned(
      bottom: _getBottom(),
      right: _getRight(),
      left: _getLeft(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.extended && widget.label != null
            ? _buildExtendedFAB(context, isBoldMinimalism)
            : _buildNormalFAB(context, isBoldMinimalism),
      ),
    );
  }

  Widget _buildNormalFAB(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final size = widget.mini ? 40.0 : 56.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondary, // 포인트 컬러 (10%)
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : size / 2,
        ),
        boxShadow: isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.3),
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : size / 2,
          ),
          child: Icon(
            widget.icon,
            color: colors.textOnSecondary,
            size: widget.mini ? 20 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildExtendedFAB(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      height: widget.mini ? 40.0 : 48.0,
      decoration: BoxDecoration(
        color: colors.secondary, // 포인트 컬러 (10%)
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : 24,
        ),
        boxShadow: isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.3),
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : 24,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: colors.textOnSecondary,
                  size: widget.mini ? 20 : 24,
                ),
                if (widget.label != null) ...[
                  SizedBox(width: spacing.sm),
                  Text(
                    widget.label!,
                    style: typography.labelMedium.copyWith(
                      color: colors.textOnSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _getBottom() {
    switch (widget.position) {
      case FABPosition.bottomRight:
      case FABPosition.bottomLeft:
      case FABPosition.bottomCenter:
        return 16;
      default:
        return null;
    }
  }

  double? _getRight() {
    switch (widget.position) {
      case FABPosition.bottomRight:
      case FABPosition.topRight:
        return 16;
      default:
        return null;
    }
  }

  double? _getLeft() {
    switch (widget.position) {
      case FABPosition.bottomLeft:
      case FABPosition.topLeft:
        return 16;
      case FABPosition.bottomCenter:
      case FABPosition.topCenter:
        return null;
      default:
        return null;
    }
  }
}

/// 다중 FAB 메뉴
class SpeedDial extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final List<SpeedDialChild> children;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDial({
    super.key,
    required this.icon,
    required this.children,
    this.activeIcon,
    this.onOpen,
    this.onClose,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
        widget.onOpen?.call();
      } else {
        _controller.reverse();
        widget.onClose?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    return SizedBox(
      width: 56,
      height: 56.0 + (widget.children.length * 56.0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 오버레이
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          // 하위 버튼들
          ...widget.children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;

            return AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) => Positioned(
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -_expandAnimation.value * (index + 1) * 64,
                  ),
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    child: child,
                  ),
                ),
              ),
              child: _buildChildButton(context, child, isBoldMinimalism),
            );
          }),
          // 메인 버튼
          Positioned(
            bottom: 0,
            child: _buildMainButton(context, isBoldMinimalism),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colors.secondary,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : 28,
        ),
        boxShadow: isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.3),
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : 28,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isOpen ? (widget.activeIcon ?? Icons.close) : widget.icon,
              key: ValueKey(_isOpen),
              color: widget.foregroundColor ?? colors.textOnSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildButton(BuildContext context, SpeedDialChild child, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (child.label != null)
          Container(
            margin: EdgeInsets.only(right: spacing.sm),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.backgroundElevated,
              borderRadius: BorderRadius.circular(
                isBoldMinimalism ? 0 : spacing.radiusSm,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              child.label!,
              style: typography.labelSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: child.backgroundColor ?? colors.primary,
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : 20,
            ),
            boxShadow: isBoldMinimalism
                ? [
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.2),
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colors.shadow,
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _toggle();
                child.onTap?.call();
              },
              borderRadius: BorderRadius.circular(
                isBoldMinimalism ? 0 : 20,
              ),
              child: Icon(
                child.icon,
                size: 20,
                color: child.foregroundColor ?? colors.textOnPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SpeedDialChild {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDialChild({
    required this.icon,
    this.label,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });
}

enum FABPosition {
  bottomRight,
  bottomLeft,
  bottomCenter,
  topRight,
  topLeft,
  topCenter,
}
