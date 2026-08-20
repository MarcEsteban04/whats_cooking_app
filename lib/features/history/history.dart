/// Public surface of the `history` feature — what the household has eaten, and
/// the celebration that puts it there.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
library;

export 'domain/entities/meal_history_entry.dart';
export 'domain/repositories/meal_history_repository.dart';
export 'presentation/providers/meal_history_controller.dart';
export 'presentation/screens/decided_screen.dart';
export 'presentation/screens/meal_history_screen.dart';
