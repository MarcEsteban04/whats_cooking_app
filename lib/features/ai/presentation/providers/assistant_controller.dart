import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/features/ai/data/assistant_memory.dart';
import 'package:whats_cooking/features/ai/data/repositories/supabase_assistant_repository.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';
import 'package:whats_cooking/features/ai/presentation/providers/ai_context.dart';

part 'assistant_controller.g.dart';

/// The assistant backend.
@Riverpod(keepAlive: true)
AssistantRepository assistantRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    return const UnavailableAssistantRepository();
  }
  return SupabaseAssistantRepository(ref.read(supabaseClientProvider));
}

/// A conversation with the assistant (Sprint 47).
@immutable
class AssistantConversation {
  const AssistantConversation({
    this.messages = const <AssistantMessage>[],
    this.isThinking = false,
    this.failure,
  });

  final List<AssistantMessage> messages;

  /// True between sending and the reply arriving.
  ///
  /// Its own flag rather than an `AsyncLoading`, because the conversation is still
  /// there and still worth reading while the next answer is coming — a loading
  /// state that blanks the screen would hide the question just asked.
  final bool isThinking;

  /// The last failure, or null.
  ///
  /// Kept beside the conversation rather than replacing it: a rate limit is not a
  /// reason to lose what was already said.
  final AppException? failure;

  bool get isEmpty => messages.isEmpty;

  AssistantConversation copyWith({
    List<AssistantMessage>? messages,
    bool? isThinking,
    AppException? failure,
    bool clearFailure = false,
  }) {
    return AssistantConversation(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Asking the app in words (Sprint 47).
///
/// **Context is assembled here, not in the UI and not in the Edge Function.** The
/// function renders whatever it is given as a labelled block of facts; deciding
/// *which* facts is a product judgement, and it is the difference between an
/// assistant that answers "what can we cook tonight" and one that guesses.
///
/// `keepAlive`, so backing out of the screen and returning does not lose the
/// conversation. A chat that forgets the moment you check the pantry is a chat
/// nobody uses twice.
@Riverpod(keepAlive: true)
class AssistantController extends _$AssistantController {
  @override
  AssistantConversation build() {
    // Not awaited, and the build stays synchronous on purpose (Sprint 50). An
    // `AsyncNotifier` here would make every screen that reads the conversation
    // handle a loading state for a disk read that takes a millisecond — and the
    // right thing to show while it happens is the empty conversation, which is
    // exactly what this returns.
    _restore();
    return const AssistantConversation();
  }

  /// Puts last week's conversation back, if there is one.
  ///
  /// Only when nothing has happened yet. Somebody who opened the screen and
  /// started typing before the disk answered must not have their question
  /// swallowed by a restore — the fresh thing wins.
  Future<void> _restore() async {
    final List<AssistantMessage> stored = await _memory.load();

    if (stored.isEmpty || !state.isEmpty || state.isThinking) {
      return;
    }
    state = state.copyWith(messages: stored);
  }

  /// Asks something.
  Future<void> ask(String question) async {
    final String trimmed = question.trim();
    if (trimmed.isEmpty || state.isThinking) {
      return;
    }

    final List<AssistantMessage> withQuestion = <AssistantMessage>[
      ...state.messages,
      AssistantMessage.user(trimmed),
    ];

    state = state.copyWith(
      messages: withQuestion,
      isThinking: true,
      clearFailure: true,
    );

    try {
      final AssistantReply reply = await ref
          .read(assistantRepositoryProvider)
          .ask(messages: withQuestion, context: await householdAiContext(ref));

      state = state.copyWith(
        messages: <AssistantMessage>[
          ...withQuestion,
          AssistantMessage(
            role: AssistantRole.assistant,
            content: reply.text,
            provider: reply.provider,
          ),
        ],
        isThinking: false,
      );

      // Saved after a whole exchange, not after each turn. A question with no
      // answer under it is not a conversation worth restoring — and a failed ask
      // leaves exactly that.
      await _memory.save(state.messages);
    } on Object catch (error, stackTrace) {
      // The question stays in the list. Losing what somebody typed because the
      // answer failed is the one thing that would make them stop trying.
      state = state.copyWith(
        isThinking: false,
        failure: ErrorMapper.map(error, stackTrace),
      );
    }
  }

  /// Asks the last question again, after a failure.
  Future<void> retry() async {
    final AssistantMessage? last = state.messages.isEmpty
        ? null
        : state.messages.last;

    if (last == null || !last.isUser) {
      return;
    }

    // Dropped and re-asked rather than resent, so the list does not end up with
    // the same question twice.
    state = state.copyWith(
      messages: state.messages.sublist(0, state.messages.length - 1),
      clearFailure: true,
    );
    await ask(last.content);
  }

  /// Starts over.
  ///
  /// Wipes the stored copy too. "Start again" that leaves last week's thread on
  /// disk to reappear on the next launch is a button that does not do what it
  /// says.
  void clear() {
    state = const AssistantConversation();
    _memory.clear();
  }

  static const AssistantMemory _memory = AssistantMemory();
}
