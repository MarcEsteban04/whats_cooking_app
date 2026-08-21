import 'package:whats_cooking/core/data/timestamped_store.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';

/// The conversation, kept across app launches (Sprint 50).
///
/// **This is what "previous conversations" means here.** The roadmap asks for the
/// assistant to be fed what the app knows, and a chat that forgets everything the
/// moment the app is closed is the one gap no amount of context lines fills: you
/// tell it on Monday that you cannot eat prawns, and on Tuesday it is a stranger
/// again. `keepAlive` on the controller survives navigation; it does not survive
/// the process.
///
/// **On the device, not in a table.** A transcript store would be a migration, a
/// policy, a retention question and a screen to browse it — and none of that is
/// worth building for a household of two on one phone. `TimestampedStore` already
/// carries the two properties that matter: a TTL, and the `cache.` prefix that the
/// sign-out sweep clears without knowing this file exists.
///
/// A week, not forever. Continuity is "we were talking about this yesterday";
/// a fortnight-old exchange about a dinner already eaten is clutter that costs
/// tokens on every turn, because the whole tail is sent with the next question.
class AssistantMemory {
  const AssistantMemory();

  /// The last few turns, oldest first. Empty when there is nothing usable.
  Future<List<AssistantMessage>> load() async {
    final TimestampedValue? stored = await _store.read(now: DateTime.now());
    if (stored?.payload is! List<dynamic>) {
      return const <AssistantMessage>[];
    }

    final List<AssistantMessage> messages = <AssistantMessage>[];

    for (final Object? row in stored!.payload as List<dynamic>) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final AssistantRole? role = switch (row['role']) {
        'user' => AssistantRole.user,
        'assistant' => AssistantRole.assistant,
        _ => null,
      };
      final Object? content = row['content'];

      // Anything unreadable is skipped rather than failing the load. A garbled
      // row costs one turn of history; throwing would cost the conversation and
      // the screen behind it.
      if (role == null || content is! String || content.isEmpty) {
        continue;
      }

      messages.add(AssistantMessage(role: role, content: content));
    }

    return messages;
  }

  /// Stores the tail of [messages].
  ///
  /// The tail rather than all of it, matching what actually gets sent: the Edge
  /// Function keeps twelve messages, so persisting a hundred would be a hundred
  /// rows on disk to reload and then discard.
  ///
  /// **The provider is not stored.** It is a developer's fact about one reply on
  /// one evening, and a restored conversation attributing an answer to a provider
  /// that may not even have been tried would be worse than saying nothing.
  Future<void> save(List<AssistantMessage> messages) async {
    if (messages.isEmpty) {
      await _store.clear();
      return;
    }

    final List<AssistantMessage> tail = messages.length > _maxTurns
        ? messages.sublist(messages.length - _maxTurns)
        : messages;

    await _store.write(<Map<String, Object?>>[
      for (final AssistantMessage message in tail) message.toWire(),
    ], now: DateTime.now());
  }

  /// Forgets it, for "Start again".
  Future<void> clear() => _store.clear();

  /// Versioned, per [TimestampedStore]'s convention, and prefixed so the
  /// sign-out sweep finds it.
  static const TimestampedStore _store = TimestampedStore(
    'cache.assistant.conversation.v1',
    ttl: Duration(days: 7),
  );

  /// Twelve is what the function keeps; twenty leaves room for the screen to show
  /// a little more of the thread than the model is told about.
  static const int _maxTurns = 20;
}
