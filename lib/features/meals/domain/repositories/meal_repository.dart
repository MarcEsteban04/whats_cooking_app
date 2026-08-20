import 'package:flutter/foundation.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';

/// One page of the feed.
@immutable
class MealPage {
  const MealPage({required this.meals, required this.hasMore});

  const MealPage.empty() : meals = const <Meal>[], hasMore = false;

  final List<Meal> meals;

  /// Whether another page exists.
  ///
  /// Answered by asking for one row more than the page size and seeing whether
  /// it arrives, rather than by a separate `count` query. A count is a second
  /// round trip on every page to answer a question the page itself can answer,
  /// and on a filtered query it is the more expensive of the two.
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      other is MealPage &&
      other.hasMore == hasMore &&
      listEquals(other.meals, meals);

  @override
  int get hashCode => Object.hash(Object.hashAll(meals), hasMore);
}

/// Reads the meal catalogue.
///
/// Paging is offset-based, which is the right trade here: the catalogue is
/// small, every sort is a total order (see [MealSort.tiebreaker]) so offsets
/// stay stable within a session, and a cursor would have to encode the sort
/// column for four different sorts. Revisit if the catalogue reaches the size
/// where a page-three offset scan costs something.
abstract interface class MealRepository {
  /// One page of meals matching [query].
  ///
  /// [offset] is a row count, not a page number, so a caller that has already
  /// loaded 23 meals asks for 23 rather than doing the arithmetic itself.
  Future<MealPage> search({required MealQuery query, int offset, int limit});

  /// Saves a meal this household wrote, and returns it as stored.
  ///
  /// Private to the household by construction. The `create own meals` policy
  /// accepts an insert only when `created_by` is the caller, `is_public` is
  /// false, and the household is one they belong to — so there is deliberately
  /// no way to write into the public catalogue from the app. Whether a custom
  /// meal can ever be promoted into it is still open (docs/DATABASE.md §9 Q8).
  Future<Meal> create(MealDraft draft);
}

/// The page size for the feed.
///
/// Twenty is about three screens of `MealCard.feed` on a phone, so the next page
/// is already in flight before the reader reaches the end of this one, and it is
/// a third of the whole catalogue — small enough that a mistake in the filters
/// shows up as an obviously short page rather than as a slow one.
const int kMealPageSize = 20;
