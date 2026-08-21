import 'package:flutter/foundation.dart';

/// One option the assistant may choose between (Sprint 47c).
///
/// A flat description rather than the entity, so the same call can choose a meal or
/// a restaurant without the AI feature importing either. The roulette owns the
/// question; this owns asking it.
@immutable
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.name,
    required this.detail,
  });

  final String id;
  final String name;

  /// One line the model can reason over: cuisine, cost, time, tags.
  final String detail;
}

/// Which option the assistant picked, and why.
@immutable
class AssistantChoice {
  const AssistantChoice({required this.id, required this.reason});

  final String id;

  /// A short phrase for the result screen.
  ///
  /// This is the whole point of asking. The engine can say *"Filipino is one of
  /// your favourites"*; a model with the same context can say *"you had adobo on
  /// Tuesday and there is chicken to use up"* — which is what a person would
  /// actually say, and the difference between a recommendation and a lookup.
  final String reason;

  /// Parses the reply.
  ///
  /// **The model is asked for `index | reason`**, not for a uuid. Models mangle
  /// long random identifiers often enough that asking for one would make the parse
  /// the least reliable part of the feature; a number between 1 and 12 is something
  /// every model gets right. The caller maps the index back to its own list, which
  /// is also what makes an out-of-range answer impossible to act on.
  ///
  /// Returns null on anything unexpected. There is no partial success here: a reply
  /// that cannot be read is a reply the caller ignores in favour of the
  /// deterministic pick it already has.
  static ({int index, String reason})? parse(String reply) {
    final String trimmed = reply.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // The first run of digits anywhere in the reply. Lenient on purpose: models
    // prepend "Sure — " and wrap things in markdown, and refusing those would
    // throw away answers that are perfectly good after the first four characters.
    final RegExpMatch? match = RegExp(r'(\d{1,2})').firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final int? index = int.tryParse(match.group(1)!);
    if (index == null) {
      return null;
    }

    // Everything after the number, minus whatever separator was used.
    String reason = trimmed.substring(match.end).trim();
    reason = reason.replaceFirst(RegExp(r'^[|\-:—.,)\s]+'), '').trim();

    // First sentence only, and capped. The system prompt allows 120 words and the
    // result screen has room for about eight — a paragraph under the meal name
    // would push the accept button off a small screen.
    final int stop = reason.indexOf('. ');
    if (stop > 0) {
      reason = reason.substring(0, stop);
    }
    reason = reason.replaceAll(RegExp(r'[.\s]+$'), '');

    if (reason.length > _maxReason) {
      reason = '${reason.substring(0, _maxReason).trimRight()}…';
    }

    return (index: index, reason: reason);
  }

  static const int _maxReason = 90;
}
