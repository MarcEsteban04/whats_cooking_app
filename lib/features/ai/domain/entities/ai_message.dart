import 'package:flutter/foundation.dart';

/// Who said a thing.
enum AiRole {
  user,
  assistant;

  String get wireValue => name;
}

/// One turn of a conversation with the assistant (Sprint 59).
@immutable
class AiMessage {
  const AiMessage({required this.role, required this.content});

  const AiMessage.user(this.content) : role = AiRole.user;

  const AiMessage.assistant(this.content) : role = AiRole.assistant;

  final AiRole role;
  final String content;

  Map<String, Object?> toWire() => <String, Object?>{
    'role': role.wireValue,
    'content': content,
  };

  @override
  bool operator ==(Object other) =>
      other is AiMessage && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);
}

/// What the assistant is being asked to do.
///
/// Sent so the Edge Function can attribute cost to a feature rather than to
/// "AI": a spike that cannot be traced to a screen cannot be fixed. The values
/// match the `purpose` check constraint on `ai_usage` (migration 0017).
enum AiPurpose {
  /// "What should we eat tonight?" (Sprint 60).
  assistant,

  /// "Create a recipe using chicken, eggs and rice." (Sprint 61).
  recipe,

  /// A photo of a fridge (Sprint 62).
  fridgeScan('fridge_scan'),

  /// Re-ranking from history and preferences (Sprint 63).
  personalise;

  const AiPurpose([this._wireValue]);

  final String? _wireValue;

  String get wireValue => _wireValue ?? name;
}

/// What came back.
@immutable
class AiReply {
  const AiReply({
    required this.text,
    required this.provider,
    required this.model,
  });

  final String text;

  /// Which of the three answered — `groq`, `gemini` or `openai`.
  ///
  /// Surfaced rather than hidden because the failover is invisible otherwise: a
  /// build that can see the third provider answered is a build somebody can
  /// diagnose a slow evening from. Never shown to a user.
  final String provider;

  final String model;

  @override
  bool operator ==(Object other) =>
      other is AiReply &&
      other.text == text &&
      other.provider == provider &&
      other.model == model;

  @override
  int get hashCode => Object.hash(text, provider, model);
}
