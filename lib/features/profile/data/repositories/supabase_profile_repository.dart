import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/onboarding/data/repositories/supabase_onboarding_repository.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/domain/repositories/profile_repository.dart';

/// [ProfileRepository] backed by Supabase.
///
/// The preference column mapping is reused from
/// [SupabaseOnboardingRepository.columnsFor] rather than restated. Both write the
/// same six fields from the same model, and two copies of that mapping is two
/// chances to disagree about which column a dietary tag belongs in.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _userId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthFailureException(
        message: 'Please sign in again',
        detail: 'profile accessed with no authenticated user',
      );
    }
    return id;
  }

  @override
  Future<UserProfile> load() {
    return RemoteCall.guard(
      () async {
        final String id = _userId;

        // The household name comes through the foreign key rather than as a
        // second round trip. RLS still applies to the embedded row, so this
        // cannot read a household the user is not in.
        final Map<String, dynamic>? profile = await _client
            .from(_profilesTable)
            .select(
              'display_name, avatar_url, active_household_id, '
              'households:active_household_id (name)',
            )
            .eq('id', id)
            .maybeSingle();

        final Map<String, dynamic>? preferences = await _client
            .from(_preferencesTable)
            .select(
              'favorite_cuisines, dietary_tags, default_budget, '
              'max_cooking_time, preferred_servings, '
              'disliked_ingredient_names',
            )
            .eq('user_id', id)
            .maybeSingle();

        if (profile == null) {
          // The signup trigger creates this row, so its absence means
          // provisioning failed rather than that the user is new.
          throw const NotFoundException(
            message: "We couldn't load your profile",
            detail: 'no profiles row for the authenticated user',
          );
        }

        final Object? household = profile['households'];

        return UserProfile(
          displayName: profile['display_name'] as String? ?? '',
          avatarUrl: profile['avatar_url'] as String?,
          preferences: SupabaseOnboardingRepository.preferencesFrom(
            preferences,
          ),
          hasHousehold: profile['active_household_id'] != null,
          householdName: household is Map<String, dynamic>
              ? household['name'] as String?
              : null,
        );
      },
      label: 'loadProfile',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> updateDisplayName(String displayName) {
    final String name = displayName.trim();
    if (name.isEmpty) {
      // `profiles.display_name` is not null, and an empty name would leave the
      // user without one everywhere it is shown.
      throw const ValidationException(
        message: 'Enter your name',
        field: 'displayName',
      );
    }

    return RemoteCall.guard(
      () => _client
          .from(_profilesTable)
          .update(<String, dynamic>{'display_name': name})
          .eq('id', _userId),
      label: 'updateDisplayName',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> updatePreferences(FoodPreferences preferences) {
    return RemoteCall.guard(
      () => _client
          .from(_preferencesTable)
          .update(SupabaseOnboardingRepository.columnsFor(preferences))
          .eq('user_id', _userId),
      label: 'updatePreferences',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return RemoteCall.guard(
      () async {
        final String id = _userId;

        // The path the storage policies enforce: '<user_id>/avatar.<ext>'. The
        // policy checks the first segment against auth.uid(), which is what stops
        // one user overwriting another's face
        // (supabase/migrations/…_avatars_storage.sql).
        final String path = '$id/avatar.$fileExtension';

        await _client.storage
            .from(_avatarsBucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: supabase.FileOptions(
                contentType: _contentTypeFor(fileExtension),
                // Overwrites rather than accumulating one file per change. A
                // fixed path means the bucket holds one avatar per user instead
                // of every avatar they have ever had.
                upsert: true,
              ),
            );

        final String url = _client.storage
            .from(_avatarsBucket)
            .getPublicUrl(path);

        // A cache-buster, because the path never changes. Without it, every
        // cached copy — the CDN's and cached_network_image's — keeps serving the
        // old face after a successful upload.
        final String versioned =
            '$url?v=${DateTime.now().millisecondsSinceEpoch}';

        await _client
            .from(_profilesTable)
            .update(<String, dynamic>{'avatar_url': versioned})
            .eq('id', id);

        return versioned;
      },
      label: 'uploadAvatar',
      // Not retried: an upload that timed out may have landed, and a retry would
      // re-send two megabytes to find out.
      policy: RetryPolicy.none,
      timeout: _uploadTimeout,
    );
  }

  @override
  Future<void> deleteAccount() {
    return RemoteCall.guard(
      () async {
        // A SECURITY DEFINER function, because deleting an account means
        // deleting rows across tables and from auth.users, which no client key
        // can do (supabase/migrations/…_delete_own_account.sql). It reads the
        // caller's id from the verified token rather than taking one.
        await _client.rpc<void>(_deleteAccountFunction);

        // Local session cleared afterwards so the app does not keep a token for
        // a user that no longer exists.
        await _client.auth.signOut();
      },
      label: 'deleteAccount',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  static String _contentTypeFor(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  /// Longer than a normal request: this is up to two megabytes on a phone
  /// connection, and failing a good upload at ten seconds would be worse than
  /// waiting.
  static const Duration _uploadTimeout = Duration(seconds: 45);

  static const String _profilesTable = 'profiles';
  static const String _preferencesTable = 'user_preferences';
  static const String _avatarsBucket = 'avatars';
  static const String _deleteAccountFunction = 'delete_own_account';
}
