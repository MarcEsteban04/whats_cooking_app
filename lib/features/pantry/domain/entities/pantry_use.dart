import 'package:flutter/foundation.dart';

/// One thing cooking a meal would take out of the kitchen (Sprint 54).
///
/// Returned by `pantry_used_by_meal()`, which reads and decides nothing — the
/// arithmetic and the asking both happen here, because only the person who cooked
/// knows whether the recipe's 500 g was the last of it.
@immutable
class PantryUse {
  const PantryUse({
    required this.itemId,
    required this.name,
    required this.haveQuantity,
    required this.haveUnit,
    required this.needsQuantity,
    required this.needsUnit,
  });

  factory PantryUse.fromRow(Map<String, dynamic> row) {
    return PantryUse(
      itemId: row['pantry_item_id'] as String,
      name: row['ingredient_name'] as String? ?? '',
      haveQuantity: (row['have_quantity'] as num?)?.toDouble(),
      haveUnit: row['have_unit'] as String? ?? '',
      needsQuantity: (row['needs_quantity'] as num?)?.toDouble(),
      needsUnit: row['needs_unit'] as String? ?? '',
    );
  }

  final String itemId;
  final String name;

  /// What the kitchen says it has. Null means "we have some".
  final double? haveQuantity;
  final String haveUnit;

  /// What the recipe asks for.
  final double? needsQuantity;
  final String needsUnit;

  /// What is left if the recipe's amount is taken out, or null when that cannot
  /// be worked out.
  ///
  /// **Units are never converted**, which is this app's rule everywhere
  /// (`PantryItem`): 500 g minus 2 cups is not arithmetic, it is a guess dressed
  /// as one. So a mismatch produces null and the row offers removal instead of a
  /// wrong number.
  ///
  /// A null `haveQuantity` also produces null. "We have some" minus 500 g is not
  /// a quantity either — and that is the honest answer for a bottle of soy sauce,
  /// which one meal does not finish.
  double? get remaining {
    final double? have = haveQuantity;
    final double? needs = needsQuantity;

    if (have == null || needs == null) {
      return null;
    }
    if (haveUnit.trim().toLowerCase() != needsUnit.trim().toLowerCase()) {
      return null;
    }
    return have - needs;
  }

  /// Whether taking this out empties the shelf.
  ///
  /// True when the arithmetic works and lands at or below zero. **Not** true when
  /// the arithmetic does not work — an unknown amount is not an empty one, and
  /// defaulting to removal would quietly delete the soy sauce every time somebody
  /// cooked with it.
  bool get isUsedUp {
    final double? left = remaining;
    return left != null && left <= 0;
  }

  /// What the row says will happen — `500 g → 200 g`, `all of it`, `some of it`.
  String get outcome {
    if (isUsedUp) {
      return 'all of it';
    }

    if (remaining case final double left) {
      return '${_figure(left)}${haveUnit.isEmpty ? '' : ' $haveUnit'} left';
    }

    // No arithmetic possible. Says what the recipe wanted rather than pretending
    // to know what is left, so the reader can decide from the real numbers.
    if (needsQuantity case final double needs) {
      return 'recipe used ${_figure(needs)}'
          '${needsUnit.isEmpty ? '' : ' $needsUnit'}';
    }
    return 'used some';
  }

  /// `2` rather than `2.0`, and `1.5` when it matters.
  static String _figure(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}
