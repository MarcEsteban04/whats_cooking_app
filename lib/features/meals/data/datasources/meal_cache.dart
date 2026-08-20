import 'package:whats_cooking/core/data/timestamped_store.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// The last catalogue page this device saw, on disk (Sprint 27).
///
/// **One page, unfiltered, and that is the whole design.** docs/ARCHITECTURE.md
/// §5 asks for the meal catalogue's first page to be cached for 24 hours, and
/// the temptation is to cache every query — which is a cache-invalidation
/// problem in exchange for nothing. A filtered result is cheap to re-fetch and
/// worthless offline, because the reader who applied that filter is holding a
/// phone with no signal and needs *something*, not their something. So: the
/// default first page, replaced whenever a default first page loads.
///
/// It exists to answer one question — "what can I cook, right now, with no
/// signal?" — which is the promise the roulette inherits
/// (docs/USER_FLOWS.md §18). Nothing reads it while the network is answering.
///
/// The id sets are here for the same reason and not as an afterthought: without
/// the dislikes, a cached page cannot honour the exclusion the app promises
/// (US-B-07), and the feed would rather fail than show a hidden meal. Without
/// the favourites, every heart on a cached page reads as empty, which is a lie
/// about the reader's own list.
class MealCache {
  const MealCache();

  /// Stores [meals] as the catalogue's first page.
  Future<void> writeFeed(List<Meal> meals, {required DateTime now}) {
    return _feed.write(<Map<String, dynamic>>[
      for (final Meal meal in meals) meal.toRow(),
    ], now: now);
  }

  /// The last stored first page, or null if there is nothing usable.
  Future<CachedMeals?> readFeed({required DateTime now}) async {
    final TimestampedValue? stored = await _feed.read(now: now);
    if (stored?.payload is! List<Object?>) {
      return null;
    }

    final List<Meal> meals = <Meal>[
      for (final Object? row in stored!.payload as List<Object?>)
        if (row is Map<String, dynamic>)
          // One bad row is skipped rather than failing the page, the same way
          // an unrecognised cuisine is. A cache that throws away 19 good meals
          // over the 20th is worse than no cache.
          if (_decode(row) case final Meal meal) meal,
    ];

    if (meals.isEmpty) {
      return null;
    }

    return CachedMeals(meals: meals, storedAt: stored.storedAt);
  }

  Future<void> writeFavorites(Set<String> ids, {required DateTime now}) =>
      _favorites.write(ids.toList(), now: now);

  Future<Set<String>?> readFavorites({required DateTime now}) =>
      _readIds(_favorites, now: now);

  Future<void> writeDislikes(Set<String> ids, {required DateTime now}) =>
      _dislikes.write(ids.toList(), now: now);

  Future<Set<String>?> readDislikes({required DateTime now}) =>
      _readIds(_dislikes, now: now);

  /// Drops everything this cache holds.
  ///
  /// Sign-out goes through `TimestampedStore.clearAll`, which sweeps every
  /// cache by key prefix so the auth feature does not have to know about this
  /// one. This stays for a caller that wants only the meals gone.
  Future<void> clear() async {
    await _feed.clear();
    await _favorites.clear();
    await _dislikes.clear();
  }

  Future<Set<String>?> _readIds(
    TimestampedStore store, {
    required DateTime now,
  }) async {
    final TimestampedValue? stored = await store.read(now: now);
    if (stored?.payload is! List<Object?>) {
      return null;
    }

    return <String>{
      for (final Object? id in stored!.payload as List<Object?>)
        if (id is String) id,
    };
  }

  static Meal? _decode(Map<String, dynamic> row) {
    try {
      return Meal.fromRow(row);
    } on Object catch (_) {
      return null;
    }
  }

  // Versioned keys. A build that changes what `Meal.toRow` writes bumps the
  // suffix and reads a clean miss, rather than half-decoding the old shape.
  static const TimestampedStore _feed = TimestampedStore(
    'cache.meals.feed.v1',
    ttl: Duration(hours: 24),
  );

  // Shorter than the catalogue's day: these are the reader's own lists, and a
  // stale heart is a small lie about something they did themselves. Long enough
  // to cover a commute with no signal.
  static const TimestampedStore _favorites = TimestampedStore(
    'cache.meals.favorites.v1',
    ttl: Duration(hours: 6),
  );

  static const TimestampedStore _dislikes = TimestampedStore(
    'cache.meals.dislikes.v1',
    ttl: Duration(hours: 6),
  );
}

/// A page that came off the disk, and when it was put there.
class CachedMeals {
  const CachedMeals({required this.meals, required this.storedAt});

  final List<Meal> meals;
  final DateTime storedAt;
}
