import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';

/// 기본 에러 위젯
class AppErrorWidget extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline,
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
              size: context.spacing.iconXxl,
              color: context.colors.error,
            ),
            SizedBox(height: context.spacing.lg),
            Text(
              message,
              style: context.typography.titleMedium.copyWith(
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              SizedBox(height: context.spacing.sm),
              Text(
                details!,
                style: context.typography.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: context.spacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: SText('common.retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 인라인 에러 메시지
class InlineError extends StatelessWidget {
  final String message;
  final IconData? icon;

  const InlineError({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.errorLight.withValues(alpha: 0.1),
        borderRadius: context.spacing.borderRadiusSm,
        border: Border.all(
          color: context.colors.errorLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: context.spacing.iconSm,
            color: context.colors.error,
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.typography.bodySmall.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 전체 화면 에러
class FullScreenError extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const FullScreenError({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl),
          child: Column(
            children: [
              if (onBack != null)
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              Expanded(
                child: AppErrorWidget(
                  message: title,
                  details: message,
                  onRetry: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
