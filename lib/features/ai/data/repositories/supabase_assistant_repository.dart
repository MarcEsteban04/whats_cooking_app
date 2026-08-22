import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_choice.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';
import 'package:whats_cooking/features/ai/domain/entities/fridge_reading.dart';
import 'package:whats_cooking/features/ai/domain/entities/generated_recipe.dart';
import 'package:whats_cooking/features/ai/domain/entities/imported_list.dart';

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

  /// Reads a photo and says what food is in it (Sprint 49).
  ///
  /// **The photo is not stored anywhere.** Not in a bucket, not in a row, not in a
  /// log line — it goes into this request, on to whichever provider answers, and
  /// then nowhere. A picture of somebody's kitchen is the most personal thing this
  /// app handles, and the cheapest way to keep it safe is not to keep it.
  ///
  /// **No context is sent with it, deliberately.** Every other purpose gets the
  /// household's facts; this one would be actively harmed by them. A model told
  /// "in_the_kitchen: chicken, eggs, rice" and then shown a photo has been given
  /// the answer it is being asked for, and it will find chicken.
  ///
  /// Returns the names, lower cased and deduplicated — never a pantry write. What
  /// comes back is a *suggestion list*, and the confirmation screen is the only
  /// thing that turns one into an item.
  ///
  /// Throws, like [generateRecipe] and unlike [choose]: somebody took a photo and
  /// is watching, and the only honest outcomes are a list or a sentence.
  Future<List<String>> readFridge({
    required Uint8List image,
    String mimeType = 'image/jpeg',
  });

  /// Reads a shopping list out of a file (Sprint 53).
  ///
  /// Exactly one of [bytes] or [text] is supplied. A photo or a PDF goes as
  /// [bytes] with its [mimeType]; a `.txt` is decoded on the device and goes as
  /// [text], because text does not need to be an attachment and sending it as one
  /// would restrict which providers could answer.
  ///
  /// **The file is not stored**, on the same terms as [readFridge]: one request,
  /// on to whichever provider answers, then nowhere.
  ///
  /// Returns what it read. **Never a write** — the confirmation screen is the only
  /// thing that turns a line into something on the list, because an OCR mistake
  /// here becomes an item somebody buys.
  ///
  /// Throws, like [readFridge]: somebody picked a file and is watching.
  Future<List<ImportedItem>> readShoppingList({
    Uint8List? bytes,
    String? text,
    String mimeType = 'image/jpeg',
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

  @override
  Future<List<String>> readFridge({
    required Uint8List image,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final supabase.FunctionResponse response = await _client.functions.invoke(
        _function,
        body: <String, Object?>{
          'purpose': 'fridge_scan',
          'messages': <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': _fridgePrompt},
          ],
          // No context. See the interface — telling the model what is already in
          // the kitchen would hand it the answer it is being asked to find.
          'file': base64Encode(image),
          'fileMimeType': mimeType,
        },
      );

      if (response.data case final Map<String, dynamic> data) {
        final String text = (data['text'] as String? ?? '').trim();
        final List<String> names = FridgeReading.parse(text);

        AppLog.debug(
          'Fridge read.',
          name: _logName,
          // The names, not the reply and never the photo. This is the one AI call
          // whose input must not reach a log at any level.
          data: <String, Object?>{'found': names.length},
        );

        return names;
      }

      throw const ServerException(
        message: 'The assistant sent something we could not read.',
      );
    } on supabase.FunctionException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  /// What the model is asked about the photo.
  ///
  /// **Short, and it forbids prose.** Everything this parser has to defend against
  /// is a model being conversational — "I can see the following items" arriving as
  /// an ingredient is the failure mode — so the instruction spends its words on the
  /// shape rather than on the task, which is obvious from the picture.
  ///
  /// "Only what you can actually see" is the other half. A model asked what is in a
  /// fridge will happily add milk, because fridges have milk.
  static const String _fridgePrompt =
      'List the food you can see in this picture. Only what is actually '
      'visible — do not add anything you would expect to be there.\n\n'
      'One ingredient per line. Two or three words at most per line, everyday '
      'names, no quantities, no brands, no headings, no other text.\n\n'
      'If there is no food in the picture, reply with the single word NONE.';

  @override
  Future<List<ImportedItem>> readShoppingList({
    Uint8List? bytes,
    String? text,
    String mimeType = 'image/jpeg',
  }) async {
    final String? trimmed = text?.trim();

    if (bytes == null && (trimmed == null || trimmed.isEmpty)) {
      throw const ValidationException(
        message: 'There was nothing in that file.',
      );
    }

    try {
      final supabase.FunctionResponse response = await _client.functions.invoke(
        _function,
        body: <String, Object?>{
          'purpose': 'grocery_import',
          'messages': <Map<String, Object?>>[
            <String, Object?>{
              'role': 'user',
              'content': trimmed == null || trimmed.isEmpty
                  ? _listPrompt
                  : '$_listPrompt\n\nThe list:\n'
                        '${trimmed.substring(0, min(trimmed.length, _maxTextChars))}',
              // Kept here so the caller can say a long file was cut, rather than
              // the tail vanishing without a word.
            },
          ],
          // No context, for the same reason the fridge scan sends none: a model
          // told what is already on the list has been handed half the answer, and
          // it will find those items whether or not they are in the file.
          if (bytes != null) ...<String, Object?>{
            'file': base64Encode(bytes),
            'fileMimeType': mimeType,
          },
        },
      );

      if (response.data case final Map<String, dynamic> data) {
        final List<ImportedItem> items = ImportedList.parse(
          (data['text'] as String? ?? '').trim(),
        );

        AppLog.debug(
          'Shopping list read.',
          name: _logName,
          // The count, never the contents and never the file.
          data: <String, Object?>{'found': items.length, 'type': mimeType},
        );

        return items;
      }

      throw const ServerException(
        message: 'The assistant sent something we could not read.',
      );
    } on supabase.FunctionException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  /// What the model is asked about a shopping list.
  ///
  /// **Quantities are wanted here**, unlike the fridge scan. Somebody wrote "2 kg
  /// rice" deliberately, and an import that drops the 2 is worse than the paper it
  /// replaced.
  ///
  /// The instruction spends its words on the shape rather than the task, because
  /// everything the parser has to defend against is a model being conversational —
  /// "Here are the items from your list:" arriving as something to buy is the
  /// failure mode.
  static const String _listPrompt =
      'This is a shopping list. Copy out EVERY line of it, one per line.\n\n'
      // **The word "every", and then again three ways.** The first version said
      // "copy out the things to buy" and got six items off a twenty-seven line
      // screenshot — which is a reasonable reading of a prompt that never asked
      // for all of them. A model given a long list and no instruction about
      // completeness will summarise, because summarising is usually what is
      // wanted.
      'Copy them ALL. Do not stop early, do not skip lines, do not summarise, '
      'do not merge two lines into one, and do not decide something is not worth '
      'including. A list can run to forty lines or more; go to the very bottom '
      'of it.\n\n'
      'Copy the words as written, even brand names, misspellings and words that '
      'are not English. Do not translate or correct them.\n\n'
      'Keep any quantity and unit that is written, at the front of the line, '
      'like "2 kg rice" or "3 pcs onion". Leave them out when the list does not '
      'say. Only what is actually on the list — do not add anything you would '
      'expect. No headings, no prices, no totals, no numbering, no other text.\n\n'
      'If there is no shopping list here, reply with the single word NONE.';

  /// How much of a text file is sent.
  ///
  /// **Sized to fit the Edge Function's own per-message cap, not to a round
  /// number.** The function keeps `MAX_MESSAGE_CHARS` (2,000) of each message and
  /// *silently truncates* the rest — it does not refuse it — so this was set to
  /// 8,000 and quietly lost everything past the first ~1,550 characters of any
  /// long list. A cut nobody is told about is the worst of the three options.
  ///
  /// 1,400 leaves room for the prompt in front of it and is about a hundred lines
  /// of shopping list. A file longer than that is either not a shopping list or
  /// is one nobody reads in an aisle, and the caller says so rather than dropping
  /// the tail in silence.
  static const int _maxTextChars = 1400;

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
      // The photo was bigger than the function will forward (Sprint 49). Its own
      // case because it is the one failure here somebody can act on themselves,
      // and the function's sentence says how.
      'file_too_large' => ServerException(
        message: message ?? 'That file is too big. Try a smaller one.',
      ),
      'unavailable' => ServerException(
        message:
            message ??
            'The assistant is not answering right now. Try again in a moment.',
      ),
      // **A 400 from our own function means the two sides disagree.** Both ends
      // of this call ship from this repository, so the app cannot send a body the
      // function does not understand *unless the deployed function is older than
      // the app* — a new `purpose` or a new field it has never heard of. That is
      // exactly what it looked like on the phone: "Something went wrong.
      // ai-assistant returned 400", which is true and tells nobody what to do.
      //
      // The function's own `bad_request` message is deliberately vague, so this
      // one does not use it.
      'bad_request' => const ServerException(
        message: 'The assistant on the server is out of date. It needs '
            'redeploying before this works.',
        detail: 'ai-assistant rejected the request as bad_request — most likely '
            'a purpose or field added after the last deploy',
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

  @override
  Future<List<String>> readFridge({
    required Uint8List image,
    String mimeType = 'image/jpeg',
  }) async {
    throw const ServerException(
      message: 'Reading a photo needs a connection.',
      detail: 'no Supabase backend configured',
    );
  }

  @override
  Future<List<ImportedItem>> readShoppingList({
    Uint8List? bytes,
    String? text,
    String mimeType = 'image/jpeg',
  }) async {
    throw const ServerException(
      message: 'Importing a list needs a connection.',
      detail: 'no Supabase backend configured',
    );
  }
}
