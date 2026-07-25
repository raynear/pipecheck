import 'package:boilerplate/core/design/design.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 적응형 앱바 (6:3:1 비율 준수)
/// 배경(60%) - 타이틀/아이콘(30%) - 액션(10%)
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double? elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final double? titleSpacing;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final AppBarVariant variant;

  const AdaptiveAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle = true,
    this.titleSpacing,
    this.systemOverlayStyle,
    this.bottom,
    this.toolbarHeight,
    this.variant = AppBarVariant.standard,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    switch (variant) {
      case AppBarVariant.standard:
        return _buildStandardAppBar(context, isBoldMinimalism);
      case AppBarVariant.transparent:
        return _buildTransparentAppBar(context, isBoldMinimalism);
      case AppBarVariant.minimal:
        return _buildMinimalAppBar(context, isBoldMinimalism);
    }
  }

  AppBar _buildStandardAppBar(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation ?? (isBoldMinimalism ? 0 : 1),
      backgroundColor: backgroundColor ?? colors.backgroundPrimary,
      foregroundColor: foregroundColor ?? colors.textPrimary,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      systemOverlayStyle: systemOverlayStyle ??
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: context.isDarkMode ? Brightness.light : Brightness.dark,
          ),
      bottom: bottom,
      toolbarHeight: toolbarHeight,
      shape: isBoldMinimalism
          ? Border(
              bottom: BorderSide(
                color: colors.divider,
                width: 2,
              ),
            )
          : null,
    );
  }

  AppBar _buildTransparentAppBar(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: foregroundColor ?? colors.textPrimary,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      systemOverlayStyle: systemOverlayStyle ?? SystemUiOverlayStyle.dark,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
    );
  }

  AppBar _buildMinimalAppBar(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: 0,
      backgroundColor: backgroundColor ?? colors.backgroundPrimary,
      foregroundColor: foregroundColor ?? colors.textPrimary,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      systemOverlayStyle: systemOverlayStyle,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
    );
  }
}

/// 확장 가능한 앱바
class SliverAdaptiveAppBar extends StatelessWidget {
  final Widget? title;
  final Widget? flexibleSpace;
  final Widget? leading;
  final List<Widget>? actions;
  final bool floating;
  final bool pinned;
  final bool snap;
  final double expandedHeight;
  final double? collapsedHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const SliverAdaptiveAppBar({
    super.key,
    this.title,
    this.flexibleSpace,
    this.leading,
    this.actions,
    this.floating = false,
    this.pinned = true,
    this.snap = false,
    required this.expandedHeight,
    this.collapsedHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.systemOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;

    return SliverAppBar(
      title: title,
      flexibleSpace: flexibleSpace ?? _buildDefaultFlexibleSpace(context),
      leading: leading,
      actions: actions,
      floating: floating,
      pinned: pinned,
      snap: snap,
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      backgroundColor: backgroundColor ?? colors.backgroundPrimary,
      foregroundColor: foregroundColor ?? colors.textPrimary,
      elevation: isBoldMinimalism ? 0 : 4,
      systemOverlayStyle: systemOverlayStyle,
      shape: isBoldMinimalism
          ? Border(
              bottom: BorderSide(
                color: colors.divider,
                width: 2,
              ),
            )
          : null,
    );
  }

  Widget _buildDefaultFlexibleSpace(BuildContext context) {
    final colors = context.colors;

    return FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primary,
              colors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

/// 검색 앱바
class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final List<Widget>? actions;
  final bool autofocus;

  const SearchAppBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.actions,
    this.autofocus = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
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
    final typography = context.typography;

    return AppBar(
      elevation: isBoldMinimalism ? 0 : 1,
      backgroundColor: colors.backgroundPrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onSubmitted: widget.onSubmitted,
        style: typography.bodyMedium,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'common.search'.tr(),
          hintStyle: typography.bodyMedium.copyWith(
            color: colors.textTertiary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
        ),
      ),
      actions: [
        if (_hasText)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _onClear,
          ),
        ...?widget.actions,
      ],
      shape: isBoldMinimalism
          ? Border(
              bottom: BorderSide(
                color: colors.divider,
                width: 2,
              ),
            )
          : null,
    );
  }
}

enum AppBarVariant { standard, transparent, minimal }
