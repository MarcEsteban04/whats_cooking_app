import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/meals/data/repositories/in_memory_meal_repository.dart';
import 'package:whats_cooking/features/meals/data/repositories/supabase_meal_repository.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';

part 'meal_repository_provider.g.dart';

/// The meal catalogue's backend.
///
/// Supabase when the build has credentials, the in-memory slice of the seed when
/// it does not — the same arrangement `authRepository` uses, and for the same
/// reason: a fresh clone should show a working feed rather than an error state.
///
/// Unlike authentication, there is nothing to lose here. Reading the catalogue
/// without a backend gives you twelve real meals instead of sixty; it does not
/// let you build up state that disappears. The banner on the auth screens says
/// which mode the app is in either way.
@Riverpod(keepAlive: true)
MealRepository mealRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: serving the built-in sample catalogue.',
      name: 'mealRepository',
    );
    return InMemoryMealRepository();
  }

  return SupabaseMealRepository(ref.read(supabaseClientProvider));
}
