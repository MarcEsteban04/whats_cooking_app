import 'package:riverpod_annotation/riverpod_annotation.dart';
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
Future<List<Meal>> myMeals(Ref ref) => ref.read(mealRepositoryProvider).mine();
