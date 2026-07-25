import 'package:pipecheck/core/design/design.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';

/// 빈 상태를 보여주는 위젯
class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: context.colors.gray400,
            ),
            SizedBox(height: context.spacing.lg),
            Text(
              title,
              style: context.typography.titleMedium.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: context.spacing.sm),
              Text(
                message!,
                style: context.typography.bodyMedium.copyWith(
                  color: context.colors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: context.spacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 검색 결과가 없을 때
class NoSearchResults extends StatelessWidget {
  final String query;
  final VoidCallback? onClear;

  const NoSearchResults({
    super.key,
    required this.query,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'search.emptyTitle'.tr(),
      message: 'search.emptyMessage'.tr(args: [query]),
      action: onClear != null
          ? TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              label: SText('search.reset'),
            )
          : null,
    );
  }
}

/// 목록이 비어있을 때
class EmptyList extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyList({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.list_alt,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: (actionLabel != null && onAction != null)
          ? ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            )
          : null,
    );
  }
}
