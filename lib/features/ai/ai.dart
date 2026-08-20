/// Public surface of the `ai` feature — the assistant, and the proxy in front of
/// it.
///
/// Cross-feature code imports this barrel and never a file inside the feature
/// (docs/CODING_STANDARDS.md §3).
///
/// **No provider key appears anywhere behind this barrel.** The three keys live
/// in the `ai-assistant` Edge Function's environment; this feature knows only
/// that a function exists. See docs/ARCHITECTURE.md §6.4.
library;

export 'domain/entities/ai_message.dart';
export 'domain/repositories/ai_repository.dart';
export 'presentation/providers/ai_repository_provider.dart';
