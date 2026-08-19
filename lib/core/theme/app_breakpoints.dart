import 'package:flutter/widgets.dart';

/// The three layout classes from docs/DESIGN_SYSTEM.md §10.
enum AppBreakpoint {
  /// Below 600 px. Single column, category grid 3 across, meal feed 1 across.
  compact,

  /// 600–904 px. Content capped and centred, category grid 4, meal feed 2.
  medium,

  /// Above 904 px. Content capped, meal feed 2–3, nav may become a rail.
  expanded;

  bool get isCompact => this == AppBreakpoint.compact;
  bool get isMedium => this == AppBreakpoint.medium;
  bool get isExpanded => this == AppBreakpoint.expanded;

  /// Whether content should be capped at `AppLayout.contentMaxWidth`.
  bool get capsContentWidth => this != AppBreakpoint.compact;

  /// Columns in the Home quick-category grid.
  int get categoryGridColumns => switch (this) {
    AppBreakpoint.compact => 3,
    AppBreakpoint.medium => 4,
    AppBreakpoint.expanded => 4,
  };

  /// Columns in the meal discovery feed.
  int get mealFeedColumns => switch (this) {
    AppBreakpoint.compact => 1,
    AppBreakpoint.medium => 2,
    AppBreakpoint.expanded => 3,
  };
}

/// Resolves a width to an [AppBreakpoint].
///
/// Feature code must never branch on a raw pixel value
/// (docs/DESIGN_SYSTEM.md §10) — it asks for the breakpoint and reads what it
/// needs off the enum. That keeps the numbers here, where they can be changed
/// once.
abstract final class AppBreakpoints {
  /// Upper bound of [AppBreakpoint.compact], exclusive.
  static const double compactMax = 600;

  /// Upper bound of [AppBreakpoint.medium], exclusive.
  static const double mediumMax = 904;

  /// The narrowest device the design supports. A 320 px screen must show the
  /// whole SPIN card without scrolling — that is the hard floor (§10).
  static const double minimumSupportedWidth = 320;

  static AppBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static AppBreakpoint fromWidth(double width) {
    if (width < compactMax) {
      return AppBreakpoint.compact;
    }
    if (width < mediumMax) {
      return AppBreakpoint.medium;
    }
    return AppBreakpoint.expanded;
  }
}
