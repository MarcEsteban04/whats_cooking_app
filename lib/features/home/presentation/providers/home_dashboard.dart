import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_spin_controller.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';

part 'home_dashboard.g.dart';

/// One week's food spend, a head (Sprint 47b).
@immutable
class WeekSpend {
  const WeekSpend({required this.weeksAgo, this.cooked = 0, this.eatenOut = 0});

  /// 0 is this week, 5 is five weeks back.
  final int weeksAgo;

  /// Pesos a head spent on food cooked at home.
  final double cooked;

  /// Pesos a head spent going out.
  final double eatenOut;

  double get total => cooked + eatenOut;
}

/// Everything Home's second panel draws (Sprint 47b).
///
/// **Two charts and three counts, and the split between them is the point.** The
/// counts are *destinations* — a number you can act on tonight, each one a tap to
/// the screen where it changes. The charts are the opposite: they are the app
/// reporting on itself, and they exist because a household watching what it spends
/// has one question a list of numbers cannot answer, which is *is it getting worse*.
///
/// docs/project_dev.md cut "food statistics" as "an interesting dashboard nobody
/// opens twice", and that stands for a pie chart of cuisines on its own screen.
/// These two are here because they are the only ones that change a decision: the
/// spend trend tells you whether to cook this week, and the cuisine mix is the
/// variety engine's premise made visible.
@immutable
class HomeDashboard {
  const HomeDashboard({
    this.mealsCooked = 0,
    this.nightsOut = 0,
    this.averageCostPerHead,
    this.cookableNow = 0,
    this.needsUsing = 0,
    this.stillToBuy = 0,
    this.spend = const <WeekSpend>[],
    this.cuisineMix = const <Cuisine, int>{},
    this.ownMeals = 0,
    this.pantryItems = 0,
    this.places = 0,
  });

  final int mealsCooked;
  final int nightsOut;

  /// What a decision cost on average this week.
  ///
  /// **A mean here, unlike the restaurant list's median.** That one summarises a
  /// standing list where one expensive place distorts the picture; this summarises a
  /// week that happened, and the total over the nights *is* what the week cost.
  final double? averageCostPerHead;

  final int cookableNow;
  final int needsUsing;
  final int stillToBuy;

  /// Six weeks, oldest first. Always six entries, zeros included — a bar chart
  /// with gaps in it is a chart that has lied about its axis.
  final List<WeekSpend> spend;

  /// What was eaten in the last thirty days, by cuisine.
  final Map<Cuisine, int> cuisineMix;

  /// How much of the app has been set up. Only read when nothing has been decided
  /// yet, for the guide that replaces the panel.
  final int ownMeals;
  final int pantryItems;
  final int places;

  int get decisions => mealsCooked + nightsOut;

  /// Whether anything has been decided, ever — not just this week.
  ///
  /// The charts need history, and "nothing this week" is a normal Monday rather
  /// than an empty app. So the panel switches to the setup guide only when there is
  /// *no* history at all.
  bool get hasHistory => spend.any((WeekSpend week) => week.total > 0);

  /// Whether there is a number worth showing at all.
  bool get hasAnything =>
      decisions > 0 ||
      cookableNow > 0 ||
      needsUsing > 0 ||
      stillToBuy > 0 ||
      hasHistory;

  /// The three things that make the app worth using, and whether each is done.
  ///
  /// Shown instead of the panel on a fresh install. Four zeros in a dashboard is a
  /// panel announcing the app has nothing for you; a list of three things to do is
  /// the same space spent usefully.
  List<({String label, String body, bool isDone, HomeSetupStep step})>
  get setupSteps =>
      <({String label, String body, bool isDone, HomeSetupStep step})>[
        (
          label: 'Add a few of your own meals',
          body: 'The roulette is only as good as the library.',
          isDone: ownMeals > 0,
          step: HomeSetupStep.meals,
        ),
        (
          label: 'Say what is in the kitchen',
          body: 'Then it can offer things you can cook right now.',
          isDone: pantryItems > 0,
          step: HomeSetupStep.pantry,
        ),
        (
          label: 'Add somewhere you eat out',
          body: 'For the nights nobody is cooking.',
          isDone: places > 0,
          step: HomeSetupStep.places,
        ),
      ];
}

/// Where a setup step sends you.
enum HomeSetupStep { meals, pantry, places }

/// Home's second panel.
///
/// Everything is best-effort. A dashboard that fails is a panel that does not
/// appear; it must never be the reason Home does not load, because Home's actual
/// job is the button in the middle of it.
@riverpod
Future<HomeDashboard> homeDashboard(Ref ref) async {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime weekAgo = today.subtract(const Duration(days: 7));
  final DateTime monthAgo = today.subtract(const Duration(days: 30));
  final DateTime windowStart = today.subtract(const Duration(days: 7 * _weeks));

  final List<MealHistoryEntry> history =
      ref.watch(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

  final List<PantryItem> pantry =
      ref.watch(pantryControllerProvider).value ?? const <PantryItem>[];

  final Map<String, PantryMatch> matches =
      ref.watch(pantryMatchesProvider).value ?? const <String, PantryMatch>{};

  final List<GroceryItem> grocery =
      ref.watch(groceryControllerProvider).value ?? const <GroceryItem>[];

  final List<Restaurant> places =
      ref.watch(restaurantsControllerProvider).value ?? const <Restaurant>[];

  final List<Meal> library =
      ref.watch(mealsControllerProvider).value?.meals ?? const <Meal>[];

  // Nights out are read directly rather than through a provider, because nothing
  // else in the app watches them and a keepAlive provider with one reader is a
  // cache with no second reader. Wrapped, because migration 0025 may not be
  // applied yet — and a missing table must cost a chart, never the screen.
  List<RestaurantVisit> visits = const <RestaurantVisit>[];
  try {
    visits = await ref
        .read(restaurantHistoryRepositoryProvider)
        .recent(limit: _visitLookback);
  } on Object catch (error) {
    AppLog.warning(
      'Could not read nights out for the dashboard.',
      name: 'homeDashboard',
      data: <String, Object?>{'reason': error.toString()},
    );
  }

  // ---- the week ------------------------------------------------------------
  final List<MealHistoryEntry> cookedThisWeek = <MealHistoryEntry>[
    for (final MealHistoryEntry entry in history)
      if (entry.eatenAt.isAfter(weekAgo)) entry,
  ];
  final List<RestaurantVisit> outThisWeek = <RestaurantVisit>[
    for (final RestaurantVisit visit in visits)
      if (visit.eatenAt.isAfter(weekAgo)) visit,
  ];

  // Decisions with no price attached are left out of both the total and the
  // divisor, so an unpriced evening does not drag the average toward zero.
  final List<double> weekCosts = <double>[
    for (final MealHistoryEntry entry in cookedThisWeek)
      if (entry.costPerServing case final double cost) cost,
    for (final RestaurantVisit visit in outThisWeek)
      if (visit.actualCost ?? visit.estimatedCost case final double cost) cost,
  ];

  // ---- six weeks of spend --------------------------------------------------
  final List<double> cookedByWeek = List<double>.filled(_weeks, 0);
  final List<double> outByWeek = List<double>.filled(_weeks, 0);

  int? bucketFor(DateTime when) {
    if (when.isBefore(windowStart)) {
      return null;
    }
    final int daysAgo = today
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    final int index = _weeks - 1 - (daysAgo ~/ 7);
    return index >= 0 && index < _weeks ? index : null;
  }

  for (final MealHistoryEntry entry in history) {
    if (entry.costPerServing case final double cost) {
      if (bucketFor(entry.eatenAt) case final int index) {
        cookedByWeek[index] += cost;
      }
    }
  }
  for (final RestaurantVisit visit in visits) {
    if (visit.actualCost ?? visit.estimatedCost case final double cost) {
      if (bucketFor(visit.eatenAt) case final int index) {
        outByWeek[index] += cost;
      }
    }
  }

  // ---- cuisine mix ---------------------------------------------------------
  final Map<Cuisine, int> mix = <Cuisine, int>{};
  for (final MealHistoryEntry entry in history) {
    if (entry.eatenAt.isAfter(monthAgo) && entry.meal?.cuisine != null) {
      final Cuisine cuisine = entry.meal!.cuisine;
      mix[cuisine] = (mix[cuisine] ?? 0) + 1;
    }
  }
  for (final RestaurantVisit visit in visits) {
    if (visit.eatenAt.isAfter(monthAgo)) {
      mix[visit.cuisine] = (mix[visit.cuisine] ?? 0) + 1;
    }
  }

  return HomeDashboard(
    mealsCooked: cookedThisWeek.length,
    nightsOut: outThisWeek.length,
    averageCostPerHead: weekCosts.isEmpty
        ? null
        : weekCosts.reduce((double a, double b) => a + b) / weekCosts.length,
    cookableNow: matches.values
        .where((PantryMatch match) => match.isComplete)
        .length,
    needsUsing: pantry
        .where((PantryItem item) => item.statusAsOf(now).needsAttention)
        .length,
    stillToBuy: grocery.where((GroceryItem item) => !item.isCompleted).length,
    spend: <WeekSpend>[
      for (int index = 0; index < _weeks; index++)
        WeekSpend(
          weeksAgo: _weeks - 1 - index,
          cooked: cookedByWeek[index],
          eatenOut: outByWeek[index],
        ),
    ],
    cuisineMix: mix,
    ownMeals: library.where((Meal meal) => meal.isMine).length,
    pantryItems: pantry.length,
    places: places.length,
  );
}

/// Six. Enough to see a direction, few enough that each bar is wide enough to read
/// on a phone — twelve would be a smear.
const int _weeks = 6;

/// Enough nights out to cover six weeks comfortably.
const int _visitLookback = 60;
