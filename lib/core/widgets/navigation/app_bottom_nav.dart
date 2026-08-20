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

/// The floating capsule navigation (docs/design_ui.md §7).
///
/// Built to `docs/reference_design/reference_img.webp`, whose navigation has a
/// specific behaviour worth naming: **only the selected destination shows its
/// label.** The active item is a pill holding icon *and* text side by side; the
/// rest are bare icons.
///
/// That is not decoration. Five labels across a 320 px screen forces `overline`
/// down to a size nobody reads, and reading four labels you are not on is work
/// the design does not need. One label, on the thing you are looking at, is
/// enough — and it lets the active pill be wide enough to actually read.
///
/// Two deliberate departures from docs/COMPONENTS.md §8, both following the
/// reference (as the near-black CTA does):
///
/// * §8 gives every item a label; the reference labels only the active one.
/// * §8 makes the active item `primary600` on a `primary50` pill; the reference's
///   active pill is a neutral tint with near-black content, and keeps green for
///   accents. Reference wins, as it did for the primary button.
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            child: Row(
              children: <Widget>[
                for (final (int index, AppBottomNavItem item) in items.indexed)
                  // The active item takes the room it needs for its label and the
                  // rest share what is left. A fixed split would either cramp the
                  // label or leave the icons floating in too much space.
                  Flexible(
                    flex: index == currentIndex ? _activeFlex : 1,
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
      ),
    );
  }

  /// How much wider the labelled item is than a bare icon.
  static const int _activeFlex = 2;
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

    return PressFeedback(
      onTap: onTap,
      semanticLabel: item.label,
      // Announced as selected so the state does not rest on the pill and the
      // filled glyph alone (docs/DESIGN_SYSTEM.md §11).
      semanticHint: isActive ? 'Selected' : null,
      expandTouchTarget: false,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.curveFast,
          height: _pillHeight,
          // Padding only where there is a pill to pad. An inactive item is a
          // bare glyph, and horizontal padding there is invisible but not free:
          // it sets a 48 px minimum width, which overflows the capsule once six
          // destinations share a 320 px screen.
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? AppSpacing.space4 : 0,
          ),
          decoration: BoxDecoration(
            color: isActive ? colors.surfaceMuted : null,
            borderRadius: AppRadius.borderFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isActive ? item.activeIcon : item.icon,
                size: AppIconSize.md,
                color: isActive ? colors.textPrimary : colors.textTertiary,
              ),
              if (isActive) ...<Widget>[
                const SizedBox(width: AppSpacing.space2),
                // Flexible so a long label at 1.3x scale ellipsises rather than
                // overflowing the capsule.
                Flexible(
                  child: Text(
                    item.label,
                    style: context.text.labelSmall.copyWith(
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const double _pillHeight = 40;
}
