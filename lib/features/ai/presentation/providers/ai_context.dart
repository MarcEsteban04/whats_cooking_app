import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/home/presentation/providers/home_dashboard.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';
part 'ai_context.g.dart';

/// What the assistant is told about this household (Sprint 47, extracted 48,
/// widened 50).
///
/// **One definition, used by every purpose.** It began inside the chat
/// controller, and the moment a second feature needed the same facts — the recipe
/// writer, which has to respect the same dietary needs and the same budget — two
/// copies would have started drifting, and the drift would show up as the AI
/// honouring an allergy in the chat and forgetting it in a recipe.
///
/// A plain function rather than a provider, deliberately. Every call site wants a
/// *snapshot at the moment of asking*, which is `ref.read` semantics; a provider
/// would either rebuild on every pantry edit or need invalidating by hand, and
/// neither buys anything when the result is immediately serialised into a request
/// body.
///
/// A `Ref`, which a widget does not have — so [householdAiSnapshot] wraps it for
/// the one caller that is a widget rather than a notifier. `Ref` and `WidgetRef`
/// are unrelated types with an identically-shaped `read`, and threading a reader
/// closure through instead defeats generic inference on every notifier provider
/// below.
///
/// ## What goes in, and the arithmetic behind it
///
/// **Chosen, not dumped.** Sprint 50's line in the roadmap is "feed the assistant
/// everything the app knows … bounded deliberately. Context is tokens and tokens
/// are money." Sixteen short lines is roughly 300 tokens on *every* turn of every
/// conversation, so each one has to earn its place by changing an answer:
///
/// * **`in_the_kitchen` / `can_cook_now`** — the pantry, and the meals it already
///   covers. The single most useful thing the app knows, and the reason the
///   assistant can answer "we only have chicken and eggs" without being told.
/// * **`going_off_soon`** — the urgent shelf (Sprint 50). Arguably the most
///   actionable line here and it was missing: a model that knows there is fish to
///   use tonight gives a different answer from one that knows there is fish.
/// * **`usually_spends_per_head` beside `budget_per_head_pesos`** — what is
///   *stated* next to what actually happens. A household with a ₱200 budget that
///   spends ₱90 is not asking for a ₱200 dinner.
/// * **`recent_cuisines`** — the observed mix over thirty days, with counts. The
///   heart of Sprint 50: `cuisines_they_like` is what somebody typed once, and
///   this is what they have eaten. When the two disagree, the second one is true.
/// * **`this_week`** — cooked against eaten out. "You have already been out
///   twice" is a sentence only this line makes possible.
/// * **`places_we_go`** — the restaurant list, so "we cannot face cooking" gets
///   real names instead of a suggestion to look somewhere up.
/// * **`some_of_our_meals`** — a *sample*, not the library. Sixty names would blow
///   the cap and spend tokens listing food nobody asked about; a dozen is enough
///   to teach the model what kind of food this household eats.
///
/// Two things deliberately left out. **Hidden meals** are excluded by the query
/// before a candidate list is ever built, so naming them again would spend tokens
/// restating a filter that already ran — and resolving hidden *ids* to names needs
/// the very rows the feed excludes. **Previous conversations** are not summarised
/// into a line either; the chat carries its own turns, and a summary would cost a
/// second AI call to produce something the transcript already says.
///
/// Nothing here is a name or an address. The household's own food is not PII, and
/// the display name is deliberately absent — the assistant has no use for it and a
/// prompt is not a place to put one.
Future<Map<String, Object?>> householdAiContext(Ref ref) async {
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

  final List<Restaurant> places =
      ref.read(restaurantsControllerProvider).value ?? const <Restaurant>[];

  final Map<String, Meal> byId = <String, Meal>{
    for (final Meal meal in library) meal.id: meal,
  };

  final List<MealHistoryEntry> history =
      ref.read(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

  // What the household actually does, rather than what it said it would.
  //
  // **Read through the dashboard rather than recomputed here** (Sprint 50). Home
  // already turns history, spend and nights out into exactly these numbers, and a
  // second implementation of "what we usually spend" would drift from the chart
  // that shows it — so the assistant and the chart would disagree about the same
  // household. Awaited because it fetches nights out; a failure costs the observed
  // lines and never the question.
  HomeDashboard? observed;
  try {
    observed = await ref.read(homeDashboardProvider.future);
  } on Object catch (error) {
    AppLog.debug(
      'Assistant context without the observed figures.',
      name: _logName,
      data: <String, Object?>{'reason': error.runtimeType.toString()},
    );
  }

  final DateTime now = DateTime.now();

  final Map<String, Object?> context = <String, Object?>{
    if (preferences?.budget case final int budget)
      'budget_per_head_pesos': budget,
    if (observed?.averageCostPerHead case final double spend)
      'usually_spends_per_head': spend.round(),
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

    // The urgent shelf, separately from the rest of the kitchen. Buried in a list
    // of twenty names it is invisible; on its own line it is the thing to cook.
    'going_off_soon': _capped(<String>[
      for (final PantryItem item in pantry)
        if (item.statusAsOf(now).needsAttention) item.name,
    ], _urgentNames),

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

    if (observed case final HomeDashboard week) ...<String, Object?>{
      'recent_cuisines': _cuisineMix(week.cuisineMix),
      if (week.decisions > 0)
        'this_week': 'cooked ${week.mealsCooked}, ate out ${week.nightsOut}',
    },

    if (places.isNotEmpty)
      'places_we_go': _capped(<String>[
        for (final Restaurant place in places) _describePlace(place),
      ], _placeNames),

    if (library.isNotEmpty)
      'some_of_our_meals': _capped(
        library.map((Meal meal) => meal.name),
        _librarySample,
      ),
  };

  // Removed here rather than guarded at every entry, because half of these are
  // "null when there is nothing" by construction and the other half would need an
  // `isNotEmpty` check that says the same thing twice.
  context.removeWhere((String _, Object? value) => value == null);

  AppLog.debug(
    'Assistant context assembled.',
    name: _logName,
    // The keys and the size, never the values. The values are what is in
    // somebody's fridge.
    data: <String, Object?>{
      'facts': context.length,
      'chars': context.values.fold<int>(
        0,
        (int total, Object? value) => total + value.toString().length,
      ),
    },
  );

  return context;
}

/// `Butao (japanese, walk)`.
///
/// Cuisine and distance, because those are the two things that decide it. Cost is
/// left off: the household's real spend is already its own line, and a price per
/// place would double this value's length for a figure the model rarely needs.
String _describePlace(Restaurant place) {
  final String cuisine = place.cuisine.label.toLowerCase();
  final String distance = place.proximity.label.toLowerCase();
  return '${place.name} ($cuisine, $distance)';
}

/// `filipino 8, chinese 5, japanese 2`, biggest first.
///
/// Counts rather than a bare list, because "mostly Filipino with the odd Chinese"
/// and "half and half" are different households and only the numbers say which.
String? _cuisineMix(Map<Cuisine, int> mix) {
  if (mix.isEmpty) {
    return null;
  }

  final List<MapEntry<Cuisine, int>> ranked = mix.entries.toList()
    ..sort(
      (MapEntry<Cuisine, int> a, MapEntry<Cuisine, int> b) =>
          b.value.compareTo(a.value),
    );

  return _capped(
    ranked.map(
      (MapEntry<Cuisine, int> entry) =>
          '${entry.key.label.toLowerCase()} ${entry.value}',
    ),
    _cuisineCount,
  );
}

/// The first [limit] of [names] that fit the character budget, joined.
///
/// **Two caps, not one** (Sprint 50). The count keeps the line meaningful; the
/// character budget keeps it *whole*. The Edge Function slices every value at 300
/// characters, so a list capped only by item count could arrive cut mid-word —
/// twenty pantry names is comfortably past 300, and "chicken thigh, spring onio"
/// is a line that teaches the model an ingredient nobody has.
///
/// Null rather than an empty string, because the function skips empty values and
/// "in_the_kitchen: " with nothing after it is a line that makes the model think
/// the kitchen is empty rather than unknown.
String? _capped(Iterable<String> names, int limit) {
  final StringBuffer buffer = StringBuffer();
  int taken = 0;

  for (final String name in names) {
    if (taken >= limit) {
      break;
    }

    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final int cost = trimmed.length + (taken == 0 ? 0 : _separator.length);
    if (buffer.length + cost > _valueChars) {
      // Stopped on an item boundary, which is the whole point. Whatever is left
      // is less useful than what is already in — the lists are ordered so that
      // the front matters most.
      break;
    }

    if (taken > 0) {
      buffer.write(_separator);
    }
    buffer.write(trimmed);
    taken += 1;
  }

  return buffer.isEmpty ? null : buffer.toString();
}

const String _separator = ', ';

/// Under the Edge Function's own 300-character slice, with room to spare. The
/// margin is deliberate: the cap there is a defence, and a value that regularly
/// arrives at exactly the limit is a value nobody would notice being cut.
const int _valueChars = 280;

/// Enough to answer "what can I make with this", short enough not to be a
/// shopping inventory.
const int _pantryNames = 20;

/// A shelf, not a list. More than this and "soon" has stopped meaning anything.
const int _urgentNames = 8;

/// The whole point of the pantry, so it gets the most room.
const int _cookableNames = 12;

/// A week's worth. Past that it stops informing "not that again".
const int _recentCount = 7;

/// Four cuisines describes a household. The fifth is a rounding error.
const int _cuisineCount = 4;

/// Enough for a real suggestion. The list is short by design anyway — it is the
/// places two people actually go.
const int _placeNames = 8;

/// A sample, to teach the model what kind of food this is. Not the library.
const int _librarySample = 12;

const String _logName = 'ai-context';

/// [householdAiContext] as something a widget can read.
///
/// The meal form fills its own fields from the assistant, and a widget holds a
/// `WidgetRef` rather than a `Ref` — so it cannot call the function directly. A
/// one-line provider bridges it without a second copy of eighty lines of context
/// assembly.
///
/// **Read it with `refresh`, not `read`.** A `FutureProvider` caches, and the
/// whole contract of this context is that it is a snapshot at the moment of
/// asking — a cached copy would tell the model about a pantry two edits ago.
@riverpod
Future<Map<String, Object?>> householdAiSnapshot(Ref ref) =>
    householdAiContext(ref);
