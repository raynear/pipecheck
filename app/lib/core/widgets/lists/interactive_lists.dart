import 'package:pipecheck/core/design/design.dart';
import 'package:pipecheck/core/widgets/lists/adaptive_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';

/// 스와이프 가능한 리스트 아이템
class SwipeableListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismissed;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool confirmDismiss;
  final SwipeDirection direction;

  const SwipeableListItem({
    super.key,
    required this.child,
    this.onDismissed,
    this.onArchive,
    this.onDelete,
    this.onEdit,
    this.confirmDismiss = true,
    this.direction = SwipeDirection.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Dismissible(
      key: key ?? UniqueKey(),
      direction: direction == SwipeDirection.horizontal
          ? DismissDirection.horizontal
          : direction == SwipeDirection.endToStart
              ? DismissDirection.endToStart
              : DismissDirection.startToEnd,
      confirmDismiss: confirmDismiss
          ? (direction) async {
              final action = direction == DismissDirection.endToStart ? 'delete' : 'archive';
              return await _showConfirmDialog(context, action);
            }
          : null,
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        } else {
          onArchive?.call();
        }
        onDismissed?.call();
      },
      background: Container(
        color: colors.primary,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Icon(
          Icons.archive,
          color: colors.textOnPrimary,
          size: spacing.iconMd,
        ),
      ),
      secondaryBackground: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Icon(
          Icons.delete,
          color: colors.textOnError,
          size: spacing.iconMd,
        ),
      ),
      child: child,
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText('common.confirm'),
        content: SText(
          action == 'delete' ? 'list.confirmDelete' : 'list.confirmArchive',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: SText('common.cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: SText(
              action == 'delete' ? 'common.delete' : 'common.archive',
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 확장 가능한 리스트 아이템
class ExpandableListItem extends StatefulWidget {
  final Widget title;
  final List<Widget> children;
  final Widget? leading;
  final Widget? subtitle;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry? childrenPadding;

  const ExpandableListItem({
    super.key,
    required this.title,
    required this.children,
    this.leading,
    this.subtitle,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.tilePadding,
    this.childrenPadding,
  });

  @override
  State<ExpandableListItem> createState() => _ExpandableListItemState();
}

class _ExpandableListItemState extends State<ExpandableListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _controller.drive(
      Tween<double>(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeIn)),
    );
    _heightFactor = _controller.drive(
      CurveTween(curve: Curves.easeIn),
    );

    _isExpanded = widget.initiallyExpanded;
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    final borderRadius = BorderRadius.circular(
      isBoldMinimalism ? 0 : spacing.radiusMd,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isExpanded
            ? widget.backgroundColor ?? colors.gray50
            : widget.collapsedBackgroundColor ?? Colors.transparent,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: borderRadius,
            child: AdaptiveListTile(
              leading: widget.leading,
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: RotationTransition(
                turns: _iconTurns,
                child: Icon(
                  Icons.expand_more,
                  color: colors.textSecondary,
                ),
              ),
              contentPadding: widget.tilePadding,
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) => SizeTransition(
                sizeFactor: _heightFactor,
                child: child,
              ),
              child: Container(
                padding: widget.childrenPadding ??
                    EdgeInsets.only(
                      left: widget.leading != null ? spacing.xxl : spacing.md,
                      right: spacing.md,
                      bottom: spacing.sm,
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 재정렬 가능한 리스트
class AdaptiveReorderableListView extends StatelessWidget {
  final List<ReorderableItem> items;
  final ReorderCallback onReorder;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const AdaptiveReorderableListView({
    super.key,
    required this.items,
    required this.onReorder,
    this.header,
    this.footer,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    final List<Widget> children = [];

    // Add header with a unique key
    if (header != null) {
      children.add(Container(
        key: const ValueKey('header'),
        child: header!,
      ));
    }

    // Add items with drag handles
    children.addAll(items.map((item) => Container(
          key: ValueKey(item.id),
          margin: EdgeInsets.symmetric(
            vertical: spacing.xs,
            horizontal: spacing.md,
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: items.indexOf(item) + (header != null ? 1 : 0),
                child: Icon(
                  Icons.drag_handle,
                  color: colors.textTertiary,
                  size: spacing.iconMd,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(child: item.child),
            ],
          ),
        )));

    // Add footer with a unique key
    if (footer != null) {
      children.add(Container(
        key: const ValueKey('footer'),
        child: footer!,
      ));
    }

    return ListView(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      children: children,
    );
  }

  double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

class ReorderableItem {
  final String id;
  final Widget child;

  const ReorderableItem({
    required this.id,
    required this.child,
  });
}

/// 선택 가능한 리스트
class SelectableList extends StatelessWidget {
  final List<SelectableItem> items;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final bool multiSelect;
  final Widget? emptyState;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const SelectableList({
    super.key,
    required this.items,
    required this.selectedIds,
    this.onSelectionChanged,
    this.multiSelect = true,
    this.emptyState,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyState != null) {
      return emptyState!;
    }

    final listView = ListView.builder(
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);

        return AdaptiveListTile(
          leading: multiSelect
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) => _handleSelection(item.id, value ?? false),
                )
              : Radio<String>(
                  value: item.id,
                ),
          title: item.title,
          subtitle: item.subtitle,
          trailing: item.trailing,
          selected: isSelected,
          onTap: () => _handleSelection(item.id, !isSelected),
        );
      },
    );

    // Single select mode uses RadioGroup
    if (!multiSelect) {
      return RadioGroup<String>(
        groupValue: selectedIds.firstOrNull,
        onChanged: onSelectionChanged != null
            ? (value) => _handleSelection(value!, true)
            : (_) {},
        child: listView,
      );
    }

    return listView;
  }

  void _handleSelection(String id, bool selected) {
    if (onSelectionChanged == null) return;

    final newSelection = Set<String>.from(selectedIds);

    if (multiSelect) {
      if (selected) {
        newSelection.add(id);
      } else {
        newSelection.remove(id);
      }
    } else {
      newSelection.clear();
      if (selected) {
        newSelection.add(id);
      }
    }

    onSelectionChanged!(newSelection);
  }
}

class SelectableItem {
  final String id;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  const SelectableItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.trailing,
  });
}

enum SwipeDirection { horizontal, startToEnd, endToStart }
