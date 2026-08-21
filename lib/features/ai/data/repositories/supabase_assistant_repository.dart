import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_choice.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';
import 'package:whats_cooking/features/ai/domain/entities/generated_recipe.dart';

/// Asking the assistant something (Sprint 47).
///
/// **Nothing here streams.** The roadmap asked for "streaming where
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

  /// Picks one of [options] and says why (Sprint 47c).
  ///
  /// **The shortlist is the safety mechanism.** The model never chooses from the
  /// library — it chooses from a list the deterministic engine has already
  /// filtered, so every possible answer is one that respects the dietary needs,
  /// the avoided foods, the hidden meals and the repetition window. Those are
  /// promises, and an LLM cannot be the thing that keeps them.
  ///
  /// Returns null on anything unexpected — a failure, a timeout, an unreadable
  /// reply, an index out of range. The caller always has the engine's own pick in
  /// hand, so null means "keep it" rather than "no answer".
  ///
  /// **Throws [RateLimitException], and only that.** A rate limit is the one
  /// failure the caller has to act on rather than shrug at: the next spin will
  /// fail the same way for the rest of the hour, so a caller that cannot tell it
  /// apart from a slow model would keep paying for round trips it already knows
  /// the answer to.
  Future<AssistantChoice?> choose({
    required List<ChoiceOption> options,
    Map<String, Object?> context,
    Duration? timeout,
  });

  /// Writes a recipe around [ingredients] (Sprint 48).
  ///
  /// The one place in this app where the model produces something that gets
  /// *stored* rather than said. Which is why it does not get stored from here:
  /// what comes back is a [GeneratedRecipe], the screen shows it, and saving it
  /// goes through the ordinary meal form with a person's finger on the button.
  ///
  /// **Throws, unlike [choose].** A choice that fails still has the engine's pick
  /// behind it, so silence is an answer. This has nothing behind it — somebody
  /// asked for a recipe and is watching a spinner, and the only honest outcomes
  /// are a recipe or a sentence saying why not.
  Future<GeneratedRecipe> generateRecipe({
    required List<String> ingredients,
    String? note,
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

  @override
  Future<AssistantChoice?> choose({
    required List<ChoiceOption> options,
    Map<String, Object?> context = const <String, Object?>{},
    Duration? timeout,
  }) async {
    if (options.isEmpty) {
      return null;
    }

    // **Nothing here throws.** Every caller already holds a deterministic pick,
    // so a failure means "keep yours" — and a spin that surfaced an error banner
    // because a model was slow would be the tail wagging the dog.
    try {
      final Future<supabase.FunctionResponse> call = _client.functions.invoke(
        _function,
        body: <String, Object?>{
          'purpose': 'assistant',
          'messages': <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': _prompt(options)},
          ],
          'context': context,
        },
      );

      final supabase.FunctionResponse response = timeout == null
          ? await call
          : await call.timeout(timeout);

      if (response.data case final Map<String, dynamic> data) {
        final String text = (data['text'] as String? ?? '').trim();
        final ({int index, String reason})? parsed =
            AssistantChoice.parse(text);

        // **Bounds are the guarantee, not a nicety.** The index maps back into
        // the caller's own shortlist, so an answer outside it cannot be acted on
        // — which is exactly why the model is asked for a number rather than a
        // meal name it could invent.
        if (parsed == null ||
            parsed.index < 1 ||
            parsed.index > options.length ||
            parsed.reason.isEmpty) {
          AppLog.debug(
            'Assistant choice unusable.',
            name: _logName,
            data: <String, Object?>{'reply': text},
          );
          return null;
        }

        return AssistantChoice(
          id: options[parsed.index - 1].id,
          reason: parsed.reason,
        );
      }
      return null;
    } on supabase.FunctionException catch (error) {
      final AppException mapped = _mapFunctionError(error);
      if (mapped is RateLimitException) {
        // The one that propagates. See the interface.
        throw mapped;
      }
      return null;
    } on Object catch (error) {
      AppLog.debug(
        'Assistant did not choose.',
        name: _logName,
        data: <String, Object?>{'reason': error.toString()},
      );
      return null;
    }
  }

  /// What the model is asked.
  ///
  /// Numbered, one per line, and the reply format stated twice — once as an
  /// instruction and once as an example. The system prompt on the function is about
  /// *being* the assistant; this message is about the one job, and a short strict
  /// format is the difference between a parse that works and one that works most
  /// evenings.
  static String _prompt(List<ChoiceOption> options) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'Pick one of these for dinner tonight, using what you know about this '
        'household.',
      )
      ..writeln();

    for (final (int index, ChoiceOption option) in options.indexed) {
      buffer.writeln('${index + 1}. ${option.name} — ${option.detail}');
    }

    buffer
      ..writeln()
      ..writeln(
        'Reply with the number, a pipe, and one short reason of at most twelve '
        'words. No other text.',
      )
      ..writeln('Example: 3 | you have the chicken and have not had it in weeks');

    return buffer.toString();
  }

  @override
  Future<GeneratedRecipe> generateRecipe({
    required List<String> ingredients,
    String? note,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    // Not retried, for the same reason `ask` is not: the function has already
    // tried three providers, and a fourth attempt from here is a second bill for
    // the same answer.
    try {
      final supabase.FunctionResponse response = await _client.functions.invoke(
        _function,
        body: <String, Object?>{
          'purpose': 'recipe',
          'messages': <Map<String, Object?>>[
            <String, Object?>{
              'role': 'user',
              'content': _recipePrompt(ingredients, note),
            },
          ],
          'context': context,
        },
      );

      if (response.data case final Map<String, dynamic> data) {
        final String text = (data['text'] as String? ?? '').trim();

        if (GeneratedRecipe.parse(text) case final GeneratedRecipe recipe) {
          return recipe;
        }

        // A 200 the parser could not use. Logged with the reply, because this is
        // the one failure mode that is a *prompt* problem rather than an outage,
        // and it is invisible without the text that caused it.
        AppLog.warning(
          'Recipe reply unusable.',
          name: _logName,
          data: <String, Object?>{'length': text.length},
        );
        AppLog.debug(
          'Recipe reply.',
          name: _logName,
          data: <String, Object?>{'reply': text},
        );

        throw const ServerException(
          message: 'That came back in a shape we could not read. Try again.',
        );
      }

      throw const ServerException(
        message: 'The assistant sent something we could not read.',
      );
    } on supabase.FunctionException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  /// What the model is asked for a recipe.
  ///
  /// **A labelled block, and the format is given as a filled-in example.** Telling
  /// a model the shape it should answer in works; showing it the shape works
  /// better, and this reply has ten fields to get right rather than one. See
  /// [GeneratedRecipe] for why the shape is labelled lines rather than JSON.
  ///
  /// The counts are deliberate. The function caps output at 700 tokens, so "at
  /// most ten ingredients and eight steps" is not a style preference — it is the
  /// difference between a recipe that ends and one that is cut off mid-sentence
  /// where the steps should be.
  static String _recipePrompt(List<String> ingredients, String? note) {
    final String have = ingredients
        .map((String name) => name.trim())
        .where((String name) => name.isNotEmpty)
        .join(', ');

    final StringBuffer buffer = StringBuffer()
      ..writeln(
        have.isEmpty
            ? 'Invent a dinner this household could cook tonight.'
            : 'Write one recipe using mostly: $have.',
      );

    if (note != null && note.trim().isNotEmpty) {
      // Somebody's own words, and they go in as a *request* rather than as part
      // of the instruction — the same reason the Edge Function renders context as
      // facts. A line typed into a text field is not allowed to redefine the
      // reply format.
      buffer.writeln('They also said: "${note.trim()}"');
    }

    buffer
      ..writeln()
      ..writeln(
        'It has to be something a Filipino household can actually cook. Assume '
        'salt, oil, garlic, onion, soy sauce and vinegar are already there. You '
        'may add up to three cheap things they would have to buy.',
      )
      ..writeln()
      ..writeln('Reply in exactly this shape and nothing else:')
      ..writeln()
      ..writeln('NAME: Chicken and egg rice bowl')
      ..writeln('CUISINE: filipino')
      ..writeln('CATEGORY: dinner')
      ..writeln('DIFFICULTY: easy')
      ..writeln('TIME: 25')
      ..writeln('COST: 180')
      ..writeln('SERVINGS: 2')
      ..writeln('INGREDIENTS:')
      ..writeln('- 300 g chicken thigh')
      ..writeln('- 2 pc egg')
      ..writeln('- 2 cup rice')
      ..writeln('STEPS:')
      ..writeln('- Season the chicken and fry it until brown.')
      ..writeln('- Scramble the eggs in the same pan.')
      ..writeln()
      ..writeln(
        'TIME is whole minutes. COST is pesos for the whole dish, not per head. '
        'Quantities use only g, ml, pc, tbsp, tsp or cup. At most ten '
        'ingredients and eight steps.',
      );

    return buffer.toString();
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

  @override
  Future<AssistantChoice?> choose({
    required List<ChoiceOption> options,
    Map<String, Object?> context = const <String, Object?>{},
    Duration? timeout,
  }) async {
    // Null, not a throw, unlike [ask]. A conversation with no backend has to say
    // so; a spin with no backend simply keeps the engine's pick, which is the
    // right answer and needs no telling.
    return null;
  }

  @override
  Future<GeneratedRecipe> generateRecipe({
    required List<String> ingredients,
    String? note,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    throw const ServerException(
      message: 'Writing a recipe needs a connection.',
      detail: 'no Supabase backend configured',
    );
  }
}
