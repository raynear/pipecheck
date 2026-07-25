import 'package:pipecheck/core/design/design.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 적응형 태그 (6:3:1 비율 준수)
/// 배경(60%) - 텍스트(30%) - 아이콘(10%)
class AdaptiveTag extends StatelessWidget {
  final String text;
  final TagVariant variant;
  final TagSize size;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Color? customColor;

  const AdaptiveTag({
    super.key,
    required this.text,
    this.variant = TagVariant.primary,
    this.size = TagSize.medium,
    this.icon,
    this.onTap,
    this.onRemove,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Size configurations
    EdgeInsets padding;
    TextStyle textStyle;
    double iconSize;
    double closeIconSize;

    switch (size) {
      case TagSize.small:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xxs,
        );
        textStyle = typography.labelSmall;
        iconSize = spacing.iconXs;
        closeIconSize = spacing.iconXs - 2;
        break;
      case TagSize.medium:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        );
        textStyle = typography.labelMedium;
        iconSize = spacing.iconSm;
        closeIconSize = spacing.iconSm - 2;
        break;
      case TagSize.large:
        padding = EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        );
        textStyle = typography.labelLarge;
        iconSize = spacing.iconMd;
        closeIconSize = spacing.iconMd - 2;
        break;
    }

    // Color configurations
    Color backgroundColor;
    Color foregroundColor;

    if (customColor != null) {
      backgroundColor = customColor!.withValues(alpha: 0.1);
      foregroundColor = customColor!;
    } else {
      switch (variant) {
        case TagVariant.primary:
          backgroundColor = colors.primaryLight;
          foregroundColor = colors.primaryDark;
          break;
        case TagVariant.secondary:
          backgroundColor = colors.gray100;
          foregroundColor = colors.textSecondary;
          break;
        case TagVariant.success:
          backgroundColor = colors.successLight;
          foregroundColor = colors.successDark;
          break;
        case TagVariant.warning:
          backgroundColor = colors.warningLight;
          foregroundColor = colors.warningDark;
          break;
        case TagVariant.error:
          backgroundColor = colors.errorLight;
          foregroundColor = colors.errorDark;
          break;
        case TagVariant.info:
          backgroundColor = colors.infoLight;
          foregroundColor = colors.infoDark;
          break;
      }
    }

    final tag = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusSm,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusSm,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize,
                  color: foregroundColor,
                ),
                SizedBox(width: spacing.xxs),
              ],
              Text(
                text,
                style: textStyle.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRemove != null) ...[
                SizedBox(width: spacing.xxs),
                InkWell(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close,
                    size: closeIconSize,
                    color: foregroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return tag;
  }
}

/// 상태 태그
class AdaptiveStatusTag extends StatelessWidget {
  final String text;
  final StatusType status;
  final TagSize size;

  const AdaptiveStatusTag({
    super.key,
    required this.text,
    required this.status,
    this.size = TagSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    TagVariant variant;

    switch (status) {
      case StatusType.active:
        icon = Icons.check_circle;
        variant = TagVariant.success;
        break;
      case StatusType.inactive:
        icon = Icons.cancel;
        variant = TagVariant.secondary;
        break;
      case StatusType.pending:
        icon = Icons.access_time;
        variant = TagVariant.warning;
        break;
      case StatusType.error:
        icon = Icons.error;
        variant = TagVariant.error;
        break;
    }

    return AdaptiveTag(
      text: text,
      icon: icon,
      variant: variant,
      size: size,
    );
  }
}

/// 카테고리 태그
class AdaptiveCategoryTag extends StatelessWidget {
  final String category;
  final Color? color;
  final VoidCallback? onTap;
  final TagSize size;

  const AdaptiveCategoryTag({
    super.key,
    required this.category,
    this.color,
    this.onTap,
    this.size = TagSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTag(
      text: category,
      customColor: color,
      onTap: onTap,
      size: size,
      variant: TagVariant.secondary,
    );
  }
}

/// 태그 목록
class AdaptiveTagList extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<int>? onTagTap;
  final ValueChanged<int>? onTagRemove;
  final double spacing;
  final double runSpacing;
  final TagSize size;
  final TagVariant variant;
  final int? maxTags;

  const AdaptiveTagList({
    super.key,
    required this.tags,
    this.onTagTap,
    this.onTagRemove,
    this.spacing = 8,
    this.runSpacing = 8,
    this.size = TagSize.small,
    this.variant = TagVariant.secondary,
    this.maxTags,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final spacing = context.spacing;

    final displayTags = maxTags != null && tags.length > maxTags! ? tags.take(maxTags!).toList() : tags;
    final remainingCount = tags.length - displayTags.length;

    return Wrap(
      spacing: this.spacing,
      runSpacing: runSpacing,
      children: [
        ...displayTags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;

          return AdaptiveTag(
            text: tag,
            variant: variant,
            size: size,
            onTap: onTagTap != null ? () => onTagTap!(index) : null,
            onRemove: onTagRemove != null ? () => onTagRemove!(index) : null,
          );
        }),
        if (remainingCount > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.gray100,
              borderRadius: BorderRadius.circular(spacing.radiusSm),
            ),
            child: Text(
              '+$remainingCount',
              style: typography.labelSmall.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// 태그 입력 필드
class AdaptiveTagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>>? onTagsChanged;
  final String? hintText;
  final int? maxTags;
  final FormFieldValidator<String>? validator;
  final List<String>? suggestions;

  const AdaptiveTagInput({
    super.key,
    required this.tags,
    this.onTagsChanged,
    this.hintText,
    this.maxTags,
    this.validator,
    this.suggestions,
  });

  @override
  State<AdaptiveTagInput> createState() => _AdaptiveTagInputState();
}

class _AdaptiveTagInputState extends State<AdaptiveTagInput> {
  late TextEditingController _controller;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = List.from(widget.tags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;
    if (widget.maxTags != null && _tags.length >= widget.maxTags!) return;
    if (_tags.contains(tag)) return;

    setState(() {
      _tags.add(tag);
    });
    widget.onTagsChanged?.call(_tags);
    _controller.clear();
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
    widget.onTagsChanged?.call(_tags);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty) ...[
          AdaptiveTagList(
            tags: _tags,
            onTagRemove: _removeTag,
            size: TagSize.medium,
          ),
          SizedBox(height: spacing.sm),
        ],
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'inputs.tag.hint'.tr(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(_controller.text),
            ),
          ),
          validator: widget.validator,
          onFieldSubmitted: _addTag,
        ),
      ],
    );
  }
}

enum TagVariant { primary, secondary, success, warning, error, info }

enum TagSize { small, medium, large }

enum StatusType { active, inactive, pending, error }
