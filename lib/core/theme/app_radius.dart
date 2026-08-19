import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Corner radii from docs/DESIGN_SYSTEM.md §5.
///
/// Nothing in the app is sharper than 8 px, and interactive pills are fully
/// rounded.
abstract final class AppRadius {
  /// Skeleton bars, tiny badges.
  static const double xs = 8;

  /// Inputs, small tiles, ingredient chips.
  static const double sm = 12;

  /// Compact cards, list rows, images inside cards.
  static const double md = 16;

  /// Standard cards, text fields.
  static const double lg = 20;

  /// Meal cards, category cards.
  static const double xl = 24;

  /// Feature cards, bottom sheets, dialogs.
  static const double xxl = 28;

  /// Roulette card, hero surfaces.
  static const double xxxl = 32;

  /// Pills, chips, buttons, avatars, FABs.
  static const double full = 999;

  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderXxxl = BorderRadius.all(
    Radius.circular(xxxl),
  );
  static const BorderRadius borderFull = BorderRadius.all(
    Radius.circular(full),
  );

  /// Top-only radius, for bottom sheets and image headers.
  static BorderRadius top(double radius) =>
      BorderRadius.vertical(top: Radius.circular(radius));

  /// Bottom-only radius, for the meal-detail hero image.
  static BorderRadius bottom(double radius) =>
      BorderRadius.vertical(bottom: Radius.circular(radius));

  /// The radius an element nested inside an [outer]-radius surface should use
  /// when separated from its edge by [padding].
  ///
  /// Concentric corners are what make nesting read as intentional, and the rule
  /// in docs/DESIGN_SYSTEM.md §5 is "outer minus padding, floored at
  /// `radiusSm`" — implemented literally here.
  ///
  /// Note that §5's worked example does not follow from its own rule: it says a
  /// 24 px card with 24 px padding takes an inner radius of 16, but the formula
  /// yields 0, which the floor lifts to 12. The rule is implemented rather than
  /// the example, because a helper has to generalise; if 16 is the intended
  /// visual, the floor is what needs revising, not the arithmetic.
  static double nested({required double outer, required double padding}) {
    return math.max(sm, outer - padding);
  }
}
