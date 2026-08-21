/// What is in the kitchen (Sprint 39).
///
/// The pantry is the app's answer to "what can we cook *now*" rather than "what
/// could we cook" — and from Sprint 41 it is what lets the roulette weight meals
/// by whether the ingredients are already in.
library;

export 'data/repositories/in_memory_pantry_repository.dart';
export 'data/repositories/supabase_pantry_repository.dart';
export 'domain/entities/pantry_item.dart';
export 'domain/repositories/pantry_repository.dart';
export 'presentation/providers/pantry_controller.dart';
export 'presentation/screens/pantry_item_sheet.dart';
export 'presentation/screens/pantry_screen.dart';
