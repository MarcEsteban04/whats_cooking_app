import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';

/// One night the household ate out (docs/DATABASE.md §4.16).
class RestaurantVisit {
  const RestaurantVisit({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.cuisine,
    required this.eatenAt,
    this.estimatedCost,
    this.actualCost,
  });

  factory RestaurantVisit.fromRow(Map<String, dynamic> row) {
    final Map<String, dynamic>? place =
        row['restaurants'] as Map<String, dynamic>?;

    return RestaurantVisit(
      id: row['id'] as String,
      restaurantId: row['restaurant_id'] as String,
      restaurantName: place?['name'] as String? ?? '',
      cuisine:
          Cuisine.fromValue(place?['cuisine'] as String? ?? '') ??
          Cuisine.other,
      eatenAt:
          DateTime.tryParse(row['eaten_at'] as String? ?? '') ?? DateTime.now(),
      estimatedCost: (row['estimated_cost'] as num?)?.toDouble(),
      actualCost: (row['actual_cost'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String restaurantId;
  final String restaurantName;
  final Cuisine cuisine;
  final DateTime eatenAt;

  /// What the place said it costs, copied at decision time.
  final double? estimatedCost;

  /// What it really came to, if anybody said.
  final double? actualCost;
}

/// Where we have eaten out (Sprint 46).
abstract interface class RestaurantHistoryRepository {
  /// Recent nights out, newest first.
  Future<List<RestaurantVisit>> recent({int limit});

  /// Records that we went.
  Future<RestaurantVisit> record(Restaurant place);
}

/// [RestaurantHistoryRepository] backed by PostgREST.
class SupabaseRestaurantHistoryRepository
    implements RestaurantHistoryRepository {
  SupabaseRestaurantHistoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RestaurantVisit>> recent({int limit = 40}) {
    return RemoteCall.guard(
      () async {
        final PostgrestList rows = await _client
            .from(_table)
            .select(_columns)
            .order('eaten_at', ascending: false)
            .limit(limit);

        return <RestaurantVisit>[
          for (final Map<String, dynamic> row in rows)
            RestaurantVisit.fromRow(row),
        ];
      },
      label: 'restaurantHistory.recent',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<RestaurantVisit> record(Restaurant place) {
    return RemoteCall.guard(
      () async {
        final String userId = _requireUserId();
        final String householdId = await _requireHouseholdId(userId);

        return RestaurantVisit.fromRow(
          await _client
              .from(_table)
              .insert(<String, Object?>{
                'household_id': householdId,
                'restaurant_id': place.id,
                // From the session. The insert policy checks
                // `decided_by = auth.uid()`, so anything else is a rejected row
                // rather than a wrong one — but sending the right thing beats
                // being caught sending the wrong one.
                'decided_by': userId,
                // Copied now, because the place's own price will drift and a
                // history that silently re-prices last month is a history nobody
                // can budget from.
                'estimated_cost': place.costPerHead,
              })
              .select(_columns)
              .single(),
        );
      },
      label: 'restaurantHistory.record',
      // No retry, exactly as `meal_history` does not. A retried insert is a second
      // night out; the table has no uniqueness to lean on — deliberately, because
      // a household really can eat at the same place twice in a day — so a
      // duplicate is indistinguishable from the truth and would skew every count
      // built on it.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailureException(
        message: 'Sign in again to record that.',
      );
    }
    return userId;
  }

  Future<String> _requireHouseholdId(String userId) async {
    final Map<String, dynamic>? profile = await _client
        .from('profiles')
        .select('active_household_id')
        .eq('id', userId)
        .maybeSingle();

    if (profile?['active_household_id'] case final String householdId) {
      return householdId;
    }

    throw const ValidationException(
      message: 'Your kitchen is still being set up. Try again in a moment.',
      detail: 'profiles.active_household_id was null',
    );
  }

  static const String _columns =
      'id, restaurant_id, eaten_at, estimated_cost, actual_cost, '
      'restaurants(name, cuisine)';

  static const String _table = 'restaurant_history';
}

/// [RestaurantHistoryRepository] with no backend behind it.
class InMemoryRestaurantHistoryRepository
    implements RestaurantHistoryRepository {
  final List<RestaurantVisit> _visits = <RestaurantVisit>[];

  int _nextId = 0;

  @override
  Future<List<RestaurantVisit>> recent({int limit = 40}) async {
    final List<RestaurantVisit> sorted = List<RestaurantVisit>.of(_visits)
      ..sort(
        (RestaurantVisit a, RestaurantVisit b) =>
            b.eatenAt.compareTo(a.eatenAt),
      );
    return sorted.take(limit).toList();
  }

  @override
  Future<RestaurantVisit> record(Restaurant place) async {
    final RestaurantVisit visit = RestaurantVisit(
      id: 'visit-${_nextId++}',
      restaurantId: place.id,
      restaurantName: place.name,
      cuisine: place.cuisine,
      eatenAt: DateTime.now(),
      estimatedCost: place.costPerHead,
    );
    _visits.add(visit);
    return visit;
  }
}
