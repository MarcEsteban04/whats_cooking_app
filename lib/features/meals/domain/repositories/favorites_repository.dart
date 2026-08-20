/// Reads and writes the signed-in user's favourite meals (Sprint 24).
///
/// A separate contract from `MealRepository` because the two answer different
/// questions and change for different reasons: one is about the catalogue, this
/// is about one person's relationship to it. Keeping them apart also keeps the
/// feed's query from growing a `favouritedBy` parameter it does not need.
///
/// **Only your own.** `favorite_meals` is readable across a household — couple
/// scoring depends on it (docs/ARCHITECTURE.md §8.3) — but writable only by its
/// owner, and this contract deliberately asks for less than the policy allows:
/// it reads `user_id = auth.uid()` explicitly rather than taking whatever RLS
/// returns. Otherwise a partner's favourite would arrive looking like yours and
/// the heart would be filled on a meal you never saved.
///
/// Household favourites are Sprint 46's problem, and they want a different
/// shape: which of you, not merely whether.
abstract interface class FavoritesRepository {
  /// The meal ids this user has favourited.
  ///
  /// A set of ids rather than a list of meals. The heart on a feed row needs to
  /// answer "is this one saved?" for twenty rows at once, and fetching twenty
  /// meals to answer a question about twenty booleans is the wrong trade.
  Future<Set<String>> mealIds();

  /// Saves a meal. Idempotent — saving twice is not an error.
  Future<void> add(String mealId);

  /// Removes a meal. Idempotent — removing something absent is not an error.
  Future<void> remove(String mealId);
}
