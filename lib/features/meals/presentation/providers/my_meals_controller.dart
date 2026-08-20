import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/utils/provider_cache.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';

part 'my_meals_controller.g.dart';

/// The meals this household wrote (Sprint 26).
///
/// Unpaged, because `MealRepository.mine` is — a household's own recipes are
/// tens, not thousands.
///
/// A provider rather than state on the screen that shows it, because the writes
/// happen elsewhere: the form invalidates this after a save, and the detail
/// screen after a delete. State held in `MyMealsScreen` would mean a list that
/// is only right until something changes it from another route.
@riverpod
Future<List<Meal>> myMeals(Ref ref) {
  // Cached for a window (Sprint 27), so stepping into a recipe and back does
  // not re-read the whole list. Invalidated outright after a save or a delete,
  // which is the only time it is actually wrong.
  ref.cacheFor(kReadCacheWindow);

  return ref.read(mealRepositoryProvider).mine();
}
