import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// How the feed is ordered.
///
/// Every option is a *total* order, because pagination depends on it. Two rows
/// that compare equal can swap places between one page request and the next, and
/// the reader sees a meal twice while another never appears at all. Every sort
/// here therefore falls back to the id — see [MealSort.tiebreaker].
enum MealSort {
  /// A–Z. The default, and deliberately not "recommended": ranking needs the
  /// scoring engine from Sprint 30, and a feed that claims to recommend while
  /// sorting alphabetically is worse than one that admits it.
  alphabetical('Name, A to Z', 'name', ascending: true),

  quickest('Quickest first', 'cooking_time_minutes', ascending: true),

  /// Per head, not per recipe (see `Meal.costPerServing`).
  cheapest('Cheapest first', 'cost_per_serving', ascending: true),

  newest('Newest first', 'created_at', ascending: false);

  const MealSort(this.label, this.column, {required this.ascending});

  final String label;

  /// The `meals` column to order by.
  final String column;
  final bool ascending;

  /// The column that breaks a tie, so the order is total.
  static const String tiebreaker = 'id';
}

/// Everything that narrows the meal feed.
///
/// One value object rather than a bag of arguments: the controller compares a
/// new query against the old one to decide whether to reset to the first page,
/// and that comparison has to be by value.
///
/// Filters are **additive**, and there is always a way to clear them all
/// (docs/USER_FLOWS.md §7).
@immutable
class MealQuery {
  const MealQuery({
    this.search = '',
    this.cuisines = const <Cuisine>{},
    this.categories = const <MealCategory>{},
    this.maxCookingTimeMinutes,
    this.maxCostPerServing,
    this.sort = MealSort.alphabetical,
    this.excludedMealIds = const <String>{},
    this.onlyMealIds,
  });

  /// Matched against the meal's name.
  ///
  /// Name only, and that is a decision rather than an omission: `meals` carries
  /// a trigram index on `name` (migration 0008), so this is the one field that
  /// searches without a table scan. Mood and cuisine are reachable through the
  /// filter pills, which is a better answer for them than free text anyway.
  final String search;

  final Set<Cuisine> cuisines;
  final Set<MealCategory> categories;

  /// The "something quick" pill (docs/design_ui.md §16).
  final int? maxCookingTimeMinutes;

  /// The "budget" pill. Pesos per head.
  final int? maxCostPerServing;

  final MealSort sort;

  /// Meals the feed must not return, whatever else matches.
  ///
  /// The user's dislikes (Sprint 25). Carried in the query rather than applied
  /// to the rows afterwards, because a condition applied in Dart after a page
  /// arrives leaves the server and the app disagreeing about what "the next
  /// twenty" means — the same reason every other filter here is server-side.
  ///
  /// **Not a filter**, and the three members below say so: it does not make
  /// [hasFilters] true, it is not counted in [filterCount], [narrowestFilterLabel]
  /// never names it, and [cleared] keeps it. "Clear filters" must not un-hide
  /// food the user chose to hide.
  final Set<String> excludedMealIds;

  /// When set, the *only* meals allowed through (Sprint 41).
  ///
  /// The inverse of [excludedMealIds], and it exists for one filter: "what can we
  /// cook right now". That question is answered by a Postgres function over the
  /// pantry, not by anything a PostgREST predicate can express — so the answer
  /// comes back as a set of ids and is applied here.
  ///
  /// **Null and empty mean different things.** Null is "no such filter"; an empty
  /// set is "the filter is on and nothing qualifies", which has to show an empty
  /// feed rather than the whole catalogue.
  final Set<String>? onlyMealIds;

  /// Whether the cookable-now filter is on.
  bool get isCookableOnly => onlyMealIds != null;

  /// Whether anything is narrowing the feed.
  ///
  /// Drives the clear-all affordance, which §7 requires whenever a filter is on.
  bool get hasFilters =>
      search.isNotEmpty ||
      cuisines.isNotEmpty ||
      categories.isNotEmpty ||
      maxCookingTimeMinutes != null ||
      maxCostPerServing != null ||
      isCookableOnly;

  /// How many filters are on, for the badge on the filter button.
  int get filterCount =>
      cuisines.length +
      categories.length +
      (maxCookingTimeMinutes == null ? 0 : 1) +
      (maxCostPerServing == null ? 0 : 1);

  /// The narrowest filter, named — for the empty state.
  ///
  /// §7: "An empty result set offers to relax the narrowest filter." Which one
  /// that is cannot be computed from the query alone, so this is a stated
  /// priority: the search text first, because it is the most specific thing the
  /// user typed and the easiest for them to have mistyped.
  String? get narrowestFilterLabel {
    if (search.isNotEmpty) {
      return 'the search for "$search"';
    }
    if (maxCostPerServing != null) {
      return 'the budget limit';
    }
    if (maxCookingTimeMinutes != null) {
      return 'the time limit';
    }
    if (cuisines.length == 1) {
      return 'the ${cuisines.single.label} filter';
    }
    if (categories.length == 1) {
      return 'the ${categories.single.label} filter';
    }
    if (cuisines.isNotEmpty || categories.isNotEmpty) {
      return 'a filter';
    }
    return null;
  }

  /// Drops every filter.
  ///
  /// Two things survive on purpose. The sort, because it is a preference about
  /// how to read the feed rather than a filter hiding food. And
  /// [excludedMealIds], because those are meals the user asked never to see
  /// again — "clear filters" is not consent to bring them back.
  MealQuery cleared() =>
      MealQuery(sort: sort, excludedMealIds: excludedMealIds);

  MealQuery copyWith({
    String? search,
    Set<Cuisine>? cuisines,
    Set<MealCategory>? categories,
    int? maxCookingTimeMinutes,
    int? maxCostPerServing,
    MealSort? sort,
    Set<String>? excludedMealIds,
    Set<String>? onlyMealIds,
    bool clearMaxCookingTime = false,
    bool clearMaxCost = false,
    bool clearCookableOnly = false,
  }) {
    return MealQuery(
      search: search ?? this.search,
      cuisines: cuisines ?? this.cuisines,
      categories: categories ?? this.categories,
      // The explicit clear flags exist because null is a meaningful value here:
      // `copyWith(maxCostPerServing: null)` cannot mean both "leave it" and
      // "remove it" (the same reason `FoodPreferences` has them).
      maxCookingTimeMinutes: clearMaxCookingTime
          ? null
          : maxCookingTimeMinutes ?? this.maxCookingTimeMinutes,
      maxCostPerServing: clearMaxCost
          ? null
          : maxCostPerServing ?? this.maxCostPerServing,
      sort: sort ?? this.sort,
      excludedMealIds: excludedMealIds ?? this.excludedMealIds,
      onlyMealIds: clearCookableOnly
          ? null
          : (onlyMealIds ?? this.onlyMealIds),
    );
  }

  /// Adds or removes one cuisine.
  MealQuery toggleCuisine(Cuisine cuisine) {
    return copyWith(
      cuisines: cuisines.contains(cuisine)
          ? (cuisines.toSet()..remove(cuisine))
          : (cuisines.toSet()..add(cuisine)),
    );
  }

  MealQuery toggleCategory(MealCategory category) {
    return copyWith(
      categories: categories.contains(category)
          ? (categories.toSet()..remove(category))
          : (categories.toSet()..add(category)),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealQuery &&
        other.search == search &&
        setEquals(other.cuisines, cuisines) &&
        setEquals(other.categories, categories) &&
        other.maxCookingTimeMinutes == maxCookingTimeMinutes &&
        other.maxCostPerServing == maxCostPerServing &&
        other.sort == sort &&
        // Part of equality, which is what makes hiding a meal reload the feed:
        // `MealsController` compares the new query against the old one to decide
        // whether to go back to page one, and a changed exclusion set is exactly
        // that kind of change.
        setEquals(other.excludedMealIds, excludedMealIds);
  }

  @override
  int get hashCode => Object.hash(
    search,
    Object.hashAllUnordered(cuisines),
    Object.hashAllUnordered(categories),
    maxCookingTimeMinutes,
    maxCostPerServing,
    sort,
    Object.hashAllUnordered(excludedMealIds),
  );

  @override
  String toString() =>
      'MealQuery(search: "$search", cuisines: ${cuisines.length}, '
      'categories: ${categories.length}, maxTime: $maxCookingTimeMinutes, '
      'maxCost: $maxCostPerServing, sort: ${sort.name}, '
      'excluded: ${excludedMealIds.length})';
}
