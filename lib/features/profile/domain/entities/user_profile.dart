import 'package:whats_cooking/core/domain/food_preferences.dart';

/// A user's profile, as the profile screen needs it.
///
/// The two halves come from two tables — `profiles` for the identity and
/// `user_preferences` for how they eat — and are carried together because every
/// screen that wants one wants the other.
class UserProfile {
  const UserProfile({
    required this.displayName,
    this.avatarUrl,
    this.preferences = const FoodPreferences(),
    this.hasHousehold = false,
    this.householdName,
  });

  final String displayName;

  /// Null falls back to initials (docs/COMPONENTS.md §16).
  final String? avatarUrl;

  final FoodPreferences preferences;

  /// Whether an active household exists.
  final bool hasHousehold;

  /// The household's name, for the profile's household row.
  final String? householdName;

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    FoodPreferences? preferences,
    bool? hasHousehold,
    String? householdName,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? this.preferences,
      hasHousehold: hasHousehold ?? this.hasHousehold,
      householdName: householdName ?? this.householdName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfile &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.preferences == preferences &&
        other.hasHousehold == hasHousehold &&
        other.householdName == householdName;
  }

  @override
  int get hashCode => Object.hash(
    displayName,
    avatarUrl,
    preferences,
    hasHousehold,
    householdName,
  );
}
