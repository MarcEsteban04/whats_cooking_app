import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// Reads and writes what the household has eaten (Sprint 31).
///
/// The loop docs/project_dev.md draws for this sprint:
/// `Roulette → Accepted Meal → Meal History → Recommendation Engine`. The first
/// three arrows are this contract; the fourth is Sprint 32, which reads what
/// this writes in order to stop offering last night's dinner.
///
/// Household-scoped, because the question is "what did *we* eat". The
/// `household members read history` policy returns everyone's rows and this
/// deliberately does not narrow them — unlike favourites, where reading the
/// household's would have been a bug. Two people cooking for each other have one
/// history, not two halves of one.
abstract interface class MealHistoryRepository {
  /// Records a decision, and returns it as stored.
  ///
  /// Returns rather than voids because the id is the route: the decided screen
  /// lives at `/home/decided/:historyId`, and a caller that had to go looking for
  /// the row it just wrote would be racing its own insert.
  ///
  /// [actualCost] is left null by the roulette on purpose. At the moment somebody
  /// accepts a meal, nobody knows what it cost — and writing the estimate into a
  /// column named `actual_cost` produces a number that gets read as a fact later.
  Future<MealHistoryEntry> record({
    required Meal meal,
    HistorySource source,
    double? actualCost,
    bool wasCooked,
  });

  /// The most recent entries, newest first.
  ///
  /// Unpaged, with a limit. This list answers "what have we been eating lately",
  /// and paging a year of dinners would be a scrolling controller built for a
  /// question nobody asked.
  Future<List<MealHistoryEntry>> recent({int limit});

  /// One entry, for the decided screen.
  ///
  /// Separate from [record] because that screen is a route: it has to survive a
  /// restart, a deep link, or somebody coming back to it, and none of those have
  /// the object the insert returned.
  Future<MealHistoryEntry> byId(String id);
}

/// How many entries a history read asks for.
///
/// About a month of dinners: enough to see a pattern, which is what the screen is
/// for, and few enough to be one request.
const int kHistoryPageSize = 40;
