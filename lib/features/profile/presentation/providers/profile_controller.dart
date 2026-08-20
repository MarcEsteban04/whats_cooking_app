import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/features/profile/data/repositories/in_memory_profile_repository.dart';
import 'package:whats_cooking/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/domain/repositories/profile_repository.dart';

part 'profile_controller.g.dart';

/// Where the profile is read and written.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    return InMemoryProfileRepository();
  }
  return SupabaseProfileRepository(ref.read(supabaseClientProvider));
}

/// The profile, as `AsyncValue` (docs/ARCHITECTURE.md §3.2).
///
/// Loading, error and data are the framework's three states rather than three
/// booleans of this notifier's own, so a screen renders it with `.when(...)` and
/// cannot forget one.
@Riverpod(keepAlive: true)
class ProfileController extends _$ProfileController {
  @override
  Future<UserProfile> build() => ref.read(profileRepositoryProvider).load();

  /// Re-reads the profile.
  Future<void> refresh() async {
    state = const AsyncValue<UserProfile>.loading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).load(),
    );
  }

  /// Renames the user.
  ///
  /// Optimistic: the new name is shown before the write returns, and rolled back
  /// if it fails. A name is the user's own text — showing it immediately is
  /// truthful, and a spinner over a text field they just typed in is not.
  Future<AppException?> updateDisplayName(String displayName) async {
    final UserProfile? current = state.value;
    if (current == null) {
      return null;
    }

    state = AsyncValue<UserProfile>.data(
      current.copyWith(displayName: displayName.trim()),
    );

    try {
      await ref.read(profileRepositoryProvider).updateDisplayName(displayName);
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<UserProfile>.data(current);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Saves the preferences.
  ///
  /// docs/USER_FLOWS.md §17: changes "take effect on the next spin, with no app
  /// restart". Nothing is re-scored here — the recommendation engine reads
  /// preferences when it runs, so writing them is the entire job.
  Future<AppException?> updatePreferences(FoodPreferences preferences) async {
    final UserProfile? current = state.value;
    if (current == null) {
      return null;
    }

    state = AsyncValue<UserProfile>.data(
      current.copyWith(preferences: preferences),
    );

    try {
      await ref.read(profileRepositoryProvider).updatePreferences(preferences);
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<UserProfile>.data(current);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Uploads a new avatar.
  ///
  /// Not optimistic, unlike the two above: the bytes may be rejected by the
  /// bucket for size or type, and showing the new face before the server accepts
  /// it would mean taking it away again.
  Future<AppException?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final UserProfile? current = state.value;
    if (current == null) {
      return null;
    }

    try {
      final String url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(bytes: bytes, fileExtension: fileExtension);

      state = AsyncValue<UserProfile>.data(current.copyWith(avatarUrl: url));
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Deletes the account.
  ///
  /// The caller is responsible for the double confirmation
  /// (docs/USER_FLOWS.md §17). Returns the failure, if any, so the screen can
  /// say so — this is the one action where silently failing would leave someone
  /// believing their data is gone when it is not.
  Future<AppException?> deleteAccount() async {
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.map(error, stackTrace);
    }
  }
}
