import 'package:flutter/widgets.dart';

/// Spacing scale from docs/DESIGN_SYSTEM.md §4, on a 4 px base grid.
///
/// No spacing literal may appear in feature code
/// (docs/CODING_STANDARDS.md §11).
abstract final class AppSpacing {
  static const double space0 = 0;

  /// Icon-to-label, tightest pairs.
  static const double space1 = 4;

  /// Inside chips, between metadata pills.
  static const double space2 = 8;

  /// Between related rows, list item gaps.
  static const double space3 = 12;

  /// Default gap, compact card padding.
  static const double space4 = 16;

  /// Screen horizontal margin.
  static const double space5 = 20;

  /// Card internal padding.
  static const double space6 = 24;

  /// Between sections.
  static const double space7 = 32;

  /// Around hero elements.
  static const double space8 = 40;

  /// Empty-state breathing room.
  static const double space9 = 48;

  /// Top of celebration screens.
  static const double space10 = 64;
}

/// The layout constants from docs/DESIGN_SYSTEM.md §4.
///
/// These are named for the decision they encode rather than for their value, so
/// a screen reads `AppLayout.screenMargin` and not `AppSpacing.space5` — the two
/// happen to be equal today and are free to diverge.
abstract final class AppLayout {
  /// Screen horizontal margin.
  static const double screenMargin = AppSpacing.space5;

  /// Screen top padding, below the safe area.
  static const double screenTopPadding = AppSpacing.space2;

  /// Standard card internal padding.
  static const double cardPadding = AppSpacing.space6;

  /// Compact card internal padding.
  static const double cardPaddingCompact = AppSpacing.space4;

  /// Gap between cards in a list.
  static const double cardGap = AppSpacing.space3;

  /// Gap between cells in a grid.
  static const double gridGap = AppSpacing.space3;

  /// Gap between sections.
  static const double sectionGap = AppSpacing.space7;

  /// Height of the floating bottom navigation bar.
  static const double bottomNavHeight = 64;

  /// Horizontal inset of the floating bottom navigation bar.
  static const double bottomNavInsetHorizontal = AppSpacing.space4;

  /// Gap between the bottom navigation bar and the safe area.
  static const double bottomNavInsetBottom = AppSpacing.space3;

  /// Bottom padding on every scroll view: content must clear the floating nav.
  static const double scrollBottomPadding = 96;

  /// Minimum touch target, per docs/DESIGN_SYSTEM.md §11.
  static const double minTouchTarget = 48;

  /// Gap required between adjacent touch targets (§11).
  static const double minTouchTargetGap = AppSpacing.space2;

  /// Content is capped at this width and centred on tablets (§10).
  static const double contentMaxWidth = 560;

  /// Screen margins as insets.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenMargin,
  );

  /// Standard card padding as insets.
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  /// Compact card padding as insets.
  static const EdgeInsets cardInsetsCompact = EdgeInsets.all(
    cardPaddingCompact,
  );
}
