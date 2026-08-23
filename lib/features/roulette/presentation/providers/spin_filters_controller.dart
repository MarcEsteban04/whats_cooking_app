import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';

part 'spin_filters_controller.g.dart';

/// What the reader has chosen to narrow the next spin by (Sprint 30).
///
/// **A per-spin scratchpad, not a setting.** The sheet edits this and nothing
/// here writes back to the profile: tightening the budget for one evening should
/// not silently change what the app assumes next week.
///
/// Budget, time and effort are seeded from the profile once, with `read` rather than
/// `watch`, so this notifier never rebuilds and can therefore never lose an edit
/// the reader has just made. If the profile has not loaded yet the seed is
/// skipped, which errs toward a *wider* spin — and the one filter where wider
/// would be dangerous is not stored here at all. See [spinFilters].
@Riverpod(keepAlive: true)
class SpinFiltersController extends _$SpinFiltersController {
  @override
  SpinFilters build() {
    final FoodPreferences? preferences = ref
        .read(profileControllerProvider)
        .value
        ?.preferences;

    if (preferences == null) {
      return const SpinFilters();
    }

    // Dietary tags are deliberately not seeded here — [spinFilters] layers them
    // on every read so they cannot go stale.
    return SpinFilters(
      maxCostPerServing: preferences.budget,
      maxCookingTimeMinutes: preferences.maxCookingTimeMinutes,
      difficulties: _upTo(preferences.maxDifficulty),
    );
  }

  /// Null clears the limit — the sheet's "Any" chip.
  void setBudget(int? pesosPerHead) => state = pesosPerHead == null
      ? state.copyWith(clearBudget: true)
      : state.copyWith(maxCostPerServing: pesosPerHead);

  void setMaxTime(int? minutes) => state = minutes == null
      ? state.copyWith(clearTime: true)
      : state.copyWith(maxCookingTimeMinutes: minutes);

  void toggleCuisine(Cuisine cuisine) =>
      state = state.copyWith(cuisines: _toggled(state.cuisines, cuisine));

  void toggleCategory(MealCategory category) =>
      state = state.copyWith(categories: _toggled(state.categories, category));

  void toggleDifficulty(Difficulty difficulty) => state = state.copyWith(
    difficulties: _toggled(state.difficulties, difficulty),
  );

  /// Restricts the spin to meals we wrote, or opens it back up (Sprint 37).
  void setOursOnly(bool oursOnly) => state = state.copyWith(oursOnly: oursOnly);

  /// How much of a meal the kitchen has to cover (Sprint 54).
  void setPantryReach(PantryReach reach) =>
      state = state.copyWith(pantryReach: reach);

  /// Tapping the chosen mood again clears it (Sprint 36).
  ///
  /// One mood at a time. Two would need a rule for what "healthy and junk food"
  /// means, and there isn't one — the tag sets contradict each other by design.
  void setMood(Mood? mood) => state = mood == null || state.mood == mood
      ? state.copyWith(clearMood: true)
      : state.copyWith(mood: mood);

  /// Replaces the lot — used by the no-match state's one-tap relaxation.
  void replace(SpinFilters filters) => state = filters;

  /// Drops everything the reader chose.
  void clear() => state = const SpinFilters();

  /// Every difficulty at or below [ceiling] (Sprint 35).
  ///
  /// The preference is stored as a ceiling because that is how people hold it —
  /// "nothing hard" — while the filter is a set, because the sheet lets somebody
  /// tick individual levels for one evening. This is the one place the two shapes
  /// meet, and it relies on [Difficulty] being declared easiest-first.
  ///
  /// An empty set for no preference, which is what [SpinFilters] already reads as
  /// "do not filter on this" — and for `hard`, which today means the same thing.
  /// Left as a real answer rather than special-cased to null so that adding a
  /// fourth level above it does the right thing without anybody remembering to
  /// come back here.
  static Set<Difficulty> _upTo(Difficulty? ceiling) {
    if (ceiling == null) {
      return const <Difficulty>{};
    }
    final Set<Difficulty> allowed = <Difficulty>{
      for (final Difficulty level in Difficulty.values)
        if (level.index <= ceiling.index) level,
    };
    // All of them is not a filter. Returning the full set would light up the
    // sheet's difficulty chips and put "the difficulty" in the no-match
    // sentence for a constraint that is excluding nothing.
    return allowed.length == Difficulty.values.length
        ? const <Difficulty>{}
        : allowed;
  }

  static Set<T> _toggled<T>(Set<T> current, T value) {
    final Set<T> next = current.toSet();
    if (!next.remove(value)) {
      next.add(value);
    }
    return next;
  }
}

/// The filters a spin actually runs with.
///
/// The reader's choices, plus their dietary needs taken fresh from the profile
/// every read. That split is the point: dietary is the one filter where being
/// out of date is not a stale default but a meal somebody cannot eat, so it is
/// **derived rather than stored** — it cannot be missed by a seeding race, left
/// behind by a rebuild, or cleared by "clear all".
///
/// docs/PRD.md principle 3: producing a meal the user cannot eat is worse than
/// producing none.
@riverpod
SpinFilters spinFilters(Ref ref) {
  final SpinFilters chosen = ref.watch(spinFiltersControllerProvider);
  final Set<DietaryTag> dietary =
      ref.watch(profileControllerProvider).value?.preferences.dietaryTags ??
      const <DietaryTag>{};

  return chosen.copyWith(dietaryTags: dietary);
}
