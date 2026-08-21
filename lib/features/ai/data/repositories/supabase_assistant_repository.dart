import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';

/// Asking the assistant something (Sprint 47).
///
/// **One method, and it is not streaming.** The roadmap asked for "streaming where
/// the provider supports it", and building it would break the thing that makes the
/// AI work at all: `ai-assistant` tries three providers in turn, and a chain like
/// that is fundamentally at odds with streaming. Once the first provider has sent
/// tokens to the screen, failing over means either abandoning a half-written answer
/// in front of the reader or silently splicing two different models' prose
/// together. A four-second wait for a whole answer is a better experience than a
/// fast answer that sometimes falls apart mid-sentence.
abstract interface class AssistantRepository {
  /// Sends the conversation and returns the reply.
  ///
  /// [context] is *data* about this household — the pantry, the budget, what was
  /// eaten lately. The Edge Function renders it as a labelled block and tells the
  /// model to treat it as facts rather than instructions, which is why nothing here
  /// tries to phrase it as a sentence.
  Future<AssistantReply> ask({
    required List<AssistantMessage> messages,
    Map<String, Object?> context,
  });
}

/// [AssistantRepository] backed by the `ai-assistant` Edge Function.
///
/// **No provider key ever reaches this class.** That is the whole reason the
/// function exists (docs/ARCHITECTURE.md §6.4), and `AppEnv.assertNoProviderKey`
/// fails the first frame if one is compiled in.
class SupabaseAssistantRepository implements AssistantRepository {
  SupabaseAssistantRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AssistantReply> ask({
    required List<AssistantMessage> messages,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    // Not wrapped in `RemoteCall.guard`, deliberately. That helper retries, and a
    // retry here is a second bill and a second hour's rate-limit budget — the
    // function has already tried three providers before it gives up, so anything
    // that reaches this catch has been attempted three times.
    try {
      final supabase.FunctionResponse response = await _client.functions.invoke(
        _function,
        body: <String, Object?>{
          'purpose': 'assistant',
          'messages': <Map<String, Object?>>[
            for (final AssistantMessage message in messages) message.toWire(),
          ],
          'context': context,
        },
      );

      if (response.data case final Map<String, dynamic> data) {
        final AssistantReply reply = AssistantReply.fromJson(data);
        if (reply.text.isEmpty) {
          // A 200 with nothing in it. Rare, and worth its own message rather than
          // an empty bubble the reader has to interpret.
          throw const ServerException(
            message: 'The assistant had nothing to say. Try asking again.',
          );
        }
        return reply;
      }

      throw const ServerException(
        message: 'The assistant sent something we could not read.',
      );
    } on supabase.FunctionException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  /// Turns the function's named error codes into something a person reads.
  ///
  /// **The function already writes the sentence** — `rate_limited` comes back with
  /// "You have used the assistant a lot in the last hour. Try again in about 40
  /// minutes." — so the job here is to *use* it rather than to invent a second
  /// wording. The code decides which exception type it becomes; the message is
  /// theirs.
  ///
  /// docs/design_ui.md §31: never show technical exception text. The fallbacks
  /// below are what a reader sees when the function did not send a sentence, and
  /// the raw detail goes to the log instead.
  AppException _mapFunctionError(supabase.FunctionException error) {
    final Map<String, dynamic> details = switch (error.details) {
      final Map<String, dynamic> map => map,
      _ => const <String, dynamic>{},
    };

    final String? code = details['code'] as String?;
    final String? message = details['message'] as String?;

    AppLog.warning(
      'Assistant refused.',
      name: _logName,
      data: <String, Object?>{'code': code, 'status': error.status},
    );

    return switch (code) {
      'unauthenticated' => AuthFailureException(
        message: message ?? 'Sign in again to ask.',
      ),
      'rate_limited' => RateLimitException(
        message:
            message ??
            'You have asked a lot in the last hour. Try again shortly.',
      ),
      // The keys are not configured on the function. A developer problem, and the
      // reader should not be told to check their connection about it.
      'misconfigured' => const ServerException(
        message: 'The assistant is not set up yet.',
        detail: 'ai-assistant is missing its provider keys',
      ),
      'unavailable' => ServerException(
        message:
            message ??
            'The assistant is not answering right now. Try again in a moment.',
      ),
      _ => ServerException(
        message:
            message ?? 'The assistant could not be reached. Try again shortly.',
        detail: 'ai-assistant returned ${error.status}',
      ),
    };
  }

  static const String _function = 'ai-assistant';
  static const String _logName = 'assistant';
}

/// [AssistantRepository] with no backend behind it.
///
/// Throws rather than inventing an answer. Every other in-memory repository in this
/// app returns something plausible so a screen has shape — but a fake AI reply is
/// the one piece of fake data that could be *believed*, and "here is a meal for
/// ₱120" from a stub is worse than an honest refusal.
class UnavailableAssistantRepository implements AssistantRepository {
  const UnavailableAssistantRepository();

  @override
  Future<AssistantReply> ask({
    required List<AssistantMessage> messages,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    throw const ServerException(
      message: 'The assistant needs a connection to answer.',
      detail: 'no Supabase backend configured',
    );
  }
}
