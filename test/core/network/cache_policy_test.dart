import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/network/cache_policy.dart';

/// The cache table from docs/ARCHITECTURE.md §4, as assertions.
void main() {
  final DateTime now = DateTime(2026, 8, 20, 12);

  group('freshness', () {
    test('a value inside its TTL is fresh', () {
      expect(
        CachePolicy.meals.isFresh(
          writtenAt: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a value past its TTL is stale', () {
      expect(
        CachePolicy.meals.isFresh(
          writtenAt: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isFalse,
      );
    });

    test('history goes stale within the hour', () {
      // It feeds the repetition penalty, so a stale copy makes the roulette
      // recommend something the household just ate.
      expect(CachePolicy.history.ttl, const Duration(hours: 1));
      expect(
        CachePolicy.history.isFresh(
          writtenAt: now.subtract(const Duration(minutes: 61)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a session-scoped policy never expires by time', () {
      // Freshness for these is decided by the cache being cleared on launch, or
      // invalidated on change — not by elapsed time. Writing a TTL for data the
      // app is told about when it changes would mean re-fetching something
      // already known to be current.
      for (final CachePolicy policy in <CachePolicy>[
        CachePolicy.preferences,
        CachePolicy.pantry,
        CachePolicy.grocery,
        CachePolicy.household,
      ]) {
        expect(policy.ttl, isNull, reason: policy.name);
        expect(
          policy.isFresh(
            writtenAt: now.subtract(const Duration(days: 30)),
            now: now,
          ),
          isTrue,
          reason: policy.name,
        );
      }
    });
  });

  group('the documented table', () {
    test('the meal catalogue caches for a day', () {
      // The entry that is a product requirement rather than an optimisation:
      // docs/USER_FLOWS.md §18 requires the roulette work against cache alone,
      // so a user with no signal still gets a decision.
      expect(CachePolicy.meals.ttl, const Duration(hours: 24));
      expect(CachePolicy.mealDetail.ttl, const Duration(hours: 24));
    });

    test('only the household-shared collections are network first', () {
      // A partner's change matters more than instant paint for these two, and
      // less than it for everything else.
      expect(CachePolicy.pantry.isNetworkFirst, isTrue);
      expect(CachePolicy.grocery.isNetworkFirst, isTrue);

      expect(CachePolicy.meals.isNetworkFirst, isFalse);
      expect(CachePolicy.mealDetail.isNetworkFirst, isFalse);
      expect(CachePolicy.history.isNetworkFirst, isFalse);
      expect(CachePolicy.preferences.isNetworkFirst, isFalse);
      expect(CachePolicy.household.isNetworkFirst, isFalse);
    });

    test('every policy has a distinct key prefix', () {
      // Two policies sharing a prefix would let one invalidate the other's
      // entries.
      final Set<String> prefixes = CachePolicy.values
          .map((CachePolicy policy) => policy.keyPrefix)
          .toSet();

      expect(prefixes, hasLength(CachePolicy.values.length));
    });
  });
}
