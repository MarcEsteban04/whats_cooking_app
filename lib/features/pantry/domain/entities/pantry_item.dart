import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// One thing in the kitchen (docs/DATABASE.md §4.11).
///
/// **Quantity is nullable, and null is the common case.** The column's own comment
/// says why — "we have some, without a tracked amount" — and that is what a pantry
/// mostly holds. Somebody standing at an open fridge at seven in the evening is
/// answering *is there chicken*, not weighing it. Forcing a number would make the
/// fast answer the slow one, and the app would stop being told about half the
/// kitchen.
///
/// **Units are stored as typed and never converted.** This was
/// docs/DATABASE.md §9's open question — normalise on write, or convert on read —
/// and the answer is neither. Both would need a density table to turn a bottle of
/// soy sauce into grams, and neither has anything sensible to do with "1 bulb" of
/// garlic. What the pantry is *for* is Sprint 41's question, and that question is
/// **do we have any**, not do we have enough: presence, not arithmetic. A unit is
/// therefore a note to the reader, and a note is best left in the words they wrote
/// it in.
@immutable
class PantryItem {
  const PantryItem({
    required this.id,
    required this.ingredientId,
    required this.name,
    this.category = IngredientCategory.other,
    this.quantity,
    this.unit = '',
    this.expiresOn,
    this.isStaple = false,
  });

  /// Decodes a `pantry_items` row with its `ingredients` join nested under its own
  /// name, which is the shape PostgREST returns.
  factory PantryItem.fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> ingredient =
        (row['ingredients'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return PantryItem(
      id: row['id'] as String,
      ingredientId: row['ingredient_id'] as String,
      name: ingredient['name'] as String? ?? '',
      category: IngredientCategory.fromValue(
        ingredient['category'] as String?,
      ),
      quantity: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit'] as String? ?? '',
      // `date`, not `timestamptz`. Parsed leniently: an unparseable value is
      // better treated as "no date" than as a reason the pantry will not open.
      expiresOn: DateTime.tryParse(row['expiration_date'] as String? ?? ''),
      isStaple: ingredient['is_staple'] as bool? ?? false,
    );
  }

  final String id;
  final String ingredientId;

  /// From the shared vocabulary, so it is always lower case and trimmed.
  final String name;

  final IngredientCategory category;

  /// Null means "we have some". See the class comment.
  final double? quantity;

  /// As typed. Empty when there is no amount to qualify.
  final String unit;

  /// Sprint 40 does the surfacing; the column and this field exist now so an item
  /// added today does not have to be edited later to gain a date it always had.
  final DateTime? expiresOn;

  /// Salt, oil, garlic. Assumed present, and never counted against a match
  /// percentage (docs/USER_FLOWS.md §12).
  final bool isStaple;

  /// `500 g`, `2`, or empty.
  ///
  /// Whole numbers lose the decimal — "4" rather than "4.0" — because quantities
  /// here are almost all integers and a trailing zero on every one reads as a
  /// rounding error. Matches `MealIngredient.amount` deliberately: the same
  /// number should look the same in a recipe and in the kitchen.
  String get amount {
    if (quantity case final double value) {
      final String figure = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return unit.isEmpty ? figure : '$figure $unit';
    }
    // No quantity, but possibly still a unit — "a bottle" is a real answer.
    return unit;
  }

  /// What the row says when there is no amount at all.
  bool get hasAmount => amount.trim().isNotEmpty;

  PantryItem copyWith({
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    bool clearQuantity = false,
    bool clearExpiry = false,
  }) {
    return PantryItem(
      id: id,
      ingredientId: ingredientId,
      name: name,
      category: category,
      // Explicit clears, because `copyWith(quantity: null)` cannot mean "unset" —
      // null is indistinguishable from "not passed". Going from "500 g" back to
      // "we have some" has to be possible.
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: unit ?? this.unit,
      expiresOn: clearExpiry ? null : (expiresOn ?? this.expiresOn),
      isStaple: isStaple,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PantryItem &&
      other.id == id &&
      other.ingredientId == ingredientId &&
      other.name == name &&
      other.category == category &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.expiresOn == expiresOn &&
      other.isStaple == isStaple;

  @override
  int get hashCode => Object.hash(
    id,
    ingredientId,
    name,
    category,
    quantity,
    unit,
    expiresOn,
    isStaple,
  );

  @override
  String toString() => 'PantryItem($name, $amount)';
}

/// A name the vocabulary already knows, offered while somebody types.
///
/// Its own type rather than a bare string, because the [id] is what makes adding
/// an item one round trip instead of two — picking a suggestion means the row is
/// already resolved and nothing has to be looked up or created.
@immutable
class IngredientSuggestion {
  const IngredientSuggestion({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultUnit,
  });

  factory IngredientSuggestion.fromRow(Map<String, dynamic> row) {
    return IngredientSuggestion(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      category: IngredientCategory.fromValue(row['category'] as String?),
      defaultUnit: row['default_unit'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final IngredientCategory category;

  /// Pre-fills the unit field, so the common case is one tap and a number.
  final String defaultUnit;
}
