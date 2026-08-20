/// Public surface of the `profile` feature — profile, preferences, budget and
/// account settings.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
library;

export 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
export 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
export 'package:whats_cooking/features/profile/presentation/providers/theme_mode_controller.dart';
export 'package:whats_cooking/features/profile/presentation/screens/account_settings_screen.dart';
export 'package:whats_cooking/features/profile/presentation/screens/appearance_settings_screen.dart';
export 'package:whats_cooking/features/profile/presentation/screens/budget_settings_screen.dart';
export 'package:whats_cooking/features/profile/presentation/screens/preferences_screen.dart';
export 'package:whats_cooking/features/profile/presentation/screens/profile_screen.dart';
