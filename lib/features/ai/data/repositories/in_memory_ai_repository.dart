import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/ai/domain/entities/ai_message.dart';
import 'package:whats_cooking/features/ai/domain/repositories/ai_repository.dart';

/// [AiRepository] with no AI behind it.
///
/// What a build with no backend falls back to, and what tests run against. It
/// does **not** pretend to answer: a canned suggestion that looked like the
/// assistant working would be the single most misleading thing in this codebase —
/// somebody would demo it.
///
/// So it says what is true. The failure is the same `ServerException` the real
/// path raises when every provider is down, which means the screens that handle
/// one handle the other.
class InMemoryAiRepository implements AiRepository {
  InMemoryAiRepository({this.latency = _defaultLatency});

  /// Simulated round trip. Exposed so a widget test can advance the fake clock
  /// past it rather than awaiting a real delay, which deadlocks the binding.
  final Duration latency;

  /// Set to have it answer instead of refusing, for exercising a reply layout
  /// without a key. Deliberately opt-in and deliberately obvious.
  String? cannedReply;

  @override
  Future<AiReply> ask({
    required List<AiMessage> messages,
    AiPurpose purpose = AiPurpose.assistant,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    await Future<void>.delayed(latency);

    if (cannedReply case final String text) {
      return AiReply(text: text, provider: 'in-memory', model: 'none');
    }

    throw const ServerException(
      message: 'The assistant needs a backend. Add credentials and try again.',
      detail: 'InMemoryAiRepository has no provider',
    );
  }

  static const Duration _defaultLatency = Duration(milliseconds: 400);
}
