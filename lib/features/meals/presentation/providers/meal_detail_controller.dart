import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';

part 'meal_detail_controller.g.dart';

/// One meal, with its ingredients (Sprint 23).
///
/// A family keyed by id rather than a single provider holding "the current
/// meal": two details can be on the navigator at once — tap a meal, then tap
/// something from its page — and a single slot would have the second overwrite
/// the first, so going back would show the wrong food.
///
/// `autoDispose`, unlike the feed. The feed is `keepAlive` because returning to
/// the tab should not re-fetch a scrolled list; a detail page is the opposite —
/// once it is off the navigator, holding its ingredients costs memory for a
/// screen nobody is looking at.
@riverpod
Future<Meal> mealDetail(Ref ref, String id) {
  return ref.read(mealRepositoryProvider).byId(id);
}
