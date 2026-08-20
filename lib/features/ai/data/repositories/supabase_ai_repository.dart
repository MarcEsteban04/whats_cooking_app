import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/ai/domain/entities/ai_message.dart';
import 'package:whats_cooking/features/ai/domain/repositories/ai_repository.dart';

/// [AiRepository] that calls the `ai-assistant` Edge Function.
///
/// The whole implementation is one `invoke`. That is the point: the client has
/// nothing to decide, because deciding would mean knowing which providers exist
/// and holding a key for one of them.
class SupabaseAiRepository implements AiRepository {
  SupabaseAiRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AiReply> ask({
    required List<AiMessage> messages,
    AiPurpose purpose = AiPurpose.assistant,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return RemoteCall.guard(
      () async {
        final FunctionResponse response;
        try {
          response = await _client.functions.invoke(
            _function,
            body: <String, Object?>{
              'purpose': purpose.wireValue,
              'messages': <Map<String, Object?>>[
                for (final AiMessage message in messages) message.toWire(),
              ],
              'context': context,
            },
          );
        } on FunctionException catch (error) {
          // `invoke` throws on any non-2xx rather than returning it, so this —
          // not the happy path below — is where every rate limit and outage
          // actually lands. Reading the body here is what turns a 429 into
          // "you have used the assistant a lot in the last hour" instead of
          // "Something went wrong".
          throw _mapFunctionFailure(error);
        }

        final Object? data = response.data;
        if (data is! Map<String, dynamic>) {
          throw const ServerException();
        }

        // A 2xx carrying an error code should not happen, and is honoured anyway:
        // the alternative is returning the word "unavailable" to somebody as
        // though it were dinner advice.
        if (data['code'] case final String code) {
          throw _mapFunctionError(code, data['message'] as String?);
        }

        if (data['text'] case final String text) {
          return AiReply(
            text: text,
            provider: data['provider'] as String? ?? 'unknown',
            model: data['model'] as String? ?? 'unknown',
          );
        }

        throw const ServerException();
      },
      label: 'ai.ask',
      // **No retry.** The function already tried three providers, each with its
      // own timeout, before giving up. A retry here is a fourth attempt that
      // costs another twelve seconds of somebody's evening and another row
      // against their rate limit, to ask the same three services that just said
      // no.
      policy: RetryPolicy.none,
      // Longer than the standard request timeout, and deliberately so: three
      // providers at twelve seconds each is a worst case this has to outlast, or
      // the client gives up on a request the server is still usefully working on.
      timeout: _aiTimeout,
    );
  }

  /// Reads the function's own error shape out of a thrown [FunctionException].
  ///
  /// Falls back to the status when the body is not the shape this function
  /// sends — a gateway timeout or a cold-start failure never reaches the
  /// function's own code, so there is nothing to read.
  AppException _mapFunctionFailure(FunctionException error) {
    if (error.details case final Map<String, dynamic> body) {
      if (body['code'] case final String code) {
        return _mapFunctionError(code, body['message'] as String?);
      }
    }

    return switch (error.status) {
      401 || 403 => const AuthFailureException(
        message: 'Please sign in again',
        detail: 'ai-assistant rejected the token',
        isSessionExpired: true,
      ),
      429 => const ValidationException(
        message: 'That is enough assistant for now. Try again a bit later.',
      ),
      _ => ServerException(detail: 'ai-assistant returned ${error.status}'),
    };
  }

  /// Turns the function's `code` into the app's own failure types.
  ///
  /// Named codes rather than status numbers, so the two sides can be read
  /// against each other — and so a new failure mode arrives as an unknown code
  /// rather than as a misinterpreted 503.
  AppException _mapFunctionError(String code, String? message) {
    return switch (code) {
      'unauthenticated' => const AuthFailureException(
        message: 'Please sign in again',
        detail: 'ai-assistant rejected the token',
        isSessionExpired: true,
      ),
      'rate_limited' => ValidationException(
        message: message ?? 'That is enough assistant for now.',
      ),
      // Both mean "not now" — which is what `ServerException` already says to
      // the retry policy and to the error state. The function's own wording is
      // used when it sent one, because it knows whether the assistant is down
      // or was never switched on.
      'unavailable' || 'misconfigured' => ServerException(
        message: message ?? 'Something went wrong',
      ),
      _ => const ServerException(),
    };
  }

  static const String _function = 'ai-assistant';

  /// Three providers at twelve seconds, plus the round trip.
  static const Duration _aiTimeout = Duration(seconds: 45);
}
