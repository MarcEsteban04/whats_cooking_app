import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_spin_controller.dart';

part 'restaurant_visits.g.dart';

/// Every night out the household can still see (Sprint 55).
///
/// **The eat-out half of the app had no memory it could show.** `restaurant_history`
/// has been written to since Sprint 46 and read by exactly one thing: the scorer,
/// which used it to push down places visited recently. So the app knew where they
/// had been, used it against them, and never told them — the cooked side got a
/// whole "What we ate" screen from the same shape of table.
///
/// Not `keepAlive`. Two readers, both screens, and neither is on a hot path: the
/// spin builds its own penalty list from a *different* window and Home's settled
/// panel wants today only. A cached list here would mostly serve a screen nobody
/// has open, and would be stale the next time they did.
@riverpod
Future<List<RestaurantVisit>> restaurantVisits(Ref ref) {
  return ref
      .watch(restaurantHistoryRepositoryProvider)
      .recent(limit: _visitLimit);
}

/// Deep enough to be a history, shallow enough to be one query.
///
/// Matches the repository's own default and `mealHistory`'s window: a household
/// eating out once or twice a week has most of a year here, and anybody wanting
/// more than that wants a report rather than a screen.
const int _visitLimit = 40;
