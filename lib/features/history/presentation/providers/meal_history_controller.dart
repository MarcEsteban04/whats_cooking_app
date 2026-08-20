import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/core/utils/provider_cache.dart';
import 'package:whats_cooking/features/history/data/repositories/in_memory_meal_history_repository.dart';
import 'package:whats_cooking/features/history/data/repositories/supabase_meal_history_repository.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/domain/repositories/meal_history_repository.dart';

part 'meal_history_controller.g.dart';

/// The history backend.
///
/// `keepAlive`, and the in-memory fallback is a singleton for the same reason
/// every other one here is: a new instance per read would forget what was just
/// recorded, and a credential-less clone would look like the write had failed.
@Riverpod(keepAlive: true)
MealHistoryRepository mealHistoryRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: meal history will not survive a restart.',
      name: 'mealHistoryRepository',
    );
    return InMemoryMealHistoryRepository();
  }

  return SupabaseMealHistoryRepository(ref.read(supabaseClientProvider));
}

/// What the household has eaten lately (Sprint 31).
///
/// Invalidated by whoever writes — the result screen after an accept — rather
/// than polled. Cached for a window on top of that, so stepping into an entry and
/// back does not re-read a list that cannot have changed in between.
@riverpod
Future<List<MealHistoryEntry>> mealHistory(Ref ref) {
  ref.cacheFor(kReadCacheWindow);

  return ref.read(mealHistoryRepositoryProvider).recent();
}

/// One entry, for the decided screen.
///
/// A family keyed by id, and cached, because that screen is reachable twice in a
/// row: accept a meal, look at it, go back, and the celebration is one tap away
/// again from the history list.
@riverpod
Future<MealHistoryEntry> historyEntry(Ref ref, String id) {
  ref.cacheFor(kReadCacheWindow);

  return ref.read(mealHistoryRepositoryProvider).byId(id);
}
