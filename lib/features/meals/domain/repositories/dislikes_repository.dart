/// Reads and writes the meals this user has hidden (Sprint 25).
///
/// **Strictly private, and that is a schema-level decision rather than a policy
/// choice this contract could soften.** `disliked_meals` carries a single
/// `own dislikes only` policy — no household read, unlike `favorite_meals` —
/// because a partner seeing what you dislike is a social cost with no product
/// benefit (`supabase/migrations/…_preferences.sql`). The engine reads both
/// server-side regardless, so couple scoring loses nothing by it.
///
/// A separate contract from `FavoritesRepository` despite the identical shape.
/// They read the same today and diverge on purpose: favourites grow a
/// *which of you* dimension in Sprint 46, and dislikes stay one person's and
/// move into the candidate query the scoring engine builds. Merging them now
/// would mean unpicking them exactly when the pressure is on.
///
/// The thing this contract does **not** do is filter the feed. A dislike is a
/// hard exclusion applied where the rows are selected — see
/// `MealQuery.excludedMealIds` — because a filter applied after the rows arrive
/// would leave the server and the app disagreeing about what "the next twenty"
/// means.
abstract interface class DislikesRepository {
  /// The meal ids this user has hidden.
  ///
  /// A set of ids, for the same reason favourites are: the question a feed asks
  /// is "is this one hidden?", twenty times, and fetching twenty meals to answer
  /// twenty booleans is the wrong trade.
  Future<Set<String>> mealIds();

  /// Hides a meal. Idempotent — hiding twice is not an error.
  Future<void> add(String mealId);

  /// Un-hides a meal. Idempotent — removing something absent is not an error.
  Future<void> remove(String mealId);
}
