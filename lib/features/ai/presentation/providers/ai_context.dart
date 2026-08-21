import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';

/// What the assistant is told about this household (Sprint 47, extracted 48).
///
/// **One definition, used by every purpose.** It began inside the chat
/// controller, and the moment a second feature needed the same facts — the recipe
/// writer, which has to respect the same dietary needs and the same budget — two
/// copies would have started drifting, and the drift would show up as the AI
/// honouring an allergy in the chat and forgetting it in a recipe.
///
/// A plain function over a [Ref] rather than a provider, deliberately. Every call
/// site wants a *snapshot at the moment of asking*, which is `ref.read` semantics;
/// a provider would either rebuild on every pantry edit or need invalidating by
/// hand, and neither buys anything when the result is immediately serialised into
/// a request body.
///
/// **Chosen, not dumped.** Every value is capped at 300 characters by the Edge
/// Function, and more importantly every value costs tokens on every turn — so this
/// sends the facts that change an answer and nothing else.
///
/// The two lists worth explaining:
///
/// * **`can_cook_now`** is what the pantry already covers. This is the single most
///   useful thing the app knows and the reason the assistant can answer "we only
///   have chicken and eggs" without being told.
/// * **`some_of_our_meals`** is a *sample*, not the library. Sixty names would blow
///   the cap and spend tokens listing food nobody asked about; a dozen is enough to
///   teach the model what kind of food this household eats, which is what stops it
///   inventing a recipe for something they have never cooked.
///
/// Nothing here is a name or an address. The household's own food is not PII, and
/// the display name is deliberately absent — the assistant has no use for it and a
/// prompt is not a place to put one.
Map<String, Object?> householdAiContext(Ref ref) {
  final FoodPreferences? preferences = ref
      .read(profileControllerProvider)
      .value
      ?.preferences;

  final List<PantryItem> pantry =
      ref.read(pantryControllerProvider).value ?? const <PantryItem>[];

  final Map<String, PantryMatch> matches =
      ref.read(pantryMatchesProvider).value ?? const <String, PantryMatch>{};

  final List<Meal> library =
      ref.read(mealsControllerProvider).value?.meals ?? const <Meal>[];

  final Map<String, Meal> byId = <String, Meal>{
    for (final Meal meal in library) meal.id: meal,
  };

  final List<MealHistoryEntry> history =
      ref.read(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

  return <String, Object?>{
    if (preferences?.budget case final int budget)
      'budget_per_head_pesos': budget,
    if (preferences?.maxCookingTimeMinutes case final int minutes)
      'max_cooking_minutes': minutes,
    'cooking_for': preferences?.preferredServings,
    if (preferences?.dietaryTags.isNotEmpty ?? false)
      'dietary_needs': preferences!.dietaryTags
          .map((DietaryTag tag) => tag.label)
          .join(', '),
    if (preferences?.dislikedFoods.isNotEmpty ?? false)
      'foods_to_avoid': preferences!.dislikedFoods.join(', '),
    if (preferences?.favouriteCuisines.isNotEmpty ?? false)
      'cuisines_they_like': preferences!.favouriteCuisines
          .map((Cuisine cuisine) => cuisine.label)
          .join(', '),

    if (pantry.isNotEmpty)
      'in_the_kitchen': _capped(
        pantry.map((PantryItem item) => item.name),
        _pantryNames,
      ),

    if (matches.isNotEmpty)
      'can_cook_now': _capped(<String>[
        for (final MapEntry<String, PantryMatch> entry in matches.entries)
          if (entry.value.isComplete && byId[entry.key] != null)
            byId[entry.key]!.name,
      ], _cookableNames),

    'eaten_recently': _capped(<String>[
      for (final MealHistoryEntry entry in history)
        if (entry.meal?.name case final String name) name,
    ], _recentCount),

    if (library.isNotEmpty)
      'some_of_our_meals': _capped(
        library.map((Meal meal) => meal.name),
        _librarySample,
      ),
  };
}

/// The first [limit] of [names], joined — or null when there are none.
///
/// Null rather than an empty string, because the function skips empty values and
/// "in_the_kitchen: " with nothing after it is a line that makes the model think
/// the kitchen is empty rather than unknown.
String? _capped(Iterable<String> names, int limit) {
  final List<String> taken = names.take(limit).toList();
  return taken.isEmpty ? null : taken.join(', ');
}

/// Enough to answer "what can I make with this", short enough not to be a
/// shopping inventory.
const int _pantryNames = 20;

/// The whole point of the pantry, so it gets the most room.
const int _cookableNames = 12;

/// A week's worth. Past that it stops informing "not that again".
const int _recentCount = 7;

/// A sample, to teach the model what kind of food this is. Not the library.
const int _librarySample = 12;
