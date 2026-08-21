import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/repositories/pantry_repository.dart';

/// [PantryRepository] with no backend behind it.
///
/// So a clone with no Supabase credentials still runs (supabase/README.md). The
/// kitchen does not survive a restart, and the log says so when this is chosen.
class InMemoryPantryRepository implements PantryRepository {
  final List<PantryItem> _items = <PantryItem>[];

  int _nextId = 0;

  /// A small vocabulary to autocomplete against, so the add sheet behaves the
  /// same way it does with a database — which is the only reason this class has
  /// any ingredients in it at all.
  static const List<(String, IngredientCategory, String)> _vocabulary =
      <(String, IngredientCategory, String)>[
        ('chicken', IngredientCategory.protein, 'g'),
        ('pork', IngredientCategory.protein, 'g'),
        ('beef', IngredientCategory.protein, 'g'),
        ('eggs', IngredientCategory.protein, 'pc'),
        ('rice', IngredientCategory.grain, 'kg'),
        ('garlic', IngredientCategory.vegetable, 'bulb'),
        ('onion', IngredientCategory.vegetable, 'pc'),
        ('potato', IngredientCategory.vegetable, 'g'),
        ('tomato', IngredientCategory.vegetable, 'pc'),
        ('soy sauce', IngredientCategory.condiment, 'bottle'),
        ('vinegar', IngredientCategory.condiment, 'bottle'),
        ('cooking oil', IngredientCategory.condiment, 'bottle'),
        ('salt', IngredientCategory.spice, 'pack'),
        ('black pepper', IngredientCategory.spice, 'pack'),
        ('milk', IngredientCategory.dairy, 'ml'),
        ('cheese', IngredientCategory.dairy, 'g'),
      ];

  @override
  Future<List<PantryItem>> items() async {
    final List<PantryItem> sorted = List<PantryItem>.of(_items)
      ..sort((PantryItem a, PantryItem b) {
        final int byCategory = a.category.index.compareTo(b.category.index);
        return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
      });
    return sorted;
  }

  @override
  Future<PantryItem> add({
    required String name,
    double? quantity,
    String unit = '',
    DateTime? expiresOn,
  }) async {
    final String normalised = name.trim().toLowerCase();
    if (normalised.isEmpty) {
      throw const ValidationException(message: 'Give the ingredient a name.');
    }

    final (String, IngredientCategory, String)? known = _vocabulary
        .where((
          (String, IngredientCategory, String) entry,
        ) => entry.$1 == normalised)
        .firstOrNull;

    // Same uniqueness the real table enforces: adding chicken twice replaces the
    // amount rather than making a second row.
    final int existing = _items.indexWhere(
      (PantryItem item) => item.name == normalised,
    );

    final PantryItem item = PantryItem(
      id: existing >= 0 ? _items[existing].id : 'pantry-${_nextId++}',
      ingredientId: 'ingredient-$normalised',
      name: normalised,
      category: known?.$2 ?? IngredientCategory.other,
      quantity: quantity,
      unit: unit.trim(),
      expiresOn: expiresOn,
    );

    if (existing >= 0) {
      _items[existing] = item;
    } else {
      _items.add(item);
    }
    return item;
  }

  @override
  Future<PantryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    bool clearQuantity = false,
    bool clearExpiry = false,
  }) async {
    final int index = _items.indexWhere((PantryItem item) => item.id == id);
    if (index < 0) {
      throw const NotFoundException(message: 'That is no longer in your pantry.');
    }

    final PantryItem updated = _items[index].copyWith(
      quantity: quantity,
      unit: unit,
      expiresOn: expiresOn,
      clearQuantity: clearQuantity,
      clearExpiry: clearExpiry,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((PantryItem item) => item.id == id);
  }

  @override
  Future<List<IngredientSuggestion>> suggest(String query) async {
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return const <IngredientSuggestion>[];
    }

    return <IngredientSuggestion>[
      for (final (String name, IngredientCategory category, String unit)
          in _vocabulary)
        if (name.startsWith(term))
          IngredientSuggestion(
            id: 'ingredient-$name',
            name: name,
            category: category,
            defaultUnit: unit,
          ),
    ];
  }
}
