import 'dart:typed_data';

import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';

/// Reads and writes the profile.
abstract interface class ProfileRepository {
  Future<UserProfile> load();

  Future<void> updateDisplayName(String displayName);

  /// Saves all six preference fields.
  ///
  /// docs/USER_FLOWS.md §17: "Preference changes take effect on the **next
  /// spin**, with no app restart." Nothing is re-scored here — the engine reads
  /// preferences when it runs, so writing them is the whole job.
  Future<void> updatePreferences(FoodPreferences preferences);

  /// Uploads an avatar and returns its public URL.
  ///
  /// [bytes] must already be resized and within the bucket's 2 MB limit; the
  /// bucket rejects anything larger and anything that is not JPEG, PNG or WebP
  /// (supabase/migrations/…_avatars_storage.sql).
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Deletes the account and everything owned by it.
  ///
  /// docs/USER_FLOWS.md §17 requires double confirmation before this is called,
  /// and that the app states plainly what is destroyed and what the household
  /// retains. This method assumes both have already happened.
  Future<void> deleteAccount();
}
