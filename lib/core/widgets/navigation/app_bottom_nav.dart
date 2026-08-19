import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// One destination in the bottom navigation.
@immutable
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;

  /// Outlined, for the inactive state.
  final IconData icon;

  /// Filled, for the active state.
  ///
  /// docs/DESIGN_SYSTEM.md §8: outlined-to-filled "is how bottom-nav selection
  /// reads without a colour change carrying the whole load".
  final IconData activeIcon;
}

/// The floating capsule navigation (docs/COMPONENTS.md §8, docs/design_ui.md §7).
///
/// Not a Material [NavigationBar]. The reference's navigation is a rounded
/// capsule floating above the content with a shadow, inset from the screen
/// edges — a full-width bar attached to the bottom is the single most
/// Material-looking element the app could have.
///
/// Scrollable content needs `AppLayout.scrollBottomPadding` at its foot so
/// nothing is ever trapped behind this.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;

  /// Called with the tapped index, including when it is already current — §8
  /// leaves what that means to the shell, which scrolls to top or pops to root.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: AppLayout.bottomNavInsetHorizontal,
        right: AppLayout.bottomNavInsetHorizontal,
        bottom:
            AppLayout.bottomNavInsetBottom +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.borderFull,
          boxShadow: context.shadows.lg,
        ),
        child: SizedBox(
          height: AppLayout.bottomNavHeight,
          child: Row(
            children: <Widget>[
              for (final (int index, AppBottomNavItem item) in items.indexed)
                Expanded(
                  child: _NavItem(
                    item: item,
                    isActive: index == currentIndex,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final Color color = isActive ? colors.primary : colors.textTertiary;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: item.label,
      // Announced as selected so the state does not rest on colour and fill
      // alone (docs/DESIGN_SYSTEM.md §11).
      semanticHint: isActive ? 'Selected' : null,
      // The row already gives each item a generous share of a 64 px bar.
      expandTouchTarget: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              // §8: the active item carries a primary50 pill behind its icon.
              color: isActive ? colors.primaryContainer : null,
              borderRadius: AppRadius.borderFull,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space1,
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.resolve(context, AppMotion.fast),
                // §8: "Icon transitions cross-fade over durationFast; there is
                // no sliding indicator."
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  key: ValueKey<bool>(isActive),
                  size: AppIconSize.md,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            item.label,
            style: context.text.overline.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}
