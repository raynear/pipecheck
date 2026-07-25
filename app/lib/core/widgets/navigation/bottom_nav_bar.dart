import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
// import 'package:utils/utils.dart';

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithBottomNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
        body: child,
        bottomNavigationBar: StylishBottomBar(
          option: AnimatedBarOptions(
            padding: const EdgeInsets.only(top: 16),
            inkEffect: true,
            // inkColor: colorScheme.secondary,
            iconSize: 32,
            barAnimation: BarAnimation.blink,
            iconStyle: IconStyle.animated,
            opacity: 0.3,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          backgroundColor: colorScheme.primaryContainer,
          // option: BubbleBarOptions(
          //   barStyle: BubbleBarStyle.horizontal,
          //   bubbleFillStyle: BubbleFillStyle.fill,
          //   opacity: 0.3,
          // ),
          // option: DotBarOptions(
          //   dotStyle: DotStyle.tile,
          //   gradient: const LinearGradient(
          //     colors: [
          //       Colors.deepPurple,
          //       Colors.pink,
          //     ],
          //     begin: Alignment.topLeft,
          //     end: Alignment.bottomRight,
          //   ),
          // ),
          items: [
            BottomBarItem(
              icon: const Icon(Icons.home),
              title: SText('bottom_navi_bar.home'),
              // backgroundColor: colorScheme.secondaryContainer,
              selectedColor: colorScheme.secondary,
              unSelectedColor: colorScheme.outline,
            ),
            BottomBarItem(
              icon: const Icon(Icons.bar_chart),
              title: SText('bottom_navi_bar.stats'),
              // backgroundColor: colorScheme.secondaryContainer,
              selectedColor: colorScheme.secondary,
              unSelectedColor: colorScheme.outline,
            ),
            BottomBarItem(
              icon: const Icon(Icons.emoji_events),
              title: SText('bottom_navi_bar.badges'),
              // backgroundColor: colorScheme.secondaryContainer,
              selectedColor: colorScheme.secondary,
              unSelectedColor: colorScheme.outline,
            ),
            BottomBarItem(
              icon: const Icon(Icons.settings),
              title: SText('bottom_navi_bar.settings'),
              // backgroundColor: colorScheme.secondaryContainer,
              selectedColor: colorScheme.secondary,
              unSelectedColor: colorScheme.outline,
            ),
          ],
          // fabLocation: StylishBarFabLocation.end,
          // hasNotch: true,
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) {
            _onItemTapped(index, context);
          },
        )
        // BottomNavigationBar(
        //   items: const [
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.home),
        //       label: '홈',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.bar_chart),
        //       label: '통계',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.emoji_events),
        //       label: '뱃지',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.settings),
        //       label: '설정',
        //     ),
        //   ],
        //   currentIndex: _calculateSelectedIndex(context),
        //   onTap: (int idx) => _onItemTapped(idx, context),
        //   selectedItemColor: colorScheme.primary,
        //   unselectedItemColor: colorScheme.inversePrimary,
        //   showUnselectedLabels: true,
        // ),
        );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/stats')) {
      return 1;
    }
    if (location.startsWith('/badges')) {
      return 2;
    }
    if (location.startsWith('/settings')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/home');
        break;
      case 1:
        GoRouter.of(context).go('/stats');
        break;
      case 2:
        GoRouter.of(context).go('/badges');
        break;
      case 3:
        GoRouter.of(context).go('/settings');
        break;
    }
  }
}
