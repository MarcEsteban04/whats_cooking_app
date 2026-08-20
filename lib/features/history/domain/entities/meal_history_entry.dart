import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// How a meal came to be eaten.
///
/// Mirrors the `source` check on `meal_history`. Recorded because Sprint 32's
/// variety rules and the statistics screen both want to know whether the app
/// chose the meal or the household did — a run of roulette picks and a run of
/// manual entries mean very different things about how well the engine is doing.
enum HistorySource {
  roulette,
  manual,
  planner,
  ai;

  String get value => name;

  static HistorySource fromValue(String value) {
    for (final HistorySource source in HistorySource.values) {
      if (source.value == value) {
        return source;
      }
    }
    // Unrecognised reads as manual rather than throwing: a source added to the
    // database before the app ships a matching build should not break a list.
    return HistorySource.manual;
  }
}

/// One meal, eaten (Sprint 31).
///
/// Mirrors a `meal_history` row (docs/DATABASE.md §4.10), joined to the meal it
/// points at. Household-scoped rather than personal: the `household members read
/// history` policy returns everyone's, because "what did we eat this week" is a
/// question about the household and answering it per-person would make a couple's
/// history two half-histories.
@immutable
class MealHistoryEntry {
  const MealHistoryEntry({
    required this.id,
    required this.mealId,
    required this.eatenAt,
    required this.mealType,
    required this.source,
    this.meal,
    this.actualCost,
    this.wasCooked = true,
  });

  /// Decodes one PostgREST row, with `meals(...)` joined under its own name.
  factory MealHistoryEntry.fromRow(Map<String, dynamic> row) {
    final Object? joined = row['meals'];

    return MealHistoryEntry(
      id: row['id'] as String,
      mealId: row['meal_id'] as String,
      eatenAt:
          DateTime.tryParse(row['eaten_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      // Falls back to dinner rather than throwing, for the reason every other
      // enum here does: one unreadable row should not take a list down. Dinner
      // because it is what most rows are.
      mealType:
          MealCategory.fromValue(row['meal_type'] as String? ?? '') ??
          MealCategory.dinner,
      source: HistorySource.fromValue(row['source'] as String? ?? 'manual'),
      meal: joined is Map<String, dynamic> ? Meal.fromRow(joined) : null,
      actualCost: (row['actual_cost'] as num?)?.toDouble(),
      wasCooked: row['was_cooked'] as bool? ?? true,
    );
  }

  final String id;
  final String mealId;

  /// When, in local time. Stored as `timestamptz`, so the date *and* the time of
  /// day are both real answers rather than a guess about a timezone.
  final DateTime eatenAt;

  /// Which occasion — the `meal_type` column, which since migration 0018 carries
  /// the same five values as a meal's category.
  final MealCategory mealType;

  final HistorySource source;

  /// The meal itself, when the query joined it. Null on a bare row.
  ///
  /// Nullable rather than required because the join can come back empty for a
  /// meal another household wrote and later deleted — `meal_id` is
  /// `on delete restrict`, so that should not happen, and a list that falls over
  /// if it does is a list that falls over.
  final Meal? meal;

  /// What it really cost, once somebody said.
  ///
  /// Null at the moment of accepting, deliberately: nobody knows yet. The meal's
  /// own `estimatedCost` is what the app shows until this is filled in, and the
  /// two are kept apart because an estimate written into a column called
  /// `actual_cost` is a number that will later be read as a fact.
  final double? actualCost;

  /// Cooked, rather than ordered. Feeds the statistics screen.
  final bool wasCooked;

  /// The name to show, even when the join is missing.
  String get displayName => meal?.name ?? 'A meal';

  /// What this cost a head, as well as it is known.
  ///
  /// The actual when there is one, the estimate otherwise, null when there is
  /// neither. Callers that need to say *which* should ask [actualCost] directly —
  /// this is for the row that just needs a number.
  double? get costPerServing {
    if (actualCost case final double actual) {
      final int servings = meal?.servings ?? 1;
      return servings > 0 ? actual / servings : actual;
    }
    return meal?.costPerServing;
  }

  @override
  bool operator ==(Object other) =>
      other is MealHistoryEntry &&
      other.id == id &&
      other.mealId == mealId &&
      other.eatenAt == eatenAt &&
      other.mealType == mealType &&
      other.source == source &&
      other.meal == meal &&
      other.actualCost == actualCost &&
      other.wasCooked == wasCooked;

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    eatenAt,
    mealType,
    source,
    meal,
    actualCost,
    wasCooked,
  );
}
