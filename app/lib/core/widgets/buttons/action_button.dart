import 'package:boilerplate/core/widgets/buttons/analytics_buttons.dart';
import 'package:flutter/material.dart';

/// 재사용 가능한 액션 버튼
/// 앱 내 다양한 액션 버튼 스타일을 통일하기 위한 위젯
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isFullWidth;
  final String? analyticsEventName;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;
  final double borderRadius;

  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.backgroundColor,
    this.textColor,
    this.isFullWidth = true,
    this.analyticsEventName,
    this.padding,
    this.iconSize = 24,
    this.borderRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bgColor = backgroundColor ?? colorScheme.primary;
    final fgColor = textColor ?? colorScheme.onPrimary;

    final button = SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: AnalyticsElevatedButton(
        eventName: analyticsEventName ?? 'button_${label.toLowerCase().replaceAll(' ', '_')}',
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize),
            const SizedBox(width: 12),
            Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: button,
    );
  }
}

/// 취소/확인 버튼 쌍을 제공하는 위젯
class ActionButtonPair extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final IconData cancelIcon;
  final IconData confirmIcon;
  final Color? cancelColor;
  final Color? confirmColor;
  final String? cancelEventName;
  final String? confirmEventName;

  const ActionButtonPair({
    super.key,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Confirm',
    required this.onCancel,
    required this.onConfirm,
    this.cancelIcon = Icons.close,
    this.confirmIcon = Icons.check,
    this.cancelColor,
    this.confirmColor,
    this.cancelEventName,
    this.confirmEventName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: ActionButton(
            label: cancelLabel,
            onPressed: onCancel,
            icon: cancelIcon,
            backgroundColor: cancelColor ?? colorScheme.secondaryContainer,
            textColor: colorScheme.onSurfaceVariant,
            analyticsEventName: cancelEventName,
            borderRadius: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            label: confirmLabel,
            onPressed: onConfirm,
            icon: confirmIcon,
            backgroundColor: confirmColor ?? colorScheme.primary,
            analyticsEventName: confirmEventName,
            borderRadius: 16,
          ),
        ),
      ],
    );
  }
}
