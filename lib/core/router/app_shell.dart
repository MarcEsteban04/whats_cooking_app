import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/navigation/app_bottom_nav.dart';

/// The five MVP tabs (docs/NAVIGATION_MAP.md §3).
///
/// docs/design_ui.md §7 lists Planner as a tab, but Planner is v1.3 and Pantry
/// is an MVP feature, so the MVP ships Pantry in that slot. §3's recommended
/// evolution when Planner arrives is to merge Pantry and Grocery into a single
/// **Kitchen** tab with two segments — they are the same mental space (what I
/// have / what I need), and it frees a slot without reaching six tabs.
enum AppTab {
  home(route: AppRoute.home, label: 'Home'),
  meals(route: AppRoute.meals, label: 'Meals'),
  pantry(route: AppRoute.pantry, label: 'Pantry'),
  grocery(route: AppRoute.grocery, label: 'Grocery'),
  profile(route: AppRoute.profile, label: 'Profile');

  const AppTab({required this.route, required this.label});

  /// The tab's root route.
  final AppRoute route;
  final String label;

  IconData get icon => switch (this) {
    AppTab.home => AppIcons.home,
    AppTab.meals => AppIcons.meals,
    AppTab.pantry => AppIcons.pantry,
    AppTab.grocery => AppIcons.grocery,
    AppTab.profile => AppIcons.profile,
  };

  IconData get activeIcon => switch (this) {
    AppTab.home => AppIcons.homeActive,
    AppTab.meals => AppIcons.mealsActive,
    AppTab.pantry => AppIcons.pantry,
    AppTab.grocery => AppIcons.groceryActive,
    AppTab.profile => AppIcons.profileActive,
  };

  AppBottomNavItem get navItem =>
      AppBottomNavItem(label: label, icon: icon, activeIcon: activeIcon);
}

/// The application shell: the five tabs and the floating navigation.
///
/// docs/NAVIGATION_MAP.md §9 specifies one `StatefulShellRoute.indexedStack`
/// with a navigator key per branch. The indexed stack is what makes §8's
/// state-preservation table true for free — each tab keeps its own navigation
/// stack and its own scroll position because its subtree is never disposed.
///
/// The navigation floats *over* the content rather than sitting beneath it, so
/// scrollable content needs `AppLayout.scrollBottomPadding` at its foot.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: navigationShell,
      // extendBody so the content scrolls behind the floating capsule instead
      // of stopping in a band above it.
      extendBody: true,
      bottomNavigationBar: AppBottomNav(
        items: AppTab.values
            .map((AppTab tab) => tab.navItem)
            .toList(growable: false),
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
      ),
    );
  }

  /// docs/NAVIGATION_MAP.md §8: "Re-tapping the active tab scrolls to top;
  /// re-tapping again pops that tab to its root."
  ///
  /// `initialLocation: true` is what pops a tab to its root, so re-tapping the
  /// current tab is passed through as that. The scroll-to-top half needs a
  /// scroll controller owned by the tab's own screen, so it is implemented by
  /// each screen as it is built rather than guessed at here.
  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
