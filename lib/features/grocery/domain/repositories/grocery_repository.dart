import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';

/// What we need to buy (Sprint 42).
///
/// **One list, and no way to make a second.** `grocery_lists` supports many and
/// the schema already enforces one *active* per household with a partial unique
/// index — so the shape it wants is exactly the shape this uses. The list is
/// created on first write and never named on screen: a list picker for two people
/// with one shopping trip is ceremony, and "which list?" is a question nobody in
/// a supermarket wants asked.
///
/// Household-scoped throughout, and no method takes a list id. The repository
/// resolves it from the session, which is what stops a caller ever writing to
/// somebody else's list — and RLS refuses regardless, so the two agree.
abstract interface class GroceryRepository {
  /// Everything on the list, ordered for walking a shop.
  ///
  /// Aisle first, then name — the same ordering the pantry uses, and for the same
  /// reason: a list sorted A-to-Z sends you back across the shop four times.
  ///
  /// **Completed items are returned, not filtered out.** They fade in place rather
  /// than vanishing (docs/USER_FLOWS.md §13, design_ui §23): things disappearing
  /// under your thumb in a supermarket is disorienting, and a ticked line is also
  /// how you check you did not miss something.
  Future<List<GroceryItem>> items();

  /// Puts something on the list.
  ///
  /// [name] is matched against the shared vocabulary and stored as an ingredient
  /// reference when it is found. When it is not, it is stored as **free text**
  /// rather than being added to the vocabulary — which is the opposite of what the
  /// pantry does, and deliberately so. A pantry entry is a standing fact about the
  /// kitchen and worth a catalogue row; "the good soy sauce" written at a shelf is
  /// a note to self, and filing it in the shared ingredient list would slowly turn
  /// that list into somebody's shopping shorthand.
  ///
  /// **Merges rather than duplicating.** The same thing added twice adds its
  /// quantities together: two lines for chicken is a list you have to read twice
  /// in an aisle.
  Future<GroceryItem> add({
    required String name,
    double? quantity,
    String unit = '',
  });

  /// Puts a meal's missing ingredients on the list (Sprint 43).
  ///
  ///     accepted meal → required ingredients → compare pantry → missing only
  ///
  /// One call, server-side, and not only for the payload: the client does not
  /// *have* the meal's ingredient list. The spin fetches `meals`-only columns, so
  /// the result screen holds a meal with no recipe attached — fetching one in
  /// order to write another table would be two round trips and a race.
  ///
  /// Staples and optional ingredients are skipped, matching the pantry match.
  /// Nobody wants "salt" on the list every time they accept a meal.
  ///
  /// Returns how many lines it touched, so the app can say so. Zero is a normal
  /// answer and a good one: it means the kitchen already had everything.
  Future<int> addMissingForMeal(String mealId);

  /// Ticks a line off, or un-ticks it.
  Future<GroceryItem> setCompleted(String id, {required bool isCompleted});

  /// Changes how much of something is wanted.
  Future<GroceryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    bool clearQuantity = false,
  });

  /// Takes a line off the list.
  Future<void> remove(String id);

  /// Removes everything already ticked.
  ///
  /// Returns how many went, so the caller can say so — "cleared 6" is a
  /// confirmation, and a list that silently shortens is a list you check twice.
  Future<int> clearCompleted();
}
