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

  /// The row [MealIngredient.fromRow] would decode back into this (Sprint 27).
  ///
  /// The PostgREST shape rather than a flat one, so the cache stores what the
  /// wire stores and there is exactly one decoder. A second, cache-only format
  /// would be a second thing to keep in step with the query.
  Map<String, dynamic> toRow() => <String, dynamic>{
    'quantity': quantity,
    'unit': unit,
    'is_optional': isOptional,
    'ingredients': <String, dynamic>{'name': name, 'is_staple': isStaple},
  };

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

  /// The same ingredient for a different number of people (Sprint 55).
  ///
  /// **Countable things round up, measured things do not.** Halving a recipe for
  /// four eggs gives two, and halving one for three gives two as well — because
  /// the alternative is a screen that asks somebody to use 1.5 eggs, and nobody
  /// has ever done that. But halving 500 g of chicken gives 250 g, and rounding
  /// *that* up to 300 would be the app inventing a hundred grams of meat.
  ///
  /// So the rule follows the unit: pieces, cloves and slices are things you can
  /// count, and a fraction of one is not an instruction. Grams and millilitres
  /// are things you weigh, and the fraction is the answer.
  ///
  /// Rounding **up** rather than to nearest, for the countable case: an extra
  /// clove of garlic is a slightly stronger dinner, and one clove short of a
  /// recipe that needed two is a different dish.
  MealIngredient scaledBy(double factor) {
    if (factor == 1 || quantity == 0) {
      return this;
    }

    final double scaled = quantity * factor;

    return MealIngredient(
      name: name,
      quantity: _isCountable
          ? scaled.ceilToDouble()
          // One decimal, matching what `amount` will print. Rounded here rather
          // than left at full precision so the value a caller reads back is the
          // value the screen showed — 166.66666 g displayed as "166.7 g" and
          // then used in arithmetic is two different numbers.
          : double.parse(scaled.toStringAsFixed(1)),
      unit: unit,
      isOptional: isOptional,
      isStaple: isStaple,
    );
  }

  /// Whether this unit counts whole things rather than measuring them.
  ///
  /// An empty unit counts too — "2 onions" is stored with no unit at all, and
  /// half an onion asked for by a screen is a screen nobody trusts.
  bool get _isCountable {
    final String normalized = unit.trim().toLowerCase();
    return normalized.isEmpty || _countableUnits.contains(normalized);
  }

  /// Deliberately short, and singular and plural both spelled out.
  ///
  /// The unit is free text typed by whoever added the meal, so this cannot be
  /// exhaustive — and it does not need to be. A unit not on this list is treated
  /// as measured, which is the safe direction: showing "1.5 tbsp" is a mild
  /// annoyance, where silently rounding 250 g of beef up to 300 is a wrong
  /// recipe.
  static const Set<String> _countableUnits = <String>{
    'pc',
    'pcs',
    'piece',
    'pieces',
    'clove',
    'cloves',
    'slice',
    'slices',
    'egg',
    'eggs',
    'can',
    'cans',
    'pack',
    'packs',
    'bunch',
    'bunches',
    'stalk',
    'stalks',
    'sheet',
    'sheets',
    'whole',
  };

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
