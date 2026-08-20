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

  /// One meal, with its ingredients.
  ///
  /// Separate from [search] because the join is only worth paying for here:
  /// twenty feed rows times six ingredients is a payload the feed renders none
  /// of. Throws a not-found failure when the id matches nothing the caller may
  /// see — which covers both a deleted meal and another household's private
  /// one, deliberately, since telling those apart would leak the difference.
  Future<Meal> byId(String id);

  /// Rewrites a meal this household wrote (Sprint 26).
  ///
  /// Only the columns the form owns. `calories`, `dietary_tags` and `tags` are
  /// left alone, because [MealDraft] does not carry them and writing a default
  /// over a value nobody was shown is how a save quietly loses data.
  ///
  /// The ingredient list is **replaced**, not merged. A recipe's ingredients are
  /// one thing the user edits as a whole — removing an item has to mean
  /// something — and diffing lines matched by a name the user is also editing
  /// would be guesswork.
  ///
  /// Author-scoped by policy, not by convention: `update own meals` accepts the
  /// write only from `created_by`. See `Meal.isWrittenBy`.
  Future<Meal> update(String id, MealDraft draft);

  /// Deletes a meal this household wrote.
  ///
  /// The `meal_ingredients` rows go with it by cascade. What outlives it is
  /// deliberate: `meal_history` keeps its `meal_id` as a nullable reference, so
  /// deleting a recipe does not rewrite the record of having eaten it.
  Future<void> delete(String id);

  /// Every meal this household wrote, newest first.
  ///
  /// Unpaged, and that is a decision rather than an omission. This is one
  /// household's own recipes — tens, not thousands — and paging it would mean a
  /// second scrolling controller for a list that fits in one request. Revisit if
  /// a household ever writes enough to notice, which would be a good problem.
  ///
  /// With ingredients, unlike [search]: this list is short enough to afford the
  /// join, and the edit form needs them the moment a row is tapped.
  Future<List<Meal>> mine();

  /// Several meals, by id, for a list assembled elsewhere.
  ///
  /// Favourites are stored as ids (Sprint 24), so the screen that shows them
  /// has a set of ids and needs meals. One request rather than one per id.
  ///
  /// Ids that match nothing are **skipped, not an error**: a meal deleted
  /// after it was favourited should leave the rest of the list intact rather
  /// than failing the whole screen.
  Future<List<Meal>> byIds(Set<String> ids);
}

/// The page size for the feed.
///
/// Twenty is about three screens of `MealCard.feed` on a phone, so the next page
/// is already in flight before the reader reaches the end of this one, and it is
/// a third of the whole catalogue — small enough that a mistake in the filters
/// shows up as an obviously short page rather than as a slow one.
const int kMealPageSize = 20;
