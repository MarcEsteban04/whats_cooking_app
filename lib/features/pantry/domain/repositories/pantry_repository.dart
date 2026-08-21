import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';

/// What is in the kitchen (Sprint 39).
///
/// Household-scoped throughout, and no method takes a household id. The repository
/// resolves it from the session, which is what stops a caller ever asking for
/// somebody else's kitchen — and RLS refuses regardless, so the two agree.
abstract interface class PantryRepository {
  /// Everything, ordered for reading.
  ///
  /// Sorted by category and then by name, because a pantry is read the way a shop
  /// is walked. Alphabetical across the whole list sends the eye back and forth
  /// between the fridge and the spice rack.
  Future<List<PantryItem>> items();

  /// Puts an ingredient in the kitchen, or updates what is already there.
  ///
  /// **Idempotent by name.** `pantry_items` is unique on
  /// `(household_id, ingredient_id)` — the schema's own comment says "adding an
  /// ingredient already present updates quantity rather than creating a duplicate
  /// row" — so adding chicken twice is one row with the newer amount, not two rows
  /// to reconcile at the fridge door.
  ///
  /// [name] is matched case-insensitively against the shared vocabulary and
  /// **added when missing**, which is the `authenticated add ingredients` policy's
  /// whole purpose: nobody may be blocked because our ingredient list is
  /// incomplete.
  ///
  /// A null [quantity] is not "zero" and not "unknown" — it is *we have some*,
  /// which is the answer somebody standing at an open fridge actually has.
  Future<PantryItem> add({
    required String name,
    double? quantity,
    String unit = '',
    DateTime? expiresOn,
  });

  /// Changes the amount on an item already there.
  ///
  /// [clearQuantity] goes back to "we have some", which a null [quantity] cannot
  /// express — null is indistinguishable from "not passed".
  Future<PantryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    bool clearQuantity = false,
    bool clearExpiry = false,
  });

  /// Takes it out of the kitchen.
  Future<void> remove(String id);

  /// How much of each meal the kitchen already covers (Sprint 41).
  ///
  /// Keyed by meal id. A meal absent from the map has no countable ingredients at
  /// all — either none recorded, or all of them staples — which the caller treats
  /// as nothing to be short of rather than as a zero.
  ///
  /// Resolved server-side by `pantry_match()`. The spin's pool runs to 200 meals
  /// with six ingredients each, and pulling that join into the one interaction that
  /// must not wait would cost more than the signal is worth. This returns two
  /// integers and at most three names per meal.
  Future<Map<String, PantryMatch>> matches();

  /// Names the vocabulary already knows, for the add field.
  ///
  /// Empty [query] returns nothing rather than everything: an autocomplete that
  /// opens with two hundred ingredients is a list, and a list is not what somebody
  /// halfway through typing "chick" is looking at.
  Future<List<IngredientSuggestion>> suggest(String query);
}
