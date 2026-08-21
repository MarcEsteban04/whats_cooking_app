import 'package:flutter/foundation.dart';

/// One line the assistant read off a shopping list (Sprint 53).
@immutable
class ImportedItem {
  const ImportedItem({required this.name, this.quantity, this.unit = ''});

  /// Lower cased and trimmed, matching how the grocery list stores names.
  final String name;

  /// Null means the list did not say — which is most lines.
  final double? quantity;

  /// As written. Empty when there is nothing to qualify.
  final String unit;

  ImportedItem copyWith({String? name}) =>
      ImportedItem(name: name ?? this.name, quantity: quantity, unit: unit);
}

/// What the assistant read off a photo, a text file or a PDF (Sprint 53).
///
/// **Quantities survive here, unlike the fridge scanner's.** A photo of a fridge
/// cannot say how much rice is in the bag, so the pantry takes names only. A
/// shopping list is the opposite: somebody wrote "2 kg rice" on purpose, and
/// dropping the 2 would make the imported line worse than the paper it came from.
///
/// Units are **not** snapped to a vocabulary. `grocery_items.unit` is free text by
/// design — the list is read in an aisle, not computed with — so "kg", "sachet"
/// and "bundle" all pass through as written. That is the opposite of
/// `DraftIngredient`, which validates against six units because a recipe's
/// quantities are arithmetic.
abstract final class ImportedList {
  /// Reads the reply into items.
  ///
  /// One per line, `quantity unit name` with the first two optional — the same
  /// tolerant shape `GeneratedRecipe` uses, and for the same reason: a labelled
  /// block that ends early still yields the first eight items, where a broken
  /// JSON array yields nothing.
  static List<ImportedItem> parse(String reply) {
    final List<ImportedItem> items = <ImportedItem>[];
    final Set<String> seen = <String>{};

    for (final String raw in reply.split('\n')) {
      final String line = _clean(raw);

      if (line.isEmpty || _isNone(line)) {
        continue;
      }

      // Prose rather than an item. A model that opens with "Here are the items
      // from your list:" is being helpful, and the helpfulness is what would end
      // up in an aisle as something to buy.
      if (line.length > _maxLineChars || line.split(' ').length > _maxWords) {
        continue;
      }

      final ImportedItem? item = _item(line);
      if (item == null || !seen.add(item.name)) {
        continue;
      }

      items.add(item);
      if (items.length >= _maxItems) {
        break;
      }
    }

    return items;
  }

  /// One line, minus its bullet, its checkbox and its case.
  static String _clean(String line) {
    String text = line.trim().replaceAll('**', '').replaceAll('`', '');

    // `- `, `* `, `1. `, `[ ] `, `[x] ` — a list written by hand or by an app.
    text = text
        .replaceFirst(RegExp(r'^\s*\[[ xX]?\]\s*'), '')
        .replaceFirst(RegExp(r'^\s*(?:[-*•]|\d{1,2}[.)])\s*'), '');

    return text.trim();
  }

  /// `2 kg rice`, `500g chicken`, `soy sauce`.
  static ImportedItem? _item(String text) {
    // Quantity, an optional unit run together or spaced, then the name. The unit
    // is only taken when a name follows it, so "2 eggs" is two eggs rather than
    // two "eggs" of nothing.
    final RegExpMatch? match = RegExp(
      r'^([\d]+(?:[.,]\d+)?)\s*([A-Za-z]{1,8})?\s+(.+)$',
    ).firstMatch(text);

    if (match == null) {
      final String name = text.toLowerCase();
      return name.isEmpty ? null : ImportedItem(name: name);
    }

    final double? quantity = double.tryParse(
      (match.group(1) ?? '').replaceAll(',', '.'),
    );
    final String word = (match.group(2) ?? '').toLowerCase();
    final String rest = (match.group(3) ?? '').trim().toLowerCase();

    // A word in the unit slot that is not a measure is part of the name — "2
    // large onions" is two onions, not two larges.
    final bool isUnit = _units.contains(word);
    final String name = isUnit ? rest : '$word $rest'.trim();

    if (name.isEmpty) {
      return null;
    }

    return ImportedItem(
      name: name,
      quantity: quantity == null || quantity <= 0 ? null : quantity,
      unit: isUnit ? word : '',
    );
  }

  static bool _isNone(String line) {
    final String lower = line.toLowerCase();
    return lower == 'none' || lower == 'nothing' || lower.startsWith('none ');
  }

  /// What counts as a measure rather than part of a name.
  ///
  /// Deliberately wider than `DraftIngredient.units`: this is not validated
  /// against anything, so recognising "kg" or "pack" only decides whether the
  /// word belongs in the unit column or in the name. Being wrong costs a slightly
  /// odd-looking line, not a rejected save.
  static const Set<String> _units = <String>{
    'g', 'kg', 'mg',
    'ml', 'l', 'liter', 'litre',
    'pc', 'pcs', 'piece', 'pieces',
    'pack', 'packs', 'sachet', 'sachets',
    'can', 'cans', 'bottle', 'bottles',
    'box', 'boxes', 'bag', 'bags',
    'bundle', 'bundles', 'kilo', 'kilos',
    'tbsp', 'tsp', 'cup', 'cups',
    'dozen', 'tray', 'trays',
  };

  /// Long enough for "spring onions, two bundles", short enough to exclude a
  /// sentence.
  static const int _maxLineChars = 60;
  static const int _maxWords = 6;

  /// A weekly shop, generously. Past this the confirmation list is longer than
  /// anybody reads, and the tail gets added unread.
  static const int _maxItems = 40;
}
