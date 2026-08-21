/// Asking the app in words (Sprint 47).
///
/// The provider key lives on the `ai-assistant` Edge Function and nowhere else —
/// `AppEnv.assertNoProviderKey` fails the first frame if one is compiled in.
/// Sprints 48 to 50 add recipe generation, the fridge scanner and richer context
/// on top of the same function.
library;

export 'data/repositories/supabase_assistant_repository.dart';
export 'domain/entities/assistant_message.dart';
export 'presentation/providers/assistant_controller.dart';
export 'presentation/screens/assistant_screen.dart';
