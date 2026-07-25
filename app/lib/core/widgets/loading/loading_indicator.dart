import 'package:pipecheck/core/design/design.dart';
import 'package:flutter/material.dart';

/// 기본 로딩 인디케이터
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? Theme.of(context).colorScheme.primary,
          ),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

/// 전체 화면 로딩 위젯
class FullScreenLoading extends StatelessWidget {
  final String? message;
  final Widget? child;

  const FullScreenLoading({
    super.key,
    this.message,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child ?? const LoadingIndicator(),
            if (message != null) ...[
              SizedBox(height: context.spacing.lg),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 오버레이 로딩
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? context.colors.overlay,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(context.spacing.xl),
                decoration: BoxDecoration(
                  color: context.colors.backgroundElevated,
                  borderRadius: context.spacing.borderRadiusMd,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingIndicator(),
                    if (message != null) ...[
                      SizedBox(height: context.spacing.md),
                      Text(
                        message!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
