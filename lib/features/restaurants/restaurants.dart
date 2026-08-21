/// Where we eat out (Sprint 45).
///
/// The second library, ours to write, with no discovery layer — no maps, no
/// ratings, no location search. Sprint 46 spins over it.
library;

export 'data/repositories/in_memory_restaurant_repository.dart';
export 'data/repositories/supabase_restaurant_repository.dart';
export 'domain/entities/restaurant.dart';
export 'domain/repositories/restaurant_repository.dart';
export 'presentation/providers/restaurants_controller.dart';
export 'presentation/screens/restaurant_form_screen.dart';
export 'presentation/screens/restaurants_screen.dart';
