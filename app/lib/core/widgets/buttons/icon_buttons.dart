import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 아이콘 버튼
class AdaptiveIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double? size;
  final Color? color;
  final String? tooltip;
  final bool selected;
  final IconButtonVariant variant;
  final bool showBadge;
  final String? badgeText;

  const AdaptiveIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size,
    this.color,
    this.tooltip,
    this.selected = false,
    this.variant = IconButtonVariant.standard,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  State<AdaptiveIconButton> createState() => _AdaptiveIconButtonState();
}

class _AdaptiveIconButtonState extends State<AdaptiveIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
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

    final effectiveSize = widget.size ?? spacing.iconMd;
    final effectiveColor = widget.color ?? (widget.selected ? colors.primary : colors.textPrimary);

    Widget button = GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildButton(context, isBoldMinimalism, effectiveSize, effectiveColor),
        ),
      ),
    );

    if (widget.showBadge) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (widget.badgeText != null)
            Positioned(
              top: -4,
              right: -4,
              child: _buildBadge(context, isBoldMinimalism),
            ),
        ],
      );
    }

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }

  Widget _buildButton(
    BuildContext context,
    bool isBoldMinimalism,
    double size,
    Color color,
  ) {
    final colors = context.colors;

    switch (widget.variant) {
      case IconButtonVariant.standard:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : size / 2,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(widget.icon, size: size, color: color),
            ),
          ),
        );

      case IconButtonVariant.filled:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.selected ? colors.primary : colors.gray100,
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : size / 2 + 8,
            ),
          ),
          child: Icon(
            widget.icon,
            size: size,
            color: widget.selected ? colors.textOnPrimary : color,
          ),
        );

      case IconButtonVariant.outlined:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.selected ? colors.primary : colors.border,
              width: isBoldMinimalism ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : size / 2 + 8,
            ),
          ),
          child: Icon(widget.icon, size: size, color: color),
        );
    }
  }

  Widget _buildBadge(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : 8,
        ),
      ),
      child: Center(
        child: Text(
          widget.badgeText!,
          style: typography.labelSmall.copyWith(
            color: colors.textOnError,
            fontSize: 10,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 토글 버튼 그룹 (아이콘/라벨 기반)
class AdaptiveIconToggleButtons extends StatelessWidget {
  final List<ToggleItem> items;
  final List<bool> isSelected;
  final Function(int)? onPressed;
  final bool allowMultipleSelection;
  final IconToggleButtonsVariant variant;
  final IconToggleButtonsSize size;

  const AdaptiveIconToggleButtons({
    super.key,
    required this.items,
    required this.isSelected,
    this.onPressed,
    this.allowMultipleSelection = false,
    this.variant = IconToggleButtonsVariant.outlined,
    this.size = IconToggleButtonsSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      decoration: BoxDecoration(
        color: variant == IconToggleButtonsVariant.filled
            ? colors.gray100
            : variant == IconToggleButtonsVariant.tonal
                ? colors.primaryLight.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusMd,
        ),
        border: variant == IconToggleButtonsVariant.outlined
            ? Border.all(
                color: colors.border,
                width: isBoldMinimalism ? 2 : 1,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final isFirst = index == 0;
          final isLast = index == items.length - 1;
          final item = items[index];
          final selected = isSelected[index];

          return _buildToggleButton(
            context,
            item,
            selected,
            isFirst,
            isLast,
            isBoldMinimalism,
            () => _handlePress(index),
          );
        }),
      ),
    );
  }

  void _handlePress(int index) {
    if (onPressed == null) return;

    if (allowMultipleSelection) {
      onPressed!(index);
    } else {
      // 단일 선택인 경우
      for (int i = 0; i < isSelected.length; i++) {
        if (i == index && !isSelected[i]) {
          onPressed!(i);
        }
      }
    }
  }

  Widget _buildToggleButton(
    BuildContext context,
    ToggleItem item,
    bool selected,
    bool isFirst,
    bool isLast,
    bool isBoldMinimalism,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Material(
      color: selected
          ? colors.primary
          : variant == IconToggleButtonsVariant.tonal
              ? colors.primaryLight
              : Colors.transparent,
      borderRadius: BorderRadius.only(
        topLeft: isFirst && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
        bottomLeft: isFirst && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
        topRight: isLast && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
        bottomRight: isLast && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
          topLeft: isFirst && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
          bottomLeft: isFirst && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
          topRight: isLast && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
          bottomRight: isLast && !isBoldMinimalism ? Radius.circular(spacing.radiusMd - 1) : Radius.zero,
        ),
        child: Container(
          padding: _getPadding(spacing, size),
          decoration: BoxDecoration(
            border: !isLast && variant == IconToggleButtonsVariant.outlined
                ? Border(
                    right: BorderSide(
                      color: colors.border,
                      width: isBoldMinimalism ? 2 : 1,
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: spacing.iconSm,
                  color: selected
                      ? (variant == IconToggleButtonsVariant.tonal ? colors.primaryDark : colors.textOnPrimary)
                      : colors.textPrimary,
                ),
                if (item.label != null) SizedBox(width: spacing.xs),
              ],
              if (item.label != null)
                Text(
                  item.label!,
                  style: typography.labelMedium.copyWith(
                    color: selected
                        ? (variant == IconToggleButtonsVariant.tonal ? colors.primaryDark : colors.textOnPrimary)
                        : colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleItem {
  final IconData? icon;
  final String? label;
  final String? tooltip;

  const ToggleItem({
    this.icon,
    this.label,
    this.tooltip,
  }) : assert(icon != null || label != null);
}

enum IconButtonVariant { standard, filled, outlined }

enum IconToggleButtonsVariant { outlined, filled, tonal }

enum IconToggleButtonsSize { small, medium, large }

EdgeInsets _getPadding(DesignSpacing spacing, IconToggleButtonsSize size) {
  switch (size) {
    case IconToggleButtonsSize.small:
      return EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      );
    case IconToggleButtonsSize.medium:
      return EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      );
    case IconToggleButtonsSize.large:
      return EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.md,
      );
  }
}
