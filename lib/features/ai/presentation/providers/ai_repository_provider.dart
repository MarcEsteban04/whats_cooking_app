import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/ai/data/repositories/in_memory_ai_repository.dart';
import 'package:whats_cooking/features/ai/data/repositories/supabase_ai_repository.dart';
import 'package:whats_cooking/features/ai/domain/repositories/ai_repository.dart';

part 'ai_repository_provider.g.dart';

/// The assistant's backend.
///
/// Same shape as every other repository provider here: the real one when there
/// are credentials, an honest refusal when there are not. Note what *is not*
/// checked — whether an AI key exists. The client cannot know that and must not:
/// the keys live in the Edge Function's environment, and whether they are set is
/// something only the function can answer (it returns `misconfigured`).
@Riverpod(keepAlive: true)
AiRepository aiRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: the assistant will refuse rather than answer.',
      name: 'aiRepository',
    );
    return InMemoryAiRepository();
  }

  return SupabaseAiRepository(ref.read(supabaseClientProvider));
}
