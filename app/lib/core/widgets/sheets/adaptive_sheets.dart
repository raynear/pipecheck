import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 바텀 시트
class AdaptiveBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool showHandle;
  final bool isDismissible;
  final bool enableDrag;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final bool isScrollControlled;

  const AdaptiveBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.showHandle = true,
    this.isDismissible = true,
    this.enableDrag = true,
    this.initialChildSize,
    this.minChildSize,
    this.maxChildSize,
    this.isScrollControlled = false,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool showHandle = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    double? initialChildSize,
    double? minChildSize,
    double? maxChildSize,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => AdaptiveBottomSheet(
        title: title,
        actions: actions,
        showHandle: showHandle,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        isScrollControlled: isScrollControlled,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final content = Container(
      decoration: BoxDecoration(
        color: colors.backgroundElevated,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            isBoldMinimalism ? 0 : spacing.radiusXl,
          ),
          topRight: Radius.circular(
            isBoldMinimalism ? 0 : spacing.radiusXl,
          ),
        ),
        boxShadow: isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, -4),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Center(
              child: Container(
                margin: EdgeInsets.only(top: spacing.sm),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.gray300,
                  borderRadius: BorderRadius.circular(
                    isBoldMinimalism ? 0 : 2,
                  ),
                ),
              ),
            ),
          if (title != null)
            Container(
              padding: EdgeInsets.all(spacing.lg),
              decoration: BoxDecoration(
                border: isBoldMinimalism
                    ? Border(
                        bottom: BorderSide(
                          color: colors.divider,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isDismissible)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            Container(
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                border: isBoldMinimalism
                    ? Border(
                        top: BorderSide(
                          color: colors.divider,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .map((action) => Padding(
                          padding: EdgeInsets.only(
                            left: actions!.indexOf(action) > 0 ? spacing.sm : 0,
                          ),
                          child: action,
                        ))
                    .toList(),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );

    if (isScrollControlled) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize ?? 0.5,
        minChildSize: minChildSize ?? 0.25,
        maxChildSize: maxChildSize ?? 0.9,
        builder: (context, scrollController) => content,
      );
    }

    return content;
  }
}

/// 리스트 바텀 시트
class ListBottomSheet extends StatelessWidget {
  final String? title;
  final List<ListBottomSheetItem> items;
  final ValueChanged<int>? onItemTap;

  const ListBottomSheet({
    super.key,
    this.title,
    required this.items,
    this.onItemTap,
  });

  static Future<int?> show({
    required BuildContext context,
    String? title,
    required List<ListBottomSheetItem> items,
  }) async {
    return AdaptiveBottomSheet.show<int>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => _ListBottomSheetTile(
                  item: item,
                  onTap: () {
                    Navigator.of(context).pop(items.indexOf(item));
                  },
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveBottomSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => _ListBottomSheetTile(
                  item: item,
                  onTap: () => onItemTap?.call(items.indexOf(item)),
                ))
            .toList(),
      ),
    );
  }
}

class _ListBottomSheetTile extends StatelessWidget {
  final ListBottomSheetItem item;
  final VoidCallback? onTap;

  const _ListBottomSheetTile({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return InkWell(
      onTap: item.enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        child: Row(
          children: [
            if (item.icon != null)
              Icon(
                item.icon,
                color: item.enabled ? (item.isDestructive ? colors.error : colors.textPrimary) : colors.textDisabled,
                size: spacing.iconMd,
              ),
            if (item.icon != null) SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: typography.bodyMedium.copyWith(
                      color:
                          item.enabled ? (item.isDestructive ? colors.error : colors.textPrimary) : colors.textDisabled,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: typography.bodySmall.copyWith(
                        color: item.enabled ? colors.textSecondary : colors.textDisabled,
                      ),
                    ),
                ],
              ),
            ),
            if (item.trailing != null) item.trailing!,
          ],
        ),
      ),
    );
  }
}

class ListBottomSheetItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool enabled;
  final bool isDestructive;

  const ListBottomSheetItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.enabled = true,
    this.isDestructive = false,
  });
}

/// 그리드 바텀 시트
class GridBottomSheet extends StatelessWidget {
  final String? title;
  final List<GridBottomSheetItem> items;
  final int crossAxisCount;
  final ValueChanged<int>? onItemTap;

  const GridBottomSheet({
    super.key,
    this.title,
    required this.items,
    this.crossAxisCount = 4,
    this.onItemTap,
  });

  static Future<int?> show({
    required BuildContext context,
    String? title,
    required List<GridBottomSheetItem> items,
    int crossAxisCount = 4,
  }) async {
    return AdaptiveBottomSheet.show<int>(
      context: context,
      title: title,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _GridBottomSheetItem(
            item: item,
            onTap: () => Navigator.of(context).pop(index),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveBottomSheet(
      title: title,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _GridBottomSheetItem(
            item: item,
            onTap: () => onItemTap?.call(index),
          );
        },
      ),
    );
  }
}

class _GridBottomSheetItem extends StatelessWidget {
  final GridBottomSheetItem item;
  final VoidCallback? onTap;

  const _GridBottomSheetItem({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return InkWell(
      onTap: item.enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(spacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: spacing.iconLg,
              color: item.enabled ? colors.textPrimary : colors.textDisabled,
            ),
            SizedBox(height: spacing.xs),
            Text(
              item.label,
              style: typography.labelSmall.copyWith(
                color: item.enabled ? colors.textSecondary : colors.textDisabled,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class GridBottomSheetItem {
  final IconData icon;
  final String label;
  final bool enabled;

  const GridBottomSheetItem({
    required this.icon,
    required this.label,
    this.enabled = true,
  });
}
