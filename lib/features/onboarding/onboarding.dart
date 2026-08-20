/// Public surface of the `onboarding` feature — first-run preference capture.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
library;

export 'package:whats_cooking/core/domain/food_preferences.dart';
export 'package:whats_cooking/core/domain/food_taxonomy.dart';
export 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
export 'package:whats_cooking/features/onboarding/domain/entities/onboarding_step.dart';
export 'package:whats_cooking/features/onboarding/presentation/providers/onboarding_controller.dart';
export 'package:whats_cooking/features/onboarding/presentation/screens/onboarding_screen.dart';
