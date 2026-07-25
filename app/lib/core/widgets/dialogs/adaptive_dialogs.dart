import 'package:boilerplate/core/design/design.dart';
import 'package:boilerplate/core/widgets/buttons/adaptive_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 적응형 다이얼로그 (6:3:1 비율 준수)
/// 배경(60%) - 콘텐츠(30%) - 액션(10%)
class AdaptiveDialog extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<DialogAction> actions;
  final EdgeInsetsGeometry? contentPadding;
  final MainAxisAlignment actionsAlignment;
  final bool barrierDismissible;

  const AdaptiveDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.contentPadding,
    this.actionsAlignment = MainAxisAlignment.end,
    this.barrierDismissible = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? content,
    List<DialogAction> actions = const [],
    EdgeInsetsGeometry? contentPadding,
    MainAxisAlignment actionsAlignment = MainAxisAlignment.end,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AdaptiveDialog(
        title: title,
        content: content,
        actions: actions,
        contentPadding: contentPadding,
        actionsAlignment: actionsAlignment,
        barrierDismissible: barrierDismissible,
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusLg,
        ),
      ),
      elevation: isBoldMinimalism ? 0 : 24,
      backgroundColor: colors.backgroundElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                child: Text(
                  title!,
                  style: typography.titleLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (content != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: contentPadding ??
                      EdgeInsets.symmetric(
                        horizontal: spacing.lg,
                        vertical: spacing.md,
                      ),
                  child: content!,
                ),
              ),
            if (actions.isNotEmpty)
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
                  mainAxisAlignment: actionsAlignment,
                  children: actions
                      .map((action) => Padding(
                            padding: EdgeInsets.only(
                              left: actions.indexOf(action) > 0 ? spacing.sm : 0,
                            ),
                            child: _buildAction(context, action),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, DialogAction action) {
    return AdaptiveButton(
      label: action.label,
      onPressed: () {
        if (action.onPressed != null) {
          action.onPressed!();
        } else {
          Navigator.of(context).pop(action.value);
        }
      },
      variant: action.isPrimary
          ? ButtonVariant.primary
          : action.isDestructive
              ? ButtonVariant.secondary
              : ButtonVariant.text,
      size: ButtonSize.medium,
    );
  }
}

/// Alert Dialog
class AlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final AlertType type;

  const AlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.onConfirm,
    this.type = AlertType.info,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    VoidCallback? onConfirm,
    AlertType type = AlertType.info,
  }) async {
    await AdaptiveDialog.show(
      context: context,
      title: title,
      content: _AlertContent(
        message: message,
        type: type,
      ),
      actions: [
        DialogAction(
          label: confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: true,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: title,
      content: _AlertContent(
        message: message,
        type: type,
      ),
      actions: [
        DialogAction(
          label: confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: true,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
        ),
      ],
    );
  }
}

class _AlertContent extends StatelessWidget {
  final String message;
  final AlertType type;

  const _AlertContent({
    required this.message,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    IconData icon;
    Color color;

    switch (type) {
      case AlertType.success:
        icon = Icons.check_circle;
        color = colors.success;
        break;
      case AlertType.error:
        icon = Icons.error;
        color = colors.error;
        break;
      case AlertType.warning:
        icon = Icons.warning;
        color = colors.warning;
        break;
      case AlertType.info:
        icon = Icons.info;
        color = colors.info;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: spacing.iconXxl,
          color: color,
        ),
        SizedBox(height: spacing.md),
        Text(
          message,
          style: typography.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Confirmation Dialog
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final result = await AdaptiveDialog.show<bool>(
      context: context,
      title: title,
      content: Text(
        message,
        style: context.typography.bodyMedium,
      ),
      actions: [
        DialogAction(
          label: cancelLabel ?? 'common.cancel'.tr(),
          value: false,
        ),
        DialogAction(
          label: confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: !isDestructive,
          isDestructive: isDestructive,
          value: true,
        ),
      ],
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: title,
      content: Text(
        message,
        style: context.typography.bodyMedium,
      ),
      actions: [
        DialogAction(
          label: cancelLabel ?? 'common.cancel'.tr(),
          onPressed: () {
            Navigator.of(context).pop(false);
            onCancel?.call();
          },
        ),
        DialogAction(
          label: confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: !isDestructive,
          isDestructive: isDestructive,
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm?.call();
          },
        ),
      ],
    );
  }
}

/// 입력 다이얼로그
class InputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? hint;
  final String? confirmLabel;
  final String? cancelLabel;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;

  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialValue,
    this.hint,
    this.confirmLabel,
    this.cancelLabel,
    this.validator,
    this.keyboardType,
    this.maxLength,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hint,
    String? confirmLabel,
    String? cancelLabel,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    int? maxLength,
  }) async {
    return AdaptiveDialog.show<String>(
      context: context,
      barrierDismissible: false,
      title: title,
      content: _InputDialogContent(
        message: message,
        initialValue: initialValue,
        hint: hint,
        validator: validator,
        keyboardType: keyboardType,
        maxLength: maxLength,
      ),
      actions: [
        DialogAction(
          label: cancelLabel ?? 'common.cancel'.tr(),
        ),
        DialogAction(
          label: confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: true,
        ),
      ],
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: widget.title,
      content: _InputDialogContent(
        message: widget.message,
        controller: _controller,
        hint: widget.hint,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        formKey: _formKey,
      ),
      actions: [
        DialogAction(
          label: widget.cancelLabel ?? 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: widget.confirmLabel ?? 'common.confirm'.tr(),
          isPrimary: true,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
        ),
      ],
    );
  }
}

class _InputDialogContent extends StatelessWidget {
  final String? message;
  final String? initialValue;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextEditingController? controller;
  final GlobalKey<FormState>? formKey;

  const _InputDialogContent({
    this.message,
    this.initialValue,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.controller,
    this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[
            Text(
              message!,
              style: typography.bodyMedium,
            ),
            SizedBox(height: spacing.md),
          ],
          TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            autofocus: true,
            keyboardType: keyboardType,
            maxLength: maxLength,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
            ),
          ),
        ],
      ),
    );
  }
}

class DialogAction {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback? onPressed;
  final dynamic value;

  const DialogAction({
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
    this.onPressed,
    this.value,
  });
}

enum AlertType { success, error, warning, info }
