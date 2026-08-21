import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// One line on the shopping list (docs/DATABASE.md §4.12).
///
/// **Either a catalogue ingredient or free text, never both.** The table's own
/// `grocery_items_name_ck` enforces it, and the reason is in the column comment:
/// "someone in a supermarket must be able to add *the good soy sauce* without our
/// vocabulary approving it first". A list that rejects what somebody types while
/// they are standing in an aisle is a list they stop using.
///
/// That split is why [name] is a getter rather than a column — it reads whichever
/// of the two is set, so nothing above this has to care which kind of line it is.
@immutable
class GroceryItem {
  const GroceryItem({
    required this.id,
    this.ingredientId,
    this.ingredientName,
    this.customName,
    this.category = IngredientCategory.other,
    this.quantity,
    this.unit = '',
    this.isCompleted = false,
    this.fromMealId,
  });

  /// Decodes a `grocery_items` row with its `ingredients` join nested under its
  /// own name, which is the shape PostgREST returns.
  factory GroceryItem.fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic>? ingredient =
        row['ingredients'] as Map<String, dynamic>?;

    return GroceryItem(
      id: row['id'] as String,
      ingredientId: row['ingredient_id'] as String?,
      ingredientName: ingredient?['name'] as String?,
      customName: row['custom_name'] as String?,
      category: IngredientCategory.fromValue(
        ingredient?['category'] as String?,
      ),
      quantity: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit'] as String? ?? '',
      isCompleted: row['is_completed'] as bool? ?? false,
      fromMealId: row['added_from_meal_id'] as String?,
    );
  }

  final String id;

  /// Set when the line came from the shared vocabulary.
  final String? ingredientId;
  final String? ingredientName;

  /// Set when somebody typed something the vocabulary does not have.
  final String? customName;

  /// Which aisle. Always [IngredientCategory.other] for a free-text line, because
  /// there is nothing to look the aisle up from — and guessing that "the good soy
  /// sauce" is a condiment would be right this once and wrong often enough to
  /// stop being useful.
  final IngredientCategory category;

  /// Null means "some" — the same convention the pantry uses, for the same
  /// reason: at a shelf, *do we need milk* is a faster question than *how much*.
  final double? quantity;

  final String unit;

  final bool isCompleted;

  /// Which meal put this here, when something did (Sprint 43).
  ///
  /// Read now, written later. The column exists, so decoding it costs nothing and
  /// means Sprint 43 adds a reason to the row rather than a migration.
  final String? fromMealId;

  /// Whichever of the two names this line has.
  String get name => ingredientName ?? customName ?? '';

  /// `500 g`, `2`, or empty.
  ///
  /// Matches `PantryItem.amount` deliberately: the same quantity should look the
  /// same in the kitchen and in the shop.
  String get amount {
    if (quantity case final double value) {
      final String figure = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return unit.isEmpty ? figure : '$figure $unit';
    }
    return unit;
  }

  bool get hasAmount => amount.trim().isNotEmpty;

  /// Whether this line is the same *thing* as [other], for merging.
  ///
  /// By ingredient id where there is one, and by name otherwise. Two lines for
  /// chicken is the failure this prevents: a list you have to read twice in an
  /// aisle is a list that gets things wrong.
  bool isSameThingAs(GroceryItem other) {
    if (ingredientId != null && other.ingredientId != null) {
      return ingredientId == other.ingredientId;
    }
    return name.trim().toLowerCase() == other.name.trim().toLowerCase();
  }

  GroceryItem copyWith({
    double? quantity,
    String? unit,
    bool? isCompleted,
    bool clearQuantity = false,
  }) {
    return GroceryItem(
      id: id,
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      customName: customName,
      category: category,
      // Explicit clear, because `copyWith(quantity: null)` cannot mean "unset" —
      // null is indistinguishable from "not passed".
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: unit ?? this.unit,
      isCompleted: isCompleted ?? this.isCompleted,
      fromMealId: fromMealId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GroceryItem &&
      other.id == id &&
      other.ingredientId == ingredientId &&
      other.ingredientName == ingredientName &&
      other.customName == customName &&
      other.category == category &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.isCompleted == isCompleted;

  @override
  int get hashCode => Object.hash(
    id,
    ingredientId,
    ingredientName,
    customName,
    category,
    quantity,
    unit,
    isCompleted,
  );

  @override
  String toString() => 'GroceryItem($name, $amount, done: $isCompleted)';
}
