import 'package:flutter/foundation.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';

/// One page of the feed.
@immutable
class MealPage {
  const MealPage({required this.meals, required this.hasMore, this.cachedAt});

  const MealPage.empty()
    : meals = const <Meal>[],
      hasMore = false,
      cachedAt = null;

  final List<Meal> meals;

  /// Whether another page exists.
  ///
  /// Answered by asking for one row more than the page size and seeing whether
  /// it arrives, rather than by a separate `count` query. A count is a second
  /// round trip on every page to answer a question the page itself can answer,
  /// and on a filtered query it is the more expensive of the two.
  final bool hasMore;

  /// When this page was stored, if it came off the disk rather than the wire
  /// (Sprint 27).
  ///
  /// Null on every live answer. Non-null means the network failed and this is
  /// what the device had — which the screen has to say, because a stale
  /// catalogue presented as current is the app lying about the one thing it is
  /// for. It also means [hasMore] is false: there is no page two in a cache.
  final DateTime? cachedAt;

  bool get isFromCache => cachedAt != null;

  @override
  bool operator ==(Object other) =>
      other is MealPage &&
      other.hasMore == hasMore &&
      other.cachedAt == cachedAt &&
      listEquals(other.meals, meals);

  @override
  int get hashCode => Object.hash(Object.hashAll(meals), hasMore, cachedAt);
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

  /// Meals ruled out by the foods this user said they avoid (Sprint 35).
  ///
  /// **This is the half of the dislikes promise that was missing.** Since
  /// migration 0011 the app has captured typed foods, stored them, and shown
  /// their count under the words "We will never suggest these" — and nothing read
  /// them. The roulette was free to offer a meal built on the one ingredient
  /// somebody cannot stand, which is a worse outcome than never having asked.
  ///
  /// Resolved server-side, by a function that reads the caller's own preferences.
  /// Two things follow from that: the list of foods never leaves the database, and
  /// there is no argument for a caller to get wrong. It also means the matching
  /// stays current — a food that matches nothing in today's catalogue matches as
  /// soon as a recipe adds it, which a one-off reconciliation at save time would
  /// never notice.
  ///
  /// Optional ingredients do not block: a recipe listing coriander as a garnish is
  /// one a coriander-hater can cook.
  Future<Set<String>> mealsBlockedByDislikes();
}

/// The page size for the feed.
///
/// Twenty is about three screens of `MealCard.feed` on a phone, so the next page
/// is already in flight before the reader reaches the end of this one, and it is
/// a third of the whole catalogue — small enough that a mistake in the filters
/// shows up as an obviously short page rather than as a slow one.
const int kMealPageSize = 20;
