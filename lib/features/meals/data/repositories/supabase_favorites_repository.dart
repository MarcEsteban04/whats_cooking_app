import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/meals/domain/repositories/favorites_repository.dart';

/// [FavoritesRepository] backed by PostgREST.
class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Set<String>> mealIds() {
    return RemoteCall.guard(
      () async {
        // Filtered to this user explicitly, even though the policy would return
        // the household's. See `FavoritesRepository` — a partner's favourite
        // arriving as yours would fill the heart on a meal you never saved.
        final PostgrestList rows = await _client
            .from(_table)
            .select('meal_id')
            .eq('user_id', _requireUserId());

        return <String>{
          for (final Map<String, dynamic> row in rows)
            if (row['meal_id'] case final String id) id,
        };
      },
      label: 'favorites.mealIds',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> add(String mealId) {
    return RemoteCall.guard(
      () async {
        // `upsert` on the unique key rather than an insert, so a double tap — or
        // a retry from another device — is a no-op instead of a constraint
        // violation the user would see as an error.
        await _client.from(_table).upsert(<String, Object?>{
          'user_id': _requireUserId(),
          'meal_id': mealId,
        }, onConflict: 'user_id, meal_id');
      },
      label: 'favorites.add',
      // The screen has already flipped the heart optimistically. A retry storm
      // behind an optimistic update means the rollback can arrive long after the
      // user moved on, which reads as the app undoing their tap at random.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> remove(String mealId) {
    return RemoteCall.guard(
      () async {
        await _client
            .from(_table)
            .delete()
            .eq('user_id', _requireUserId())
            .eq('meal_id', mealId);
      },
      label: 'favorites.remove',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  String _requireUserId() {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      // Reached only if a screen behind the auth guard called this without a
      // session, which is a programming error rather than a runtime condition.
      throw const AuthFailureException(
        message: 'Please sign in again',
        detail: 'favorites called with no session',
        isSessionExpired: true,
      );
    }
    return id;
  }

  static const String _table = 'favorite_meals';
}
