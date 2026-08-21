import 'package:flutter/material.dart';

/// Icon sizes from docs/DESIGN_SYSTEM.md §8.
///
/// An icon-only control is always at least
/// `AppLayout.minTouchTarget` in touch size regardless of the glyph size, and
/// always carries a semantic label.
abstract final class AppIconSize {
  /// Inline with `bodySmall`, inside chips.
  static const double xs = 16;

  /// Metadata rows, text-field affixes.
  static const double sm = 20;

  /// Default — nav, buttons, app bar.
  static const double md = 24;

  /// Feature cards, empty states.
  static const double lg = 28;

  /// Empty and error illustrations.
  static const double xl = 48;
}

/// The app's icon vocabulary.
///
/// Material Symbols Rounded (§8) — rounded matches the geometry of the system;
/// sharp icons fight it. Naming every glyph in one place means a swap happens
/// once, and that a screen never reaches for a near-miss icon because the right
/// one was hard to find.
///
/// Outlined is inactive and **filled is active**: that pairing is how bottom-nav
/// selection reads without colour carrying the whole load.
abstract final class AppIcons {
  // Navigation (docs/design_ui.md §7).
  static const IconData home = Icons.home_outlined;
  static const IconData homeActive = Icons.home_rounded;
  static const IconData meals = Icons.restaurant_outlined;
  static const IconData mealsActive = Icons.restaurant_rounded;
  static const IconData planner = Icons.calendar_today_outlined;
  static const IconData plannerActive = Icons.calendar_month_rounded;
  static const IconData grocery = Icons.shopping_cart_outlined;
  static const IconData groceryActive = Icons.shopping_cart_rounded;
  static const IconData profile = Icons.person_outline_rounded;
  static const IconData profileActive = Icons.person_rounded;

  // Actions.
  static const IconData search = Icons.search_rounded;
  static const IconData clear = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_ios_new_rounded;
  static const IconData forward = Icons.arrow_forward_ios_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData share = Icons.ios_share_rounded;
  static const IconData check = Icons.check_rounded;

  // Product concepts.
  static const IconData spin = Icons.casino_outlined;
  static const IconData favorite = Icons.favorite_border_rounded;
  static const IconData favoriteActive = Icons.favorite_rounded;
  static const IconData dislike = Icons.thumb_down_outlined;
  static const IconData dislikeActive = Icons.thumb_down_rounded;

  /// Bringing a hidden meal back (Sprint 25). An undo rather than a filled
  /// thumb: the thumb states what the meal *is*, this states what tapping does,
  /// and on a list where every row is hidden only the second is worth a glyph.
  static const IconData restore = Icons.undo_rounded;
  static const IconData pantry = Icons.kitchen_outlined;
  static const IconData budget = Icons.payments_outlined;
  static const IconData cookingTime = Icons.schedule_rounded;
  static const IconData servings = Icons.people_outline_rounded;
  static const IconData difficulty = Icons.local_fire_department_outlined;
  static const IconData cuisine = Icons.public_rounded;
  static const IconData household = Icons.favorite_outline_rounded;
  static const IconData assistant = Icons.auto_awesome_outlined;

  /// Asking the assistant to *write* something, rather than to answer (Sprint 48).
  ///
  /// Its own glyph because the two sit side by side in the Meals header, and two
  /// sparkles that do different things is worse than no icon at all. A wand reads
  /// as "make me one" where sparkles read as "help me".
  static const IconData invent = Icons.auto_fix_high_outlined;
  static const IconData camera = Icons.photo_camera_outlined;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData expiring = Icons.event_busy_outlined;

  /// For the "we sent you a link, go and look" moment.
  static const IconData mail = Icons.mark_email_unread_outlined;

  // Feedback (§2.4 — never colour alone).
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData info = Icons.info_outline_rounded;
}
