import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/meals/data/datasources/meal_cache.dart';
import 'package:whats_cooking/features/meals/domain/repositories/dislikes_repository.dart';

/// [DislikesRepository] backed by PostgREST.
class SupabaseDislikesRepository implements DislikesRepository {
  SupabaseDislikesRepository(this._client, {this.cache = const MealCache()});

  final SupabaseClient _client;

  /// Where the set is kept for a cold start with no signal (Sprint 27).
  final MealCache cache;

  /// The hidden set, from the network, falling back to the disk.
  ///
  /// This one is on the critical path and that is why it is cached at all. The
  /// feed reads it before its first page — deliberately, because a catalogue
  /// that might contain a hidden meal breaks the promise the feature exists for
  /// (US-B-07) — so without a fallback here, a cold start with no signal fails
  /// the whole Meals tab before the cached catalogue is ever consulted.
  @override
  Future<Set<String>> mealIds() async {
    try {
      final Set<String> ids = await _mealIds();
      unawaited(cache.writeDislikes(ids, now: DateTime.now()));
      return ids;
    } on AppException catch (failure) {
      if (failure is! NetworkException && failure is! ServerException) {
        rethrow;
      }

      // No cached set means no exclusion can be honoured, and the right answer
      // is to fail rather than to show a catalogue that might contain something
      // the reader hid.
      final Set<String>? cached = await cache.readDislikes(now: DateTime.now());
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  Future<Set<String>> _mealIds() {
    return RemoteCall.guard(
      () async {
        // The `own dislikes only` policy already restricts this to `auth.uid()`,
        // so the filter is redundant — and stated anyway. It costs nothing, it
        // uses `disliked_meals_user_idx`, and it means a future policy widened
        // for the scoring engine cannot quietly widen what the app reads.
        final PostgrestList rows = await _client
            .from(_table)
            .select('meal_id')
            .eq('user_id', _requireUserId());

        return <String>{
          for (final Map<String, dynamic> row in rows)
            if (row['meal_id'] case final String id) id,
        };
      },
      label: 'dislikes.mealIds',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> add(String mealId) {
    return RemoteCall.guard(
      () async {
        // Upsert on the unique key, so hiding something already hidden — a
        // double tap, or the same meal hidden on a second device — is a no-op
        // rather than a constraint violation the user reads as a failure.
        await _client.from(_table).upsert(<String, Object?>{
          'user_id': _requireUserId(),
          'meal_id': mealId,
        }, onConflict: 'user_id, meal_id');
      },
      label: 'dislikes.add',
      // The screen has already hidden the row. Retrying behind an optimistic
      // update means the rollback can arrive long after the user moved on,
      // which reads as a meal reappearing by itself.
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
      label: 'dislikes.remove',
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
        detail: 'dislikes called with no session',
        isSessionExpired: true,
      );
    }
    return id;
  }

  static const String _table = 'disliked_meals';
}
