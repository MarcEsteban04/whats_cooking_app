/// Public surface of the `roulette` feature — the spin interaction, its filters,
/// and from Sprint 34 the scoring behind it.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
library;

export 'domain/entities/spin_filters.dart';
export 'domain/usecases/meal_scorer.dart';
export 'presentation/providers/spin_controller.dart';
export 'presentation/providers/spin_filters_controller.dart';
export 'presentation/screens/spin_filters_sheet.dart';
export 'presentation/screens/spin_result_screen.dart';
export 'presentation/screens/spin_screen.dart';
export 'presentation/widgets/meal_reel.dart';
