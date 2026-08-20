import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/domain/repositories/meal_history_repository.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// [MealHistoryRepository] held in memory.
///
/// The no-backend fallback and the tests' backend. It really does record, unlike
/// the AI fallback which refuses: accepting a meal and seeing it appear in the
/// history is the loop this sprint builds, and a fallback that silently dropped
/// the write would make a credential-less clone look broken rather than
/// backend-less.
class InMemoryMealHistoryRepository implements MealHistoryRepository {
  InMemoryMealHistoryRepository({
    List<MealHistoryEntry>? initial,
    this.latency = _defaultLatency,
  }) : _entries = List<MealHistoryEntry>.of(initial ?? const []);

  final List<MealHistoryEntry> _entries;

  /// Simulated round trip. Exposed so a widget test can advance the fake clock
  /// past it rather than awaiting a real delay, which deadlocks the binding.
  final Duration latency;

  /// Set to make every write fail.
  bool failWrites = false;

  /// Set to make every read fail.
  bool failReads = false;

  /// The clock, injectable so a test can write a history that spans days without
  /// waiting any.
  DateTime Function() now = DateTime.now;

  @override
  Future<MealHistoryEntry> record({
    required Meal meal,
    HistorySource source = HistorySource.roulette,
    double? actualCost,
    bool wasCooked = true,
  }) async {
    await Future<void>.delayed(latency);

    if (failWrites) {
      throw const ServerException();
    }

    final MealHistoryEntry entry = MealHistoryEntry(
      // Sequential rather than random, so a test can predict it and two entries
      // written in the same millisecond cannot collide.
      id: 'local-history-${_entries.length + 1}',
      mealId: meal.id,
      eatenAt: now(),
      mealType: meal.category,
      source: source,
      meal: meal,
      actualCost: actualCost,
      wasCooked: wasCooked,
    );

    _entries.add(entry);
    return entry;
  }

  @override
  Future<List<MealHistoryEntry>> recent({int limit = kHistoryPageSize}) async {
    await Future<void>.delayed(latency);

    if (failReads) {
      throw const ServerException();
    }

    // Sorted the way the server sorts, with the id as tiebreaker, so a test that
    // passes here means something about the app people use.
    final List<MealHistoryEntry> sorted = List<MealHistoryEntry>.of(_entries)
      ..sort((MealHistoryEntry a, MealHistoryEntry b) {
        final int byDate = b.eatenAt.compareTo(a.eatenAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    return sorted.take(limit).toList();
  }

  @override
  Future<MealHistoryEntry> byId(String id) async {
    await Future<void>.delayed(latency);

    if (failReads) {
      throw const ServerException();
    }

    for (final MealHistoryEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }

    throw const NotFoundException(message: 'We could not find that meal');
  }

  static const Duration _defaultLatency = Duration(milliseconds: 150);
}
