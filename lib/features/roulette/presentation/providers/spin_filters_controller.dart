import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';

part 'spin_filters_controller.g.dart';

/// What the reader has chosen to narrow the next spin by (Sprint 30).
///
/// **A per-spin scratchpad, not a setting.** The sheet edits this and nothing
/// here writes back to the profile: tightening the budget for one evening should
/// not silently change what the app assumes next week.
///
/// Budget and time are seeded from the profile once, with `read` rather than
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

  /// Replaces the lot — used by the no-match state's one-tap relaxation.
  void replace(SpinFilters filters) => state = filters;

  /// Drops everything the reader chose.
  void clear() => state = const SpinFilters();

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
