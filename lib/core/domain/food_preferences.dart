import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// What a user has told the app about how they eat.
///
/// One model, shared: onboarding captures it and the profile screen edits it.
/// docs/COMPONENTS.md §18b is explicit about why that matters — "a user must meet
/// the same cuisine grid on day one and on day thirty" — and two copies of these
/// six fields would drift the moment one gained a seventh.
///
/// **Every field is nullable or empty-able.** Onboarding steps are skippable, and
/// a profile can be edited back to "no preference", so *unset* has to be
/// representable and distinguishable from *set to nothing*. A null budget means
/// no preference; the recommendation engine treats that very differently from a
/// budget of zero.
class FoodPreferences {
  const FoodPreferences({
    this.favouriteCuisines = const <Cuisine>{},
    this.dislikedFoods = const <String>[],
    this.dietaryTags = const <DietaryTag>{},
    this.budget,
    this.maxCookingTimeMinutes,
    this.cookingFor,
  });

  final Set<Cuisine> favouriteCuisines;

  /// Foods to avoid, as the user typed them.
  ///
  /// Free text, not ingredient ids. `user_preferences.disliked_ingredients`
  /// holds ids, which is the right long-term shape, but the catalogue cannot
  /// match what someone types on their first day — so names live in
  /// `disliked_ingredient_names` and are reconciled later
  /// (supabase/migrations/…_onboarding_dislikes.sql).
  final List<String> dislikedFoods;

  final Set<DietaryTag> dietaryTags;

  /// Null means no budget preference, which is not the same as zero.
  final int? budget;

  /// Null means no time limit.
  final int? maxCookingTimeMinutes;

  final CookingFor? cookingFor;

  /// Servings to store, defaulting to the product's assumption of two.
  int get preferredServings =>
      cookingFor?.servings ?? AppConstants.defaultPartySize;

  /// Whether anything has been set.
  ///
  /// docs/USER_FLOWS.md §5's bar for onboarding: an abandoned run should still
  /// leave the app smarter than a blank one.
  bool get hasAny =>
      favouriteCuisines.isNotEmpty ||
      dislikedFoods.isNotEmpty ||
      dietaryTags.isNotEmpty ||
      budget != null ||
      maxCookingTimeMinutes != null ||
      cookingFor != null;

  FoodPreferences copyWith({
    Set<Cuisine>? favouriteCuisines,
    List<String>? dislikedFoods,
    Set<DietaryTag>? dietaryTags,
    int? budget,
    int? maxCookingTimeMinutes,
    CookingFor? cookingFor,
    bool clearBudget = false,
    bool clearMaxCookingTime = false,
  }) {
    return FoodPreferences(
      favouriteCuisines: favouriteCuisines ?? this.favouriteCuisines,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      // Explicit clears, because `copyWith(budget: null)` cannot mean "unset" in
      // Dart — null is indistinguishable from "not passed". Choosing "no budget
      // in mind" has to be able to clear a previously chosen one.
      budget: clearBudget ? null : (budget ?? this.budget),
      maxCookingTimeMinutes: clearMaxCookingTime
          ? null
          : (maxCookingTimeMinutes ?? this.maxCookingTimeMinutes),
      cookingFor: cookingFor ?? this.cookingFor,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodPreferences &&
        _sameSet(other.favouriteCuisines, favouriteCuisines) &&
        _sameList(other.dislikedFoods, dislikedFoods) &&
        _sameSet(other.dietaryTags, dietaryTags) &&
        other.budget == budget &&
        other.maxCookingTimeMinutes == maxCookingTimeMinutes &&
        other.cookingFor == cookingFor;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(favouriteCuisines),
    Object.hashAll(dislikedFoods),
    Object.hashAllUnordered(dietaryTags),
    budget,
    maxCookingTimeMinutes,
    cookingFor,
  );

  /// Value equality over the collections, not identity.
  ///
  /// Needed because the profile screen compares edited preferences against the
  /// saved ones to decide whether there is anything to save — and two sets with
  /// the same contents are the same answer.
  static bool _sameSet<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
