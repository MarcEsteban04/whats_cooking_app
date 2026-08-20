import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/meals/data/repositories/in_memory_favorites_repository.dart';
import 'package:whats_cooking/features/meals/data/repositories/supabase_favorites_repository.dart';
import 'package:whats_cooking/features/meals/domain/repositories/favorites_repository.dart';

part 'favorites_controller.g.dart';

/// The favourites backend.
@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: favourites will not survive a restart.',
      name: 'favoritesRepository',
    );
    return InMemoryFavoritesRepository();
  }

  return SupabaseFavoritesRepository(ref.read(supabaseClientProvider));
}

/// Which meals this user has saved (Sprint 24).
///
/// **One set, read by every heart in the app.** That is what makes the feature
/// feel coherent: favourite something on the detail screen and the heart on the
/// feed row behind it is already filled, because both read this provider rather
/// than each holding their own copy. It is also the "favourite synchronisation"
/// the sprint asks for, within a session.
///
/// `keepAlive`, so switching tabs does not re-fetch a set that has not changed.
@Riverpod(keepAlive: true)
class FavoritesController extends _$FavoritesController {
  @override
  Future<Set<String>> build() =>
      ref.read(favoritesRepositoryProvider).mealIds();

  bool isFavorite(String mealId) => state.value?.contains(mealId) ?? false;

  /// Flips one meal, optimistically.
  ///
  /// The heart moves immediately and the write happens behind it, because a
  /// favourite that waits for the network feels broken (docs/COMPONENTS.md §11).
  /// The corollary is that a failed write **must** put it back: an optimistic
  /// update that does not roll back tells the user their tap landed when it did
  /// not, which is worse than making them wait.
  ///
  /// Returns the failure, so the caller can say so. Nothing is thrown — a
  /// screen should not need a try/catch around a heart.
  Future<AppException?> toggle(String mealId) async {
    final Set<String>? current = state.value;
    if (current == null) {
      // Still loading, or the initial read failed. Flipping a heart whose true
      // state is unknown would guess, and guessing wrong deletes a favourite.
      return null;
    }

    final bool wasFavorite = current.contains(mealId);
    final Set<String> optimistic = <String>{...current};
    if (wasFavorite) {
      optimistic.remove(mealId);
    } else {
      optimistic.add(mealId);
    }

    state = AsyncValue<Set<String>>.data(optimistic);

    try {
      final FavoritesRepository repository = ref.read(
        favoritesRepositoryProvider,
      );
      if (wasFavorite) {
        await repository.remove(mealId);
      } else {
        await repository.add(mealId);
      }
      return null;
    } on Object catch (error, stackTrace) {
      // Rolled back against the *live* state rather than the snapshot taken
      // above: another heart may have been tapped while this write was in
      // flight, and restoring the old snapshot wholesale would undo that too.
      final Set<String> live = <String>{...?state.value};
      if (wasFavorite) {
        live.add(mealId);
      } else {
        live.remove(mealId);
      }
      state = AsyncValue<Set<String>>.data(live);

      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Re-reads the set from the backend.
  ///
  /// For pull-to-refresh, and for the moment after signing in on a second
  /// device. Cross-device changes that arrive while the app is open are not
  /// covered — that needs a realtime subscription, which is not in this sprint.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(favoritesRepositoryProvider).mealIds(),
    );
  }
}
