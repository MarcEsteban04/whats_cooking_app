import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/meals/data/repositories/in_memory_dislikes_repository.dart';
import 'package:whats_cooking/features/meals/data/repositories/supabase_dislikes_repository.dart';
import 'package:whats_cooking/features/meals/domain/repositories/dislikes_repository.dart';

part 'dislikes_controller.g.dart';

/// The dislikes backend.
@Riverpod(keepAlive: true)
DislikesRepository dislikesRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: hidden meals will not survive a restart.',
      name: 'dislikesRepository',
    );
    return InMemoryDislikesRepository();
  }

  return SupabaseDislikesRepository(ref.read(supabaseClientProvider));
}

/// Which meals this user has hidden (Sprint 25).
///
/// **One set, and it is the feed's exclusion list.** `MealsController` reads it
/// before every first page and watches it for changes, so hiding a meal removes
/// it from the feed without the screen that did the hiding having to know a feed
/// exists. That is the whole point of keeping it here rather than in a widget:
/// US-B-07 promises a disliked meal is *never* suggested, and a promise that
/// depends on every caller remembering to filter is a promise that breaks.
///
/// No `toggle`, deliberately, unlike favourites. The two directions are not
/// symmetrical: hiding is destructive-feeling and asks for confirmation
/// (docs/USER_FLOWS.md §10), un-hiding is not and does not. A single `toggle`
/// would invite a caller to hide without asking.
///
/// `keepAlive`, so switching tabs does not re-fetch a set that has not changed.
@Riverpod(keepAlive: true)
class DislikesController extends _$DislikesController {
  @override
  Future<Set<String>> build() => ref.read(dislikesRepositoryProvider).mealIds();

  bool isHidden(String mealId) => state.value?.contains(mealId) ?? false;

  /// Hides a meal, optimistically.
  ///
  /// Returns the failure so the caller can say so; nothing is thrown.
  Future<AppException?> hide(String mealId) => _write(mealId, hidden: true);

  /// Brings a meal back.
  Future<AppException?> restore(String mealId) => _write(mealId, hidden: false);

  /// Re-reads the set from the backend.
  ///
  /// For pull-to-refresh. Changes made on another device while the app is open
  /// are not covered — that needs a realtime subscription, which is not in this
  /// sprint.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(dislikesRepositoryProvider).mealIds(),
    );
  }

  Future<AppException?> _write(String mealId, {required bool hidden}) async {
    final Set<String>? current = state.value;
    if (current == null) {
      // Still loading, or the initial read failed. Writing against a set whose
      // true contents are unknown would guess, and guessing wrong here either
      // un-hides something or hides something the user never chose.
      return null;
    }

    if (current.contains(mealId) == hidden) {
      // Already in the requested state. The write would be a no-op on the
      // server too — both directions are idempotent — but skipping it also
      // skips a round trip and a pointless optimistic flicker.
      return null;
    }

    final Set<String> optimistic = <String>{...current};
    if (hidden) {
      optimistic.add(mealId);
    } else {
      optimistic.remove(mealId);
    }
    state = AsyncValue<Set<String>>.data(optimistic);

    try {
      final DislikesRepository repository = ref.read(
        dislikesRepositoryProvider,
      );
      if (hidden) {
        await repository.add(mealId);
      } else {
        await repository.remove(mealId);
      }
      return null;
    } on Object catch (error, stackTrace) {
      // Rolled back against the *live* state rather than the snapshot above:
      // another meal may have been hidden while this write was in flight, and
      // restoring the old snapshot wholesale would undo that one too.
      final Set<String> live = <String>{...?state.value};
      if (hidden) {
        live.remove(mealId);
      } else {
        live.add(mealId);
      }
      state = AsyncValue<Set<String>>.data(live);

      return ErrorMapper.map(error, stackTrace);
    }
  }
}
