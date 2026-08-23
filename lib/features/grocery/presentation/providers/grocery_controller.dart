import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/grocery/data/repositories/in_memory_grocery_repository.dart';
import 'package:whats_cooking/features/grocery/data/repositories/supabase_grocery_repository.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/domain/repositories/grocery_repository.dart';

part 'grocery_controller.g.dart';

/// The grocery backend.
@Riverpod(keepAlive: true)
GroceryRepository groceryRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: the shopping list will not survive a restart.',
      name: 'groceryRepository',
    );
    return InMemoryGroceryRepository();
  }

  return SupabaseGroceryRepository(ref.read(supabaseClientProvider));
}

/// What we need to buy (Sprint 42).
///
/// **Ticking is optimistic, and this is the screen where that matters most.** It
/// is used one-handed, in a shop, on whatever signal a supermarket has — and a
/// checkbox that waits for a round trip is a checkbox somebody taps twice. The
/// line changes immediately, the request follows, and a failure puts it back with
/// the reason.
///
/// **A ticked line stays where it is.** No re-sorting, no removal — docs/USER_FLOWS
/// §13 and design_ui §23 both say so, and the reason is physical: things that
/// disappear under your thumb in an aisle make you lose your place. Clearing them
/// is a separate, deliberate action.
///
/// `keepAlive`, because from Sprint 43 accepting a meal writes to this list and
/// the screen should already know.
@Riverpod(keepAlive: true)
class GroceryController extends _$GroceryController {
  @override
  Future<List<GroceryItem>> build() =>
      ref.read(groceryRepositoryProvider).items();

  /// Puts something on the list, merging with what is already there.
  Future<AppException?> add({
    required String name,
    double? quantity,
    String unit = '',
  }) {
    return _write(
      () => ref
          .read(groceryRepositoryProvider)
          .add(name: name, quantity: quantity, unit: unit),
      // Not optimistic. An add either creates a line or merges into one, and only
      // the server knows which — guessing would either show a duplicate for a
      // moment or hide a merge that did not happen.
      optimistic: null,
    );
  }

  /// Puts a meal's missing ingredients on the list (Sprint 43).
  ///
  /// Returns how many lines it touched. **Zero is a good answer** — it means the
  /// kitchen already had everything — so the caller has to be able to tell that
  /// apart from a failure, which is why this returns a pair rather than a count.
  ///
  /// Not optimistic, and it re-reads rather than merging a response. The function
  /// may have updated three lines and inserted two, and reconstructing that from
  /// a single integer is guesswork — this is also the one grocery write nobody is
  /// standing in a shop waiting for.
  Future<(int, AppException?)> addMissingForMeal(String mealId) async {
    try {
      final int touched = await ref
          .read(groceryRepositoryProvider)
          .addMissingForMeal(mealId);

      if (touched > 0) {
        await refresh();
      }
      return (touched, null);
    } on Object catch (error, stackTrace) {
      return (0, ErrorMapper.map(error, stackTrace));
    }
  }

  /// Ticks a line, or un-ticks it.
  Future<AppException?> setCompleted(
    GroceryItem item, {
    required bool isCompleted,
  }) {
    return _write(
      () => ref
          .read(groceryRepositoryProvider)
          .setCompleted(item.id, isCompleted: isCompleted),
      optimistic: _replacing(item.copyWith(isCompleted: isCompleted)),
    );
  }

  /// Changes how much of something is wanted.
  Future<AppException?> updateAmount(
    GroceryItem item, {
    double? quantity,
    String? unit,
    bool clearQuantity = false,
  }) {
    return _write(
      () => ref
          .read(groceryRepositoryProvider)
          .updateAmount(
            item.id,
            quantity: quantity,
            unit: unit,
            clearQuantity: clearQuantity,
          ),
      optimistic: _replacing(
        item.copyWith(
          quantity: quantity,
          unit: unit,
          clearQuantity: clearQuantity,
        ),
      ),
    );
  }

  /// Takes a line off.
  Future<AppException?> remove(GroceryItem item) async {
    final List<GroceryItem> before = state.value ?? const <GroceryItem>[];

    state = AsyncData<List<GroceryItem>>(<GroceryItem>[
      for (final GroceryItem existing in before)
        if (existing.id != item.id) existing,
    ]);

    try {
      await ref.read(groceryRepositoryProvider).remove(item.id);
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<GroceryItem>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Removes everything already ticked.
  ///
  /// Returns how many went, or the failure. Both, because the caller has
  /// something to say either way — "cleared 6" is a confirmation, and a list that
  /// silently shortens is a list you check twice.
  Future<(int, AppException?)> clearCompleted() async {
    final List<GroceryItem> before = state.value ?? const <GroceryItem>[];

    state = AsyncData<List<GroceryItem>>(<GroceryItem>[
      for (final GroceryItem item in before)
        if (!item.isCompleted) item,
    ]);

    try {
      final int gone = await ref
          .read(groceryRepositoryProvider)
          .clearCompleted();
      return (gone, null);
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<GroceryItem>>(before);
      return (0, ErrorMapper.map(error, stackTrace));
    }
  }

  /// Re-reads the list, for pull-to-refresh.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(groceryRepositoryProvider).items(),
    );
  }

  /// The current list with [item] swapped in, for an optimistic update.
  List<GroceryItem> _replacing(GroceryItem item) => <GroceryItem>[
    for (final GroceryItem existing in state.value ?? const <GroceryItem>[])
      if (existing.id == item.id) item else existing,
  ];

  Future<AppException?> _write(
    Future<GroceryItem> Function() operation, {
    required List<GroceryItem>? optimistic,
  }) async {
    final List<GroceryItem> before = state.value ?? const <GroceryItem>[];

    if (optimistic case final List<GroceryItem> next) {
      state = AsyncData<List<GroceryItem>>(next);
    }

    try {
      final GroceryItem saved = await operation();
      state = AsyncData<List<GroceryItem>>(
        _merge(state.value ?? before, saved),
      );
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<GroceryItem>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// [items] with [saved] replacing its match, or appended, and re-sorted by
  /// aisle.
  ///
  /// Sorted here as well as in the repository so a newly added line lands in the
  /// aisle it belongs to rather than at the bottom — the order is what makes the
  /// list walkable, and a line that appears in the wrong place and moves on the
  /// next refresh reads as a bug.
  static List<GroceryItem> _merge(List<GroceryItem> items, GroceryItem saved) {
    return <GroceryItem>[
      for (final GroceryItem item in items)
        if (item.id != saved.id) item,
      saved,
    ]..sort((GroceryItem a, GroceryItem b) {
      final int byAisle = a.category.index.compareTo(b.category.index);
      return byAisle != 0 ? byAisle : a.name.compareTo(b.name);
    });
  }
}
