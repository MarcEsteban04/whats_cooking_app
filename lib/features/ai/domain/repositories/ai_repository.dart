import 'package:whats_cooking/features/ai/domain/entities/ai_message.dart';

/// Talks to the assistant (Sprint 59).
///
/// **There is deliberately no provider in this contract.** No key, no model, no
/// endpoint, no failover — the client cannot express which AI answers because it
/// must not be able to hold a credential for any of them
/// (docs/ARCHITECTURE.md §8.1 rule 4, docs/project_dev.md Sprint 59: "Never
/// expose AI API keys inside Flutter"). What this asks for is an answer; where it
/// comes from is the `ai-assistant` Edge Function's business.
///
/// The chain of three providers, the per-provider timeout, the rate limit and the
/// usage row all live there for the same reason. A retry policy on this side
/// would be a fourth attempt on top of three the server already made.
abstract interface class AiRepository {
  /// Sends a conversation and returns the reply.
  ///
  /// [context] is a small map of facts about the household — budget, party size,
  /// dietary needs — that the function folds into its system prompt. Facts, not
  /// instructions: the prompt says so explicitly, because a value here came from
  /// something a user typed.
  ///
  /// Keep it small. Every entry is sent on every turn and paid for on every turn.
  Future<AiReply> ask({
    required List<AiMessage> messages,
    AiPurpose purpose,
    Map<String, Object?> context,
  });
}
