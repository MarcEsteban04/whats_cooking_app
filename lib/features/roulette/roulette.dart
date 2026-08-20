/// Public surface of the `roulette` feature — the spin interaction and, from
/// Sprint 30, the recommendation engine behind it.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
library;

export 'presentation/providers/spin_controller.dart';
export 'presentation/screens/spin_result_screen.dart';
export 'presentation/screens/spin_screen.dart';
export 'presentation/widgets/meal_reel.dart';
