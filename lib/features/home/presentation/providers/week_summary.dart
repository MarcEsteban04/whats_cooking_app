import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_spin_controller.dart';

part 'week_summary.g.dart';

/// Where things stand, for Home's second panel (Sprint 47b).
///
/// **Four numbers, and every one of them is a destination.** That is the rule this
/// exists to follow: docs/project_dev.md cut "food statistics" as "an interesting
/// dashboard nobody opens twice", and it was right to. What survives that cut is not
/// a chart — it is a count somebody can *act* on tonight, which is a different kind
/// of number entirely.
///
/// So: how many decisions this week (the one figure worth a headline), and then how
/// many meals the kitchen already covers, how many things want using up, and how
/// many lines are still on the shopping list. Three taps, three screens.
///
/// Composed from providers Home already warms before a spin, so this panel costs
/// one extra query — the grocery list — and nothing else.
@immutable
class WeekSummary {
  const WeekSummary({
    this.mealsCooked = 0,
    this.nightsOut = 0,
    this.averageCostPerHead,
    this.cookableNow = 0,
    this.needsUsing = 0,
    this.stillToBuy = 0,
  });

  /// Dinners decided by cooking, in the last seven days.
  final int mealsCooked;

  /// Nights decided by going out.
  final int nightsOut;

  /// What those decisions cost a head on average, or null when nothing is known.
  ///
  /// **A mean here, unlike the restaurant list's median.** That one summarises a
  /// standing list where one expensive place distorts the picture; this summarises
  /// a week that actually happened, and the total divided by the nights *is* what
  /// the week cost.
  final double? averageCostPerHead;

  /// Meals the pantry already covers completely.
  final int cookableNow;

  /// Things in the kitchen that want eating soon.
  final int needsUsing;

  /// Lines still unticked on the shopping list.
  final int stillToBuy;

  /// Decisions made this week, however they were made.
  int get decisions => mealsCooked + nightsOut;

  /// Whether there is anything worth showing a panel for.
  ///
  /// A panel of four zeros on a fresh install is a panel that says "this app has
  /// nothing for you", so Home hides it entirely until one number is real.
  bool get hasAnything =>
      decisions > 0 || cookableNow > 0 || needsUsing > 0 || stillToBuy > 0;
}

/// Home's second panel.
///
/// Everything is best-effort. A summary that fails is a panel that does not appear;
/// it must never be the reason Home does not load, because Home's actual job is the
/// button in the middle of it.
@riverpod
Future<WeekSummary> weekSummary(Ref ref) async {
  final DateTime now = DateTime.now();
  final DateTime weekAgo = now.subtract(const Duration(days: 7));

  final List<MealHistoryEntry> history =
      ref.watch(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

  final List<PantryItem> pantry =
      ref.watch(pantryControllerProvider).value ?? const <PantryItem>[];

  final Map<String, PantryMatch> matches =
      ref.watch(pantryMatchesProvider).value ?? const <String, PantryMatch>{};

  final List<GroceryItem> grocery =
      ref.watch(groceryControllerProvider).value ?? const <GroceryItem>[];

  final List<MealHistoryEntry> cooked = <MealHistoryEntry>[
    for (final MealHistoryEntry entry in history)
      if (entry.eatenAt.isAfter(weekAgo)) entry,
  ];

  // Nights out are read directly rather than through a provider, because nothing
  // else in the app watches them and a keepAlive provider for one panel is a cache
  // with no second reader. Wrapped, because migration 0025 may not be applied.
  List<RestaurantVisit> visits = const <RestaurantVisit>[];
  try {
    visits = await ref
        .read(restaurantHistoryRepositoryProvider)
        .recent(limit: _visitLookback);
  } on Object catch (error) {
    AppLog.warning(
      'Could not read nights out for the week summary.',
      name: 'weekSummary',
      data: <String, Object?>{'reason': error.toString()},
    );
  }

  final List<RestaurantVisit> recentVisits = <RestaurantVisit>[
    for (final RestaurantVisit visit in visits)
      if (visit.eatenAt.isAfter(weekAgo)) visit,
  ];

  // What the week cost, from whichever figure each decision has. `actualCost`
  // where somebody said, the estimate otherwise — and nights with neither are left
  // out of both the total and the divisor, so an unpriced evening does not drag the
  // average toward zero.
  final List<double> costs = <double>[
    for (final MealHistoryEntry entry in cooked)
      if (entry.costPerServing case final double cost) cost,
    for (final RestaurantVisit visit in recentVisits)
      if (visit.actualCost ?? visit.estimatedCost case final double cost) cost,
  ];

  return WeekSummary(
    mealsCooked: cooked.length,
    nightsOut: recentVisits.length,
    averageCostPerHead: costs.isEmpty
        ? null
        : costs.reduce((double a, double b) => a + b) / costs.length,
    cookableNow: matches.values
        .where((PantryMatch match) => match.isComplete)
        .length,
    needsUsing: pantry
        .where((PantryItem item) => item.statusAsOf(now).needsAttention)
        .length,
    stillToBuy: grocery.where((GroceryItem item) => !item.isCompleted).length,
  );
}

/// Enough to cover a week comfortably, without pulling a history nobody asked for.
const int _visitLookback = 20;
