import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/domain/repositories/grocery_repository.dart';

/// [GroceryRepository] with no backend behind it.
///
/// So a clone with no Supabase credentials still runs (supabase/README.md). The
/// list does not survive a restart, and the log says so when this is chosen.
class InMemoryGroceryRepository implements GroceryRepository {
  final List<GroceryItem> _items = <GroceryItem>[];

  int _nextId = 0;

  @override
  Future<List<GroceryItem>> items() async {
    final List<GroceryItem> sorted = List<GroceryItem>.of(_items)
      ..sort((GroceryItem a, GroceryItem b) {
        final int byAisle = a.category.index.compareTo(b.category.index);
        return byAisle != 0 ? byAisle : a.name.compareTo(b.name);
      });
    return sorted;
  }

  @override
  Future<GroceryItem> add({
    required String name,
    double? quantity,
    String unit = '',
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(message: 'Give the item a name.');
    }

    final GroceryItem candidate = GroceryItem(
      id: 'grocery-${_nextId++}',
      customName: trimmed,
      category: IngredientCategory.other,
      quantity: quantity,
      unit: unit.trim(),
    );

    // The same merge the real repository does: quantities add, and re-adding a
    // ticked line un-ticks it because wanting it again is what adding it means.
    final int existing = _items.indexWhere(
      (GroceryItem item) => item.isSameThingAs(candidate),
    );

    if (existing >= 0) {
      final GroceryItem current = _items[existing];
      final double? merged = switch ((current.quantity, quantity)) {
        (final double a, final double b) => a + b,
        (final double a, null) => a,
        (null, final double b) => b,
        _ => null,
      };

      final GroceryItem updated = current.copyWith(
        quantity: merged,
        unit: unit.trim().isEmpty ? current.unit : unit.trim(),
        isCompleted: false,
        clearQuantity: merged == null,
      );
      _items[existing] = updated;
      return updated;
    }

    _items.add(candidate);
    return candidate;
  }

  @override
  Future<int> addMissingForMeal(String mealId) async {
    // Always zero. The real answer joins the meal's recipe against the pantry,
    // neither of which exists here. Zero rather than unimplemented, because this
    // repository exists so the app runs without credentials — and "nothing was
    // added" is a true and harmless thing to report.
    return 0;
  }

  @override
  Future<GroceryItem> setCompleted(
    String id, {
    required bool isCompleted,
  }) async {
    return _mutate(
      id,
      (GroceryItem item) => item.copyWith(isCompleted: isCompleted),
    );
  }

  @override
  Future<GroceryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    bool clearQuantity = false,
  }) async {
    return _mutate(
      id,
      (GroceryItem item) => item.copyWith(
        quantity: quantity,
        unit: unit,
        clearQuantity: clearQuantity,
      ),
    );
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((GroceryItem item) => item.id == id);
  }

  @override
  Future<int> clearCompleted() async {
    final int before = _items.length;
    _items.removeWhere((GroceryItem item) => item.isCompleted);
    return before - _items.length;
  }

  GroceryItem _mutate(String id, GroceryItem Function(GroceryItem) change) {
    final int index = _items.indexWhere((GroceryItem item) => item.id == id);
    if (index < 0) {
      throw const NotFoundException(message: 'That is no longer on the list.');
    }
    return _items[index] = change(_items[index]);
  }
}
