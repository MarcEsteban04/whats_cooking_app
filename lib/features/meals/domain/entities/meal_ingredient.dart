import 'package:flutter/foundation.dart';

/// One line of a meal's ingredient list, as stored.
///
/// Mirrors a `meal_ingredients` row joined to its `ingredients` row
/// (docs/DATABASE.md §4.7). The name comes from the shared vocabulary and the
/// quantity from the link, which is the whole reason the link table exists: two
/// meals can both want garlic without agreeing on how much.
@immutable
class MealIngredient {
  const MealIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
    this.isStaple = false,
  });

  /// Decodes a nested PostgREST row.
  ///
  /// The shape is `{quantity, unit, is_optional, ingredients: {name, is_staple}}`
  /// — PostgREST nests the joined table under its own name. A row whose join
  /// came back null is skipped by the caller rather than defaulted here, because
  /// an ingredient with no name is not something to render.
  factory MealIngredient.fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> ingredient =
        (row['ingredients'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return MealIngredient(
      name: ingredient['name'] as String? ?? '',
      quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
      unit: row['unit'] as String? ?? '',
      isOptional: row['is_optional'] as bool? ?? false,
      isStaple: ingredient['is_staple'] as bool? ?? false,
    );
  }

  final String name;
  final double quantity;
  final String unit;

  /// Excluded from the pantry match's denominator, so a missing garnish never
  /// stops a meal being offered (docs/USER_FLOWS.md §12).
  final bool isOptional;

  /// Assumed present. Salt, oil, garlic — the things that never reduce a match
  /// percentage, per the same rule.
  final bool isStaple;

  bool get isNamed => name.trim().isNotEmpty;

  /// `500 g`, or `4 pc`.
  ///
  /// Whole numbers lose their decimal: "4 pc" rather than "4.0 pc". Quantities
  /// in this catalogue are almost all integers, and a trailing `.0` on every one
  /// of them reads as a rounding error.
  String get amount {
    final String figure = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return unit.isEmpty ? figure : '$figure $unit';
  }

  @override
  bool operator ==(Object other) =>
      other is MealIngredient &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.isOptional == isOptional &&
      other.isStaple == isStaple;

  @override
  int get hashCode => Object.hash(name, quantity, unit, isOptional, isStaple);

  @override
  String toString() => 'MealIngredient($name, $amount)';
}
