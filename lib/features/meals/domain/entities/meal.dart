import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/utils/formatters.dart';

/// A meal from the catalogue, or one a household wrote itself.
///
/// Mirrors the `meals` table (docs/DATABASE.md §4.5). One entity for both the
/// feed and the detail screen: the catalogue is sixty rows and the instructions
/// are a handful of short strings, so a separate summary type would buy a few
/// hundred bytes a page at the cost of a second thing to keep in step. If the
/// catalogue ever reaches thousands, split it then — that is a measurement, not
/// a guess to make now.
///
/// Hand-written rather than Freezed. Every field here is decoded from a
/// PostgREST row whose enum values are check-constrained in the database, and
/// the decoding is where the interesting decisions live: an unrecognised cuisine
/// hides one meal rather than throwing away a page (see [Meal.fromRow]). A
/// generated `fromJson` would either throw or need the same hand-written
/// converters anyway.
@immutable
class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.category,
    required this.difficulty,
    required this.cookingTimeMinutes,
    required this.estimatedCost,
    required this.servings,
    this.description,
    this.calories,
    this.instructions = const <String>[],
    this.dietaryTags = const <DietaryTag>{},
    this.tags = const <String>[],
    this.isPublic = true,
  });

  /// Decodes one PostgREST row.
  ///
  /// Unrecognised enum values fall back rather than throwing. A cuisine added to
  /// the database before the app ships a matching build would otherwise take the
  /// whole feed down; showing that one meal as "Something else" is the smaller
  /// failure, and [Cuisine.other] exists for exactly this.
  factory Meal.fromRow(Map<String, dynamic> row) {
    return Meal(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      cuisine: Cuisine.fromValue(row['cuisine'] as String) ?? Cuisine.other,
      category:
          MealCategory.fromValue(row['category'] as String) ??
          MealCategory.dinner,
      difficulty:
          Difficulty.fromValue(row['difficulty'] as String) ?? Difficulty.easy,
      cookingTimeMinutes: (row['cooking_time_minutes'] as num).toInt(),
      estimatedCost: (row['estimated_cost'] as num).toDouble(),
      servings: (row['servings'] as num).toInt(),
      calories: (row['calories'] as num?)?.toInt(),
      instructions: _stringList(row['instructions']),
      // Skipped rather than defaulted: a dietary tag the app does not know is
      // the one case where guessing is dangerous. Dropping it means the meal is
      // *offered* to someone it may not suit, which is why the seed's tags are
      // checked against these enums in test/tooling/meal_seed_test.dart.
      dietaryTags: <DietaryTag>{
        for (final String value in _stringList(row['dietary_tags']))
          if (DietaryTag.fromValue(value) case final DietaryTag tag) tag,
      },
      tags: _stringList(row['tags']),
      // Defaults to public so a query that did not select the column cannot
      // label the whole catalogue as household-written.
      isPublic: row['is_public'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String? description;
  final Cuisine cuisine;
  final MealCategory category;
  final Difficulty difficulty;
  final int cookingTimeMinutes;

  /// Pesos, for [servings] people — not per head. See [costPerServing].
  final double estimatedCost;
  final int servings;

  /// Display only, never a tracked target (docs/DATABASE.md §4.5).
  final int? calories;

  /// Ordered steps.
  final List<String> instructions;
  final Set<DietaryTag> dietaryTags;

  /// Mood and free-form: comfort, spicy, quick.
  final List<String> tags;

  /// Whether this is a catalogue meal rather than one a household wrote.
  final bool isPublic;

  /// Whether this meal belongs to the reader's household.
  ///
  /// The inverse of [isPublic] rather than a comparison against a household id:
  /// the `read visible meals` policy returns "public, or my household's" and
  /// nothing else, so any non-public row that reaches the client is already
  /// established as one this household may see.
  bool get isMine => !isPublic;

  /// What one plate costs.
  ///
  /// The number every budget question in the app actually means: two meals at
  /// 300 pesos are not the same price if one feeds two people and the other
  /// feeds five. Computed here and stored in the database as a generated column
  /// so the server can filter on it (migration 0015).
  double get costPerServing => estimatedCost / servings;

  /// `Filipino · 45 min`.
  String get metadataLine => AppFormat.metadata(<String?>[
    cuisine.label,
    AppFormat.cookingTime(cookingTimeMinutes),
  ]);

  @override
  bool operator ==(Object other) {
    return other is Meal &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.cuisine == cuisine &&
        other.category == category &&
        other.difficulty == difficulty &&
        other.cookingTimeMinutes == cookingTimeMinutes &&
        other.estimatedCost == estimatedCost &&
        other.servings == servings &&
        other.calories == calories &&
        other.isPublic == isPublic &&
        listEquals(other.instructions, instructions) &&
        setEquals(other.dietaryTags, dietaryTags) &&
        listEquals(other.tags, tags);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    cuisine,
    category,
    difficulty,
    cookingTimeMinutes,
    estimatedCost,
    servings,
    calories,
    isPublic,
    Object.hashAll(instructions),
    Object.hashAllUnordered(dietaryTags),
    Object.hashAll(tags),
  );

  @override
  String toString() => 'Meal($id, $name, ${cuisine.value})';

  /// A list of strings from a jsonb array, a Postgres array, or nothing.
  ///
  /// PostgREST hands back `List<dynamic>` for both `jsonb` and `text[]`, and
  /// null for a column the query did not select.
  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return <String>[
      for (final Object? entry in value)
        if (entry != null) '$entry',
    ];
  }
}
