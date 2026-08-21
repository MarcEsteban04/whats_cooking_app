/// Where we eat out (Sprints 45–46).
///
/// The second library, ours to write, with no discovery layer — no maps, no
/// ratings, no location search. Sprint 46 spins over it, sharing the reel and the
/// weighting arithmetic with the meal roulette and keeping its own weight table.
library;

export 'data/repositories/in_memory_restaurant_repository.dart';
export 'data/repositories/supabase_restaurant_history_repository.dart';
export 'data/repositories/supabase_restaurant_repository.dart';
export 'domain/entities/restaurant.dart';
export 'domain/entities/restaurant_filters.dart';
export 'domain/repositories/restaurant_repository.dart';
export 'domain/usecases/restaurant_scorer.dart';
export 'presentation/providers/restaurant_spin_controller.dart';
export 'presentation/providers/restaurants_controller.dart';
export 'presentation/screens/restaurant_form_screen.dart';
export 'presentation/screens/restaurant_result_screen.dart';
export 'presentation/screens/restaurant_spin_screen.dart';
export 'presentation/screens/restaurants_screen.dart';
