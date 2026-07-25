import 'package:pipecheck/core/design/design.dart';
import 'package:pipecheck/core/widgets/inputs/adaptive_text_field.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 폼 필드 래퍼
class AdaptiveFormField<T> extends StatelessWidget {
  final String label;
  final String? helperText;
  final String? errorText;
  final bool required;
  final Widget child;

  const AdaptiveFormField({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.errorText,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: typography.labelMedium.copyWith(
                color: errorText != null ? colors.error : colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: typography.labelMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        child,
        if (helperText != null || errorText != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              errorText ?? helperText!,
              style: typography.labelSmall.copyWith(
                color: errorText != null ? colors.error : colors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// 드롭다운 필드
class AdaptiveDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<AdaptiveDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? label;
  final String? errorText;
  final bool enabled;
  final Widget? prefixIcon;

  const AdaptiveDropdownField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.label,
    this.errorText,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Text(
              label!,
              style: typography.labelMedium.copyWith(
                color: hasError ? colors.error : colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: enabled ? colors.backgroundPrimary : colors.gray50,
            borderRadius: BorderRadius.circular(
              isBoldMinimalism ? 0 : spacing.radiusMd,
            ),
            border: Border.all(
              color: hasError ? colors.error : colors.inputBorder,
              width: isBoldMinimalism ? 2 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item.value,
                        child: Row(
                          children: [
                            if (item.icon != null) ...[
                              Icon(
                                item.icon,
                                size: spacing.iconSm,
                                color: colors.textPrimary,
                              ),
                              SizedBox(width: spacing.sm),
                            ],
                            Text(
                              item.label,
                              style: typography.bodyMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: enabled ? onChanged : null,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textTertiary,
                      ),
                    )
                  : null,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: enabled ? colors.textPrimary : colors.textDisabled,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              borderRadius: BorderRadius.circular(
                isBoldMinimalism ? 0 : spacing.radiusMd,
              ),
              dropdownColor: colors.backgroundElevated,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              errorText!,
              style: typography.labelSmall.copyWith(
                color: colors.error,
              ),
            ),
          ),
      ],
    );
  }
}

class AdaptiveDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AdaptiveDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// 날짜 선택 필드
class AdaptiveDateField extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool enabled;
  final DateFieldMode mode;

  const AdaptiveDateField({
    super.key,
    this.value,
    this.onChanged,
    this.firstDate,
    this.lastDate,
    this.label,
    // i18n: const 생성자 기본값에 .tr() 직삽 불가 → null 두고 build에서 해석.
    this.hint,
    this.errorText,
    this.enabled = true,
    this.mode = DateFieldMode.date,
  });

  @override
  State<AdaptiveDateField> createState() => _AdaptiveDateFieldState();
}

class _AdaptiveDateFieldState extends State<AdaptiveDateField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _updateControllerText();
  }

  @override
  void didUpdateWidget(AdaptiveDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateControllerText();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateControllerText() {
    if (widget.value != null) {
      _controller.text = _formatDate(widget.value!);
    } else {
      _controller.clear();
    }
  }

  String _formatDate(DateTime date) {
    switch (widget.mode) {
      case DateFieldMode.date:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case DateFieldMode.time:
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      case DateFieldMode.dateTime:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _selectDate() async {
    if (!widget.enabled) return;

    final now = DateTime.now();
    final initialDate = widget.value ?? now;
    final firstDate = widget.firstDate ?? DateTime(1900);
    final lastDate = widget.lastDate ?? DateTime(2100);

    if (widget.mode == DateFieldMode.time) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null) {
        final newDate = DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
          time.hour,
          time.minute,
        );
        widget.onChanged?.call(newDate);
      }
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );

      if (date != null) {
        if (widget.mode == DateFieldMode.dateTime) {
          if (!mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialDate),
          );

          if (time != null) {
            final newDate = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            widget.onChanged?.call(newDate);
          }
        } else {
          widget.onChanged?.call(date);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    IconData icon;
    switch (widget.mode) {
      case DateFieldMode.date:
        icon = Icons.calendar_today;
        break;
      case DateFieldMode.time:
        icon = Icons.access_time;
        break;
      case DateFieldMode.dateTime:
        icon = Icons.event;
        break;
    }

    return AdaptiveTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint ?? 'inputs.dateField.hint'.tr(),
      errorText: widget.errorText,
      enabled: widget.enabled,
      readOnly: true,
      onEditingComplete: _selectDate,
      suffixIcon: IconButton(
        icon: Icon(
          icon,
          color: widget.enabled ? colors.textPrimary : colors.textDisabled,
          size: spacing.iconMd,
        ),
        onPressed: widget.enabled ? _selectDate : null,
      ),
    );
  }
}

/// 텍스트 영역 (여러 줄 입력)
class AdaptiveTextArea extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const AdaptiveTextArea({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextField(
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      enabled: enabled,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

enum DateFieldMode { date, time, dateTime }
