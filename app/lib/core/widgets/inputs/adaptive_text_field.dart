import 'package:boilerplate/core/design/design.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 적응형 텍스트 필드 (6:3:1 비율 준수)
/// 배경(60%) - 테두리/라벨(30%) - 포커스/에러(10%)
class AdaptiveTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextFieldVariant variant;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  const AdaptiveTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.variant = TextFieldVariant.outlined,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  @override
  State<AdaptiveTextField> createState() => _AdaptiveTextFieldState();
}

class _AdaptiveTextFieldState extends State<AdaptiveTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    _hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.variant != TextFieldVariant.filled)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Text(
              widget.label!,
              style: typography.labelMedium.copyWith(
                color: _hasError
                    ? colors.error
                    : _isFocused
                        ? colors.primary
                        : colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        _buildTextField(context, isBoldMinimalism),
        if (widget.helperText != null || widget.errorText != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              widget.errorText ?? widget.helperText!,
              style: typography.labelSmall.copyWith(
                color: _hasError ? colors.error : colors.textTertiary,
              ),
            ),
          ),
        if (widget.maxLength != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_controller.text.length}/${widget.maxLength}',
                style: typography.labelSmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, bool isBoldMinimalism) {
    final spacing = context.spacing;

    final borderRadius = BorderRadius.circular(
      isBoldMinimalism ? 0 : spacing.radiusMd,
    );

    switch (widget.variant) {
      case TextFieldVariant.outlined:
        return _buildOutlinedTextField(
          context,
          isBoldMinimalism,
          borderRadius,
        );

      case TextFieldVariant.filled:
        return _buildFilledTextField(
          context,
          isBoldMinimalism,
          borderRadius,
        );

      case TextFieldVariant.underlined:
        return _buildUnderlinedTextField(
          context,
          isBoldMinimalism,
        );
    }
  }

  Widget _buildOutlinedTextField(
    BuildContext context,
    bool isBoldMinimalism,
    BorderRadius borderRadius,
  ) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: widget.enabled ? colors.backgroundPrimary : colors.gray50,
        borderRadius: borderRadius,
        border: Border.all(
          color: _hasError
              ? colors.error
              : _isFocused
                  ? colors.primary
                  : colors.inputBorder,
          width: isBoldMinimalism ? 2 : (_isFocused ? 2 : 1),
        ),
      ),
      child: _buildTextFormField(context, borderRadius),
    );
  }

  Widget _buildFilledTextField(
    BuildContext context,
    bool isBoldMinimalism,
    BorderRadius borderRadius,
  ) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: widget.enabled ? colors.inputBackground : colors.gray100,
        borderRadius: borderRadius,
        border: _isFocused || _hasError
            ? Border.all(
                color: _hasError ? colors.error : colors.primary,
                width: isBoldMinimalism ? 2 : 1,
              )
            : null,
      ),
      child: _buildTextFormField(context, borderRadius),
    );
  }

  Widget _buildUnderlinedTextField(
    BuildContext context,
    bool isBoldMinimalism,
  ) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _hasError
                ? colors.error
                : _isFocused
                    ? colors.primary
                    : colors.inputBorder,
            width: isBoldMinimalism ? 2 : (_isFocused ? 2 : 1),
          ),
        ),
      ),
      child: _buildTextFormField(context, BorderRadius.zero),
    );
  }

  Widget _buildTextFormField(BuildContext context, BorderRadius borderRadius) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      style: typography.bodyMedium.copyWith(
        color: widget.enabled ? colors.textPrimary : colors.textDisabled,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: typography.bodyMedium.copyWith(
          color: colors.textTertiary,
        ),
        labelText: widget.variant == TextFieldVariant.filled ? widget.label : null,
        labelStyle: typography.bodyMedium.copyWith(
          color: _hasError
              ? colors.error
              : _isFocused
                  ? colors.primary
                  : colors.textTertiary,
        ),
        floatingLabelStyle: typography.labelSmall.copyWith(
          color: _hasError ? colors.error : colors.primary,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        border: InputBorder.none,
        counterText: '',
      ),
    );
  }
}

/// 검색 필드
class AdaptiveSearchField extends StatefulWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool showClearButton;

  const AdaptiveSearchField({
    super.key,
    // i18n: const 기본값 .tr() 불가 → null 두고 build에서 common.search 해석.
    this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.autofocus = false,
    this.showClearButton = true,
  });

  @override
  State<AdaptiveSearchField> createState() => _AdaptiveSearchFieldState();
}

class _AdaptiveSearchFieldState extends State<AdaptiveSearchField> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onClear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.gray50,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusFull,
        ),
        border: isBoldMinimalism
            ? Border.all(
                color: colors.border,
                width: 2,
              )
            : null,
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: spacing.md),
            child: Icon(
              Icons.search,
              color: colors.textTertiary,
              size: spacing.iconMd,
            ),
          ),
          Expanded(
            child: AdaptiveTextField(
              controller: _controller,
              hint: widget.hint ?? 'common.search'.tr(),
              onSubmitted: widget.onSubmitted,
              autofocus: widget.autofocus,
              variant: TextFieldVariant.underlined,
            ),
          ),
          if (widget.showClearButton && _hasText)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: colors.textTertiary,
                size: spacing.iconSm,
              ),
              onPressed: _onClear,
            ),
        ],
      ),
    );
  }
}

enum TextFieldVariant { outlined, filled, underlined }
