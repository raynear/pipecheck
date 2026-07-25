import 'package:boilerplate/core/design/design.dart';
import 'package:flutter/material.dart';

/// 적응형 탭바
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<AdaptiveTab> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  final bool isScrollable;
  final EdgeInsetsGeometry? labelPadding;
  final TabBarIndicatorSize? indicatorSize;
  final TabBarVariant variant;

  const AdaptiveTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
    this.isScrollable = false,
    this.labelPadding,
    this.indicatorSize,
    this.variant = TabBarVariant.standard,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    final tabWidgets = tabs
        .map((tab) => Tab(
              text: tab.text,
              icon: tab.icon != null ? Icon(tab.icon) : null,
              child: tab.child,
            ))
        .toList();

    switch (variant) {
      case TabBarVariant.standard:
        return _buildStandardTabBar(
          context,
          tabWidgets,
          isBoldMinimalism,
        );

      case TabBarVariant.filled:
        return _buildFilledTabBar(
          context,
          tabWidgets,
          isBoldMinimalism,
        );

      case TabBarVariant.outlined:
        return _buildOutlinedTabBar(
          context,
          tabWidgets,
          isBoldMinimalism,
        );
    }
  }

  Widget _buildStandardTabBar(
    BuildContext context,
    List<Tab> tabWidgets,
    bool isBoldMinimalism,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return TabBar(
      tabs: tabWidgets,
      controller: controller,
      onTap: onTap,
      isScrollable: isScrollable,
      labelPadding: labelPadding,
      indicatorSize: indicatorSize,
      labelColor: colors.primary,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: typography.labelMedium.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: typography.labelMedium,
      indicatorColor: colors.primary,
      indicatorWeight: isBoldMinimalism ? 4 : 2,
      indicator: isBoldMinimalism
          ? UnderlineTabIndicator(
              borderSide: BorderSide(
                color: colors.primary,
                width: 4,
              ),
              insets: EdgeInsets.zero,
            )
          : null,
    );
  }

  Widget _buildFilledTabBar(
    BuildContext context,
    List<Tab> tabWidgets,
    bool isBoldMinimalism,
  ) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      height: 48,
      margin: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.gray100,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusFull,
        ),
      ),
      child: TabBar(
        tabs: tabWidgets,
        controller: controller,
        onTap: onTap,
        isScrollable: isScrollable,
        labelPadding: labelPadding ??
            EdgeInsets.symmetric(
              horizontal: spacing.md,
            ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.textOnPrimary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: typography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: typography.labelMedium,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : spacing.radiusFull,
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedTabBar(
    BuildContext context,
    List<Tab> tabWidgets,
    bool isBoldMinimalism,
  ) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      height: 48,
      margin: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.border,
          width: isBoldMinimalism ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusMd,
        ),
      ),
      child: TabBar(
        tabs: tabWidgets,
        controller: controller,
        onTap: onTap,
        isScrollable: isScrollable,
        labelPadding: labelPadding ??
            EdgeInsets.symmetric(
              horizontal: spacing.md,
            ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colors.textOnPrimary,
        unselectedLabelColor: colors.textPrimary,
        labelStyle: typography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: typography.labelMedium,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(
            isBoldMinimalism ? 0 : spacing.radiusMd - 1,
          ),
        ),
      ),
    );
  }
}

/// 적응형 바텀 네비게이션 바
class AdaptiveBottomNavigationBar extends StatelessWidget {
  final List<AdaptiveNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final BottomNavigationBarType? type;
  final Color? backgroundColor;
  final double? elevation;
  final BottomNavVariant variant;

  const AdaptiveBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    this.onTap,
    this.type,
    this.backgroundColor,
    this.elevation,
    this.variant = BottomNavVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');

    switch (variant) {
      case BottomNavVariant.standard:
        return _buildStandardBottomNav(context, isBoldMinimalism);

      case BottomNavVariant.floating:
        return _buildFloatingBottomNav(context, isBoldMinimalism);

      case BottomNavVariant.minimal:
        return _buildMinimalBottomNav(context, isBoldMinimalism);
    }
  }

  Widget _buildStandardBottomNav(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;

    return BottomNavigationBar(
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: item.activeIcon != null ? Icon(item.activeIcon) : Icon(item.icon),
                label: item.label,
                tooltip: item.tooltip,
              ))
          .toList(),
      currentIndex: currentIndex,
      onTap: onTap,
      type: type ?? (items.length > 3 ? BottomNavigationBarType.fixed : BottomNavigationBarType.shifting),
      backgroundColor: backgroundColor ?? colors.backgroundPrimary,
      selectedItemColor: colors.primary,
      unselectedItemColor: colors.textTertiary,
      elevation: elevation ?? (isBoldMinimalism ? 0 : 8),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      margin: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.backgroundElevated,
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusXl,
        ),
        boxShadow: isBoldMinimalism
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          isBoldMinimalism ? 0 : spacing.radiusXl,
        ),
        child: BottomNavigationBar(
          items: items
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: item.activeIcon != null ? Icon(item.activeIcon) : Icon(item.icon),
                    label: item.label,
                    tooltip: item.tooltip,
                  ))
              .toList(),
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.textTertiary,
          selectedLabelStyle: typography.labelSmall,
          unselectedLabelStyle: typography.labelSmall,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildMinimalBottomNav(BuildContext context, bool isBoldMinimalism) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == currentIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap?.call(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected && item.activeIcon != null ? item.activeIcon : item.icon,
                    color: isSelected ? colors.primary : colors.textTertiary,
                    size: spacing.iconMd,
                  ),
                  if (isSelected && item.label != null)
                    Container(
                      margin: EdgeInsets.only(top: spacing.xxs),
                      width: spacing.xs,
                      height: spacing.xs,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: isBoldMinimalism ? BoxShape.rectangle : BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 적응형 네비게이션 레일
class AdaptiveNavigationRail extends StatelessWidget {
  final List<AdaptiveNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? leading;
  final Widget? trailing;
  final double? width;
  final double? elevation;
  final Color? backgroundColor;
  final bool extended;
  final double? minWidth;
  final double? minExtendedWidth;

  const AdaptiveNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.leading,
    this.trailing,
    this.width,
    this.elevation,
    this.backgroundColor,
    this.extended = false,
    this.minWidth,
    this.minExtendedWidth,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final isBoldMinimalism = design.name.contains('Bold');
    final colors = context.colors;
    final spacing = context.spacing;

    return NavigationRail(
      destinations: destinations
          .map((dest) => NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: dest.activeIcon != null ? Icon(dest.activeIcon) : Icon(dest.icon),
                label: Text(dest.label ?? ''),
              ))
          .toList(),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      leading: leading,
      trailing: trailing,
      backgroundColor: backgroundColor ?? colors.backgroundPrimary,
      elevation: elevation ?? (isBoldMinimalism ? 0 : 1),
      extended: extended,
      minWidth: minWidth ?? 72,
      minExtendedWidth: minExtendedWidth ?? 256,
      selectedIconTheme: IconThemeData(
        color: colors.primary,
      ),
      unselectedIconTheme: IconThemeData(
        color: colors.textTertiary,
      ),
      selectedLabelTextStyle: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colors.textTertiary,
      ),
      indicatorColor: colors.primary.withValues(alpha: 0.1),
      indicatorShape: isBoldMinimalism
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(spacing.radiusMd),
            ),
    );
  }
}

class AdaptiveTab {
  final String? text;
  final IconData? icon;
  final Widget? child;

  const AdaptiveTab({
    this.text,
    this.icon,
    this.child,
  }) : assert(text != null || icon != null || child != null);
}

class AdaptiveNavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String? label;
  final String? tooltip;

  const AdaptiveNavigationItem({
    required this.icon,
    this.activeIcon,
    this.label,
    this.tooltip,
  });
}

enum TabBarVariant { standard, filled, outlined }

enum BottomNavVariant { standard, floating, minimal }
