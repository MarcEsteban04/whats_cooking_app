import 'dart:typed_data';

import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/domain/repositories/profile_repository.dart';

/// [ProfileRepository] with no backend.
///
/// Lets a build without Supabase credentials open the profile screen and edit
/// preferences for the session, so the whole app stays walkable on a fresh clone.
class InMemoryProfileRepository implements ProfileRepository {
  UserProfile _profile = const UserProfile(
    displayName: 'Marc',
    hasHousehold: true,
    householdName: "Marc's Kitchen",
  );

  /// Set when [deleteAccount] runs. Visible for tests.
  bool isDeleted = false;

  @override
  Future<UserProfile> load() async {
    await _latency();
    return _profile;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _latency();
    _profile = _profile.copyWith(displayName: displayName.trim());
  }

  @override
  Future<void> updatePreferences(FoodPreferences preferences) async {
    await _latency();
    _profile = _profile.copyWith(preferences: preferences);
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    await _latency();

    // A data URL rather than a fake remote one, so the picked image actually
    // renders and the flow can be judged without a backend.
    const String url = 'memory://avatar';
    _profile = _profile.copyWith(avatarUrl: url);
    return url;
  }

  @override
  Future<void> deleteAccount() async {
    await _latency();
    isDeleted = true;
  }

  static const Duration latency = Duration(milliseconds: 120);

  static Future<void> _latency() => Future<void>.delayed(latency);
}
