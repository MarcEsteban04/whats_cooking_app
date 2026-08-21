import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// One thing narrowing a spin (Sprint 30).
///
/// Named as a *type* rather than left implicit in the field list, because the
/// no-match state has to talk about them: docs/USER_FLOWS.md §7 requires it to
/// name the blocking constraint and offer the single one whose relaxation opens
/// the most options. That is impossible to write against six nullable fields and
/// straightforward against a list of these.
enum SpinConstraint {
  budget('the budget'),
  time('the time limit'),
  cuisine('the cuisine'),
  category('the meal type'),
  difficulty('the difficulty'),

  /// Only meals this household wrote (Sprint 37).
  ///
  /// A constraint rather than a preference, unlike [SpinFilters.mood], because it
  /// genuinely can empty the pool — on a fresh install nothing has been written
  /// yet. So it has to be nameable in the no-match sentence and offerable as the
  /// one-tap relaxation, which is exactly what being in this enum buys.
  ours('your own meals'),

  /// Never relaxed, and that is the whole point of it being here.
  ///
  /// docs/PRD.md principle 3: producing a meal the user cannot eat is worse than
  /// producing none. A budget the app quietly stretched costs somebody twenty
  /// pesos; a dietary exclusion it quietly stretched costs them dinner, or worse.
  dietary('your dietary needs');

  const SpinConstraint(this.label);

  /// How the no-match state refers to it, mid-sentence.
  final String label;

  /// Whether the app may ever suggest dropping it.
  bool get isRelaxable => this != SpinConstraint.dietary;
}

/// What the roulette is allowed to offer (Sprint 30).
///
/// **Applied in Dart, not in the query, and that is deliberate here.** Every
/// other filter in this app is server-side because the feed is paged, and a
/// condition applied after a page arrives leaves the server and the app
/// disagreeing about what "the next twenty" means. The spin has no pages: it
/// asks for the whole eligible catalogue in one request and picks from it. That
/// changes the trade completely, and buys the one thing §7 actually demands —
/// exact answers to "how many meals would come back if I dropped *this*?", for
/// every filter at once, from one request rather than one probe per filter.
///
/// The dislikes and the session's own exclusions stay server-side, because those
/// are not filters the user is choosing between: they are the promise that a
/// hidden meal never appears (US-B-07), and it should not depend on this class
/// being called correctly.
///
/// Revisit when the catalogue is large enough that sending it costs something.
/// The honest fix then is scoring in SQL, which is where the recommendation
/// engine is heading anyway — not moving these six conditions into the query and
/// losing the diagnosis.
@immutable
class SpinFilters {
  const SpinFilters({
    this.maxCostPerServing,
    this.maxCookingTimeMinutes,
    this.cuisines = const <Cuisine>{},
    this.categories = const <MealCategory>{},
    this.difficulties = const <Difficulty>{},
    this.dietaryTags = const <DietaryTag>{},
    this.oursOnly = false,
    this.mood,
  });

  /// The user's settings as the starting point for every spin.
  ///
  /// docs/USER_FLOWS.md §6: budget and party size are always visible on Home so
  /// "the user never wonders what the app is about to assume". This is what makes
  /// that true — the spin assumes exactly what the profile says, and the sheet
  /// overrides it for one spin rather than editing the setting.
  ///
  /// Favourite cuisines are *not* carried over. A favourite is a preference the
  /// scoring engine should weight (Sprint 34); as a hard filter it would silently
  /// hide nine cuisines out of twelve from somebody who once tapped "Italian".
  factory SpinFilters.fromPreferences(FoodPreferences preferences) {
    return SpinFilters(
      maxCostPerServing: preferences.budget,
      maxCookingTimeMinutes: preferences.maxCookingTimeMinutes,
      dietaryTags: preferences.dietaryTags,
    );
  }

  /// Pesos a head, not per recipe — the number every budget question in this app
  /// means (see `Meal.costPerServing`).
  final int? maxCostPerServing;

  final int? maxCookingTimeMinutes;

  /// Empty means every cuisine, not none.
  final Set<Cuisine> cuisines;
  final Set<MealCategory> categories;
  final Set<Difficulty> difficulties;

  /// A meal must carry **all** of these to be offered.
  ///
  /// All, not any: somebody who is vegetarian *and* gluten-free needs both, and
  /// "any" would offer them a wheat-based vegetarian dish and call it a match.
  final Set<DietaryTag> dietaryTags;

  /// Whether the spin is restricted to meals we wrote ourselves (Sprint 37).
  ///
  /// The point of the app is that it spins over our library rather than over a
  /// catalogue somebody else chose. The catalogue is still there — it makes the
  /// app usable before the library fills up, and "Surprise me" needs breadth to
  /// surprise with — but this is the switch that says *tonight, only ours*.
  ///
  /// Off by default. On a fresh install it would empty the pool, and a first spin
  /// that finds nothing is the one failure this product cannot survive.
  final bool oursOnly;

  /// What the household is in the mood for tonight, or null (Sprint 36).
  ///
  /// **Deliberately not a [SpinConstraint], and it never blocks a meal.** Every
  /// other field here can empty the pool and therefore has to be relaxable and
  /// nameable in the no-match sentence. A mood cannot: it moves scores, so the
  /// pool it hands the scorer is exactly the pool it was given. Putting it in the
  /// constraint enum would offer readers a "drop the mood" button that opens
  /// nothing, and put it in a sentence explaining an emptiness it did not cause.
  ///
  /// It lives here anyway rather than in its own provider because it is a
  /// per-spin choice made on the same sheet, cleared by the same "clear all", and
  /// carried to the scorer alongside the budget and the time limit.
  final Mood? mood;

  /// Whether [meal] survives every filter here.
  ///
  /// [mood] is not consulted. See its own doc for why.
  bool allows(Meal meal) => _blockers(meal).isEmpty;

  /// Which of these filters [meal] fails.
  ///
  /// Every one rather than the first, because the count that matters to the
  /// no-match state is *how many meals a given filter is costing* — and a meal
  /// blocked by two filters is not evidence against either one on its own.
  Set<SpinConstraint> _blockers(Meal meal) {
    return <SpinConstraint>{
      if (maxCostPerServing case final int limit)
        if (meal.costPerServing > limit) SpinConstraint.budget,
      if (maxCookingTimeMinutes case final int limit)
        if (meal.cookingTimeMinutes > limit) SpinConstraint.time,
      if (cuisines.isNotEmpty && !cuisines.contains(meal.cuisine))
        SpinConstraint.cuisine,
      if (categories.isNotEmpty && !categories.contains(meal.category))
        SpinConstraint.category,
      if (difficulties.isNotEmpty && !difficulties.contains(meal.difficulty))
        SpinConstraint.difficulty,
      // `isPublic` rather than a household comparison: RLS already returns only
      // "public, or my household's", so anything not public is ours by
      // construction and the client never needs to know its own household id.
      if (oursOnly && meal.isPublic) SpinConstraint.ours,
      if (!meal.dietaryTags.containsAll(dietaryTags)) SpinConstraint.dietary,
    };
  }

  /// The constraints currently narrowing anything.
  Set<SpinConstraint> get active => <SpinConstraint>{
    if (maxCostPerServing != null) SpinConstraint.budget,
    if (maxCookingTimeMinutes != null) SpinConstraint.time,
    if (cuisines.isNotEmpty) SpinConstraint.cuisine,
    if (categories.isNotEmpty) SpinConstraint.category,
    if (difficulties.isNotEmpty) SpinConstraint.difficulty,
    if (oursOnly) SpinConstraint.ours,
    if (dietaryTags.isNotEmpty) SpinConstraint.dietary,
  };

  /// How many the sheet's badge shows.
  ///
  /// Dietary is excluded: it is not a filter the reader chose in the sheet and
  /// cannot clear from it, so counting it would make "3 filters" un-clearable
  /// down to zero and read as a bug.
  int get chosenCount =>
      active.where((SpinConstraint c) => c.isRelaxable).length;

  bool get hasChosen => chosenCount > 0;

  /// The same filters with [constraint] dropped.
  ///
  /// The tool the no-match analysis is built on: it asks this for each active
  /// constraint and counts what comes back.
  SpinFilters without(SpinConstraint constraint) {
    return switch (constraint) {
      SpinConstraint.budget => copyWith(clearBudget: true),
      SpinConstraint.time => copyWith(clearTime: true),
      SpinConstraint.cuisine => copyWith(cuisines: const <Cuisine>{}),
      SpinConstraint.category => copyWith(categories: const <MealCategory>{}),
      SpinConstraint.difficulty => copyWith(difficulties: const <Difficulty>{}),
      SpinConstraint.ours => copyWith(oursOnly: false),
      // Deliberately unreachable through the analysis, which only ever asks
      // about relaxable constraints. Honoured here so the switch is total and a
      // future caller cannot get a silently unchanged object back.
      SpinConstraint.dietary => copyWith(dietaryTags: const <DietaryTag>{}),
    };
  }

  /// Drops everything the reader chose, keeping what they did not.
  ///
  /// Dietary survives a "clear all", because clearing filters is a request to
  /// widen the search and not a declaration that the reader has stopped being
  /// vegetarian.
  SpinFilters cleared() => SpinFilters(dietaryTags: dietaryTags);

  /// How this constraint currently reads, for the no-match sentence.
  ///
  /// Concrete numbers rather than the generic label where there is a number to
  /// give: §7's example is *"Nothing under ₱150 that also takes under 20
  /// minutes"*, and "nothing matching the budget" is not that sentence.
  String describe(SpinConstraint constraint) {
    return switch (constraint) {
      SpinConstraint.budget =>
        'under ${AppFormat.peso(maxCostPerServing ?? 0)} a head',
      SpinConstraint.time =>
        'ready in ${AppFormat.cookingTime(maxCookingTimeMinutes ?? 0)}',
      SpinConstraint.cuisine => _list(cuisines.map((Cuisine c) => c.label)),
      // Carries its own preposition so the no-match sentence reads "Nothing for
      // dinner that is also under ₱100 a head" rather than "Nothing dinner".
      SpinConstraint.category =>
        'for ${_list(categories.map((MealCategory c) => c.label.toLowerCase()))}',
      SpinConstraint.difficulty => _list(
        difficulties.map((Difficulty d) => d.label.toLowerCase()),
      ),
      // Reads as "Nothing of your own that is also under ₱150 a head", which is
      // the sentence §7 wants — it names the filter in the reader's own terms
      // rather than saying "no results".
      SpinConstraint.ours => 'of your own',
      SpinConstraint.dietary => _list(
        dietaryTags.map((DietaryTag t) => t.label.toLowerCase()),
      ),
    };
  }

  SpinFilters copyWith({
    int? maxCostPerServing,
    int? maxCookingTimeMinutes,
    Set<Cuisine>? cuisines,
    Set<MealCategory>? categories,
    Set<Difficulty>? difficulties,
    bool? oursOnly,
    Mood? mood,
    Set<DietaryTag>? dietaryTags,
    bool clearBudget = false,
    bool clearTime = false,
    bool clearMood = false,
  }) {
    return SpinFilters(
      // The explicit clear flags exist because null is a meaningful value here:
      // `copyWith(maxCostPerServing: null)` cannot mean both "leave it" and
      // "remove it" (the same reason `FoodPreferences` has them).
      maxCostPerServing: clearBudget
          ? null
          : maxCostPerServing ?? this.maxCostPerServing,
      maxCookingTimeMinutes: clearTime
          ? null
          : maxCookingTimeMinutes ?? this.maxCookingTimeMinutes,
      cuisines: cuisines ?? this.cuisines,
      categories: categories ?? this.categories,
      difficulties: difficulties ?? this.difficulties,
      oursOnly: oursOnly ?? this.oursOnly,
      mood: clearMood ? null : (mood ?? this.mood),
      dietaryTags: dietaryTags ?? this.dietaryTags,
    );
  }

  /// `Italian`, `Italian or Thai`, `Italian, Thai or Korean`.
  static String _list(Iterable<String> parts) {
    final List<String> items = parts.toList();
    if (items.isEmpty) {
      return '';
    }
    if (items.length == 1) {
      return items.single;
    }
    return '${items.take(items.length - 1).join(', ')} or ${items.last}';
  }

  @override
  bool operator ==(Object other) =>
      other is SpinFilters &&
      other.maxCostPerServing == maxCostPerServing &&
      other.maxCookingTimeMinutes == maxCookingTimeMinutes &&
      setEquals(other.cuisines, cuisines) &&
      setEquals(other.categories, categories) &&
      setEquals(other.difficulties, difficulties) &&
      other.oursOnly == oursOnly &&
      other.mood == mood &&
      setEquals(other.dietaryTags, dietaryTags);

  @override
  int get hashCode => Object.hash(
    maxCostPerServing,
    maxCookingTimeMinutes,
    Object.hashAllUnordered(cuisines),
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(difficulties),
    oursOnly,
    mood,
    Object.hashAllUnordered(dietaryTags),
  );

  /// The budget steps the sheet offers, per head.
  ///
  /// `AppConstants.budgetPresets` are whole-meal figures from onboarding; these
  /// are per head, because that is what the filter compares and offering ₱500 a
  /// head as a "budget" would be absurd.
  static const List<int> budgetSteps = <int>[75, 100, 150, 250];

  /// The time steps the sheet offers, in minutes.
  static const List<int> timeSteps = <int>[15, 30, 45, 60];
}
