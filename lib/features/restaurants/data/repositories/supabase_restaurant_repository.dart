import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/repositories/restaurant_repository.dart';

/// [RestaurantRepository] backed by PostgREST.
class SupabaseRestaurantRepository implements RestaurantRepository {
  SupabaseRestaurantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Restaurant>> all() {
    return RemoteCall.guard(
      () async {
        // No visibility filter and no household filter. The
        // `household members manage restaurants` policy returns exactly this
        // household's rows and nothing else, so filtering here would either
        // duplicate it or — worse — disagree with it.
        final PostgrestList rows = await _client
            .from(_table)
            .select(_columns)
            // Favourites first, matching the index. A list where the places we
            // actually like are at the top is a list that answers the question
            // most nights without scrolling.
            .order('is_favorite', ascending: false)
            .order('name');

        return <Restaurant>[
          for (final Map<String, dynamic> row in rows) Restaurant.fromRow(row),
        ];
      },
      label: 'restaurants.all',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Restaurant> create(RestaurantDraft draft) {
    return RemoteCall.guard(
      () async {
        final String userId = _requireUserId();
        final String householdId = await _requireHouseholdId(userId);

        return Restaurant.fromRow(
          await _client
              .from(_table)
              .insert(<String, Object?>{
                ...draft.toRow(),
                'household_id': householdId,
                'created_by': userId,
              })
              .select(_columns)
              .single(),
        );
      },
      label: 'restaurants.create',
      // No retry. `restaurants_name_unique` would refuse a duplicate, so a
      // retried insert cannot make two rows — but it would surface the conflict
      // as the error instead of the original problem, which is a worse message
      // than the one the reader should have seen.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Restaurant> update(String id, RestaurantDraft draft) {
    return RemoteCall.guard(
      () async {
        return Restaurant.fromRow(
          await _client
              .from(_table)
              .update(draft.toRow())
              .eq('id', id)
              .select(_columns)
              .single(),
        );
      },
      label: 'restaurants.update',
      // Idempotent: the same row written twice is the same row.
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> remove(String id) {
    return RemoteCall.guard(
      () async {
        await _client.from(_table).delete().eq('id', id);
      },
      label: 'restaurants.remove',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Restaurant> setFavorite(String id, {required bool isFavorite}) {
    return RemoteCall.guard(
      () async {
        return Restaurant.fromRow(
          await _client
              .from(_table)
              .update(<String, Object?>{'is_favorite': isFavorite})
              .eq('id', id)
              .select(_columns)
              .single(),
        );
      },
      label: 'restaurants.setFavorite',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailureException(
        message: 'Sign in again to see your places.',
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

  /// Every column the app reads. No join — this table stands alone.
  static const String _columns =
      'id, name, cuisine, cost_per_head, proximity, delivers, notes, '
      'go_to_order, tags, is_favorite, created_by';

  static const String _table = 'restaurants';
}
