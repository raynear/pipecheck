import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 리스트 타일 (6:3:1 비율 준수)
/// 배경(60%) - 텍스트/아이콘(30%) - 액센트(10%)
class AdaptiveListTile extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final ListTileVariant variant;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  const AdaptiveListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.dense = false,
    this.contentPadding,
    this.variant = ListTileVariant.standard,
    this.backgroundColor,
    this.shape,
  });

  @override
  State<AdaptiveListTile> createState() => _AdaptiveListTileState();
}

class _AdaptiveListTileState extends State<AdaptiveListTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: _buildTile(context, isBoldMinimalism),
      ),
    );
  }

  Widget _buildTile(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;

    Widget tile;

    switch (widget.variant) {
      case ListTileVariant.standard:
        tile = _buildStandardTile(context);
        break;
      case ListTileVariant.card:
        tile = _buildCardTile(context, isBoldMinimalism);
        break;
      case ListTileVariant.outlined:
        tile = _buildOutlinedTile(context, isBoldMinimalism);
        break;
    }

    // 상태에 따른 배경색
    final backgroundColor = widget.backgroundColor ??
        (widget.selected
            ? colors.primary.withValues(alpha: 0.1)
            : _isPressed
                ? colors.gray100
                : _isHovered
                    ? colors.gray50
                    : Colors.transparent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.shape != null
            ? null
            : BorderRadius.circular(
                isBoldMinimalism ? 0 : spacing.radiusMd,
              ),
      ),
      child: tile,
    );
  }

  Widget _buildStandardTile(BuildContext context) {
    return ListTile(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: widget.trailing,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      enabled: widget.enabled,
      selected: widget.selected,
      dense: widget.dense,
      contentPadding: widget.contentPadding,
      shape: widget.shape,
    );
  }

  Widget _buildCardTile(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Card(
      elevation: isBoldMinimalism ? 0 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusMd,
        ),
        side: isBoldMinimalism ? BorderSide(color: colors.cardBorder, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: widget.leading,
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: widget.trailing,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        enabled: widget.enabled,
        selected: widget.selected,
        dense: widget.dense,
        contentPadding: widget.contentPadding ??
            EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs,
            ),
      ),
    );
  }

  Widget _buildOutlinedTile(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.selected ? colors.primary : colors.border,
          width: isBoldMinimalism ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusMd,
        ),
      ),
      child: ListTile(
        leading: widget.leading,
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: widget.trailing,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        enabled: widget.enabled,
        selected: widget.selected,
        dense: widget.dense,
        contentPadding: widget.contentPadding ??
            EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs,
            ),
      ),
    );
  }
}

/// 간단한 리스트 아이템
class AdaptiveListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;
  final ListItemSize size;

  const AdaptiveListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.size = ListItemSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final dimensions = _getDimensions(context);

    return AdaptiveListTile(
      leading: icon != null
          ? Icon(
              icon,
              color: selected
                  ? colors.primary
                  : enabled
                      ? colors.textPrimary
                      : colors.textDisabled,
              size: dimensions.iconSize,
            )
          : null,
      title: Text(
        title,
        style: dimensions.titleStyle.copyWith(
          color: enabled ? colors.textPrimary : colors.textDisabled,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: dimensions.subtitleStyle.copyWith(
                color: enabled ? colors.textSecondary : colors.textDisabled,
              ),
            )
          : null,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      selected: selected,
      dense: size == ListItemSize.small,
      contentPadding: dimensions.padding,
    );
  }

  _ListItemDimensions _getDimensions(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;

    switch (size) {
      case ListItemSize.small:
        return _ListItemDimensions(
          iconSize: spacing.iconSm,
          titleStyle: typography.bodySmall,
          subtitleStyle: typography.labelSmall,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.xs,
          ),
        );

      case ListItemSize.medium:
        return _ListItemDimensions(
          iconSize: spacing.iconMd,
          titleStyle: typography.bodyMedium,
          subtitleStyle: typography.bodySmall,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
        );

      case ListItemSize.large:
        return _ListItemDimensions(
          iconSize: spacing.iconLg,
          titleStyle: typography.bodyLarge,
          subtitleStyle: typography.bodyMedium,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
        );
    }
  }
}

/// 섹션 헤더
class AdaptiveListSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AdaptiveListSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.labelLarge.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: typography.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 리스트 구분선
class AdaptiveDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final Color? color;

  const AdaptiveDivider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;

    return Divider(
      height: height ?? 1,
      thickness: thickness ?? (isBoldMinimalism ? 2 : 1),
      indent: indent,
      endIndent: endIndent,
      color: color ?? colors.divider,
    );
  }
}

enum ListTileVariant { standard, card, outlined }

enum ListItemSize { small, medium, large }

class _ListItemDimensions {
  final double iconSize;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final EdgeInsets padding;

  const _ListItemDimensions({
    required this.iconSize,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.padding,
  });
}
