import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/pantry/data/repositories/in_memory_pantry_repository.dart';
import 'package:whats_cooking/features/pantry/data/repositories/supabase_pantry_repository.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/repositories/pantry_repository.dart';

part 'pantry_controller.g.dart';

/// The pantry backend.
@Riverpod(keepAlive: true)
PantryRepository pantryRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: the pantry will not survive a restart.',
      name: 'pantryRepository',
    );
    return InMemoryPantryRepository();
  }

  return SupabasePantryRepository(ref.read(supabaseClientProvider));
}

/// What is in the kitchen (Sprint 39).
///
/// **Optimistic on every write.** A pantry is edited standing at an open fridge,
/// often several items at a time, and a spinner between each one turns a
/// thirty-second job into a two-minute one. So the list changes first and the
/// request follows; a failure puts the old list back and hands the caller the
/// reason, which is the same shape favourites and dislikes already use.
///
/// `keepAlive`, because from Sprint 41 the roulette reads this before every spin
/// and re-fetching a list that has not changed would put a round trip inside the
/// one interaction that must not wait.
@Riverpod(keepAlive: true)
class PantryController extends _$PantryController {
  @override
  Future<List<PantryItem>> build() => ref.read(pantryRepositoryProvider).items();

  /// Puts something in the kitchen, or updates what is there.
  ///
  /// Returns the failure rather than throwing, so the sheet that called it can say
  /// so without a try/catch at every call site.
  Future<AppException?> add({
    required String name,
    double? quantity,
    String unit = '',
    DateTime? expiresOn,
  }) async {
    return _write(
      () => ref.read(pantryRepositoryProvider).add(
        name: name,
        quantity: quantity,
        unit: unit,
        expiresOn: expiresOn,
      ),
      // Not optimistic, unlike the other two. An add has to resolve a name
      // against the vocabulary — possibly creating the row — so the id, the
      // category and whether it is a staple are all things only the server knows.
      // Guessing them would show the reader a wrong aisle for a second.
      optimistic: null,
    );
  }

  /// Changes an amount.
  Future<AppException?> updateAmount(
    PantryItem item, {
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    bool clearQuantity = false,
    bool clearExpiry = false,
  }) {
    final PantryItem next = item.copyWith(
      quantity: quantity,
      unit: unit,
      expiresOn: expiresOn,
      clearQuantity: clearQuantity,
      clearExpiry: clearExpiry,
    );

    return _write(
      () => ref.read(pantryRepositoryProvider).updateAmount(
        item.id,
        quantity: quantity,
        unit: unit,
        expiresOn: expiresOn,
        clearQuantity: clearQuantity,
        clearExpiry: clearExpiry,
      ),
      optimistic: <PantryItem>[
        for (final PantryItem existing in state.value ?? const <PantryItem>[])
          if (existing.id == item.id) next else existing,
      ],
    );
  }

  /// Takes something out.
  Future<AppException?> remove(PantryItem item) async {
    final List<PantryItem> before = state.value ?? const <PantryItem>[];
    final List<PantryItem> without = <PantryItem>[
      for (final PantryItem existing in before)
        if (existing.id != item.id) existing,
    ];

    state = AsyncData<List<PantryItem>>(without);

    try {
      await ref.read(pantryRepositoryProvider).remove(item.id);
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<PantryItem>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Re-reads the kitchen, for pull-to-refresh.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(pantryRepositoryProvider).items(),
    );
  }

  /// Runs [operation], showing [optimistic] first when there is one.
  ///
  /// The returned item is merged rather than the whole list re-fetched. A refetch
  /// after every add is a round trip to learn something the response already
  /// said, and on a slow connection it is the one that makes adding four things
  /// feel broken.
  Future<AppException?> _write(
    Future<PantryItem> Function() operation, {
    required List<PantryItem>? optimistic,
  }) async {
    final List<PantryItem> before = state.value ?? const <PantryItem>[];

    if (optimistic case final List<PantryItem> next) {
      state = AsyncData<List<PantryItem>>(next);
    }

    try {
      final PantryItem saved = await operation();
      state = AsyncData<List<PantryItem>>(_merge(state.value ?? before, saved));
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<PantryItem>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// [items] with [saved] replacing its match, or appended, and re-sorted.
  ///
  /// Sorted here as well as in the repository so a newly added item lands in its
  /// own aisle rather than at the bottom of the list — the order is the feature,
  /// and an item that appears in the wrong group and moves on the next refresh
  /// reads as a bug.
  static List<PantryItem> _merge(List<PantryItem> items, PantryItem saved) {
    final List<PantryItem> next = <PantryItem>[
      for (final PantryItem item in items)
        if (item.id != saved.id) item,
      saved,
    ]..sort((PantryItem a, PantryItem b) {
      final int byCategory = a.category.index.compareTo(b.category.index);
      return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
    });

    return next;
  }
}

/// Names the vocabulary knows, for the add sheet's field.
///
/// Family-keyed on the query so each prefix is cached for the length of the sheet
/// — backspacing from "chicke" to "chick" reuses an answer already on the device
/// rather than asking again.
///
/// Not `keepAlive`: these are throwaway lookups, and holding every prefix
/// somebody has ever typed would be a cache with no eviction.
@riverpod
Future<List<IngredientSuggestion>> ingredientSuggestions(
  Ref ref,
  String query,
) {
  return ref.read(pantryRepositoryProvider).suggest(query);
}
