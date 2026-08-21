import 'package:flutter/foundation.dart';

/// Who said something in an assistant conversation.
enum AssistantRole {
  user,
  assistant;

  /// The wire value the Edge Function validates against.
  String get value => name;
}

/// One turn of the conversation (Sprint 47).
@immutable
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.content,
    this.provider,
  });

  const AssistantMessage.user(this.content)
    : role = AssistantRole.user,
      provider = null;

  final AssistantRole role;
  final String content;

  /// Which provider answered, on an assistant turn.
  ///
  /// Shown in development, and it is not a secret: `ai-assistant` returns it
  /// deliberately so that a slow evening can be debugged rather than guessed at.
  /// Three providers answer this app, and "which one was it" is the first question
  /// worth asking when one of them is having a bad day.
  final String? provider;

  bool get isUser => role == AssistantRole.user;

  /// The shape `ai-assistant` expects. Nothing else is sent.
  Map<String, Object?> toWire() => <String, Object?>{
    'role': role.value,
    'content': content,
  };
}

/// What the assistant said, and who said it.
@immutable
class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.provider,
    required this.model,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    return AssistantReply(
      text: (json['text'] as String? ?? '').trim(),
      provider: json['provider'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'unknown',
    );
  }

  final String text;
  final String provider;
  final String model;
}
