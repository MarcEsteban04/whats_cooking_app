import 'package:flutter/foundation.dart';

/// How much of one meal is already in the kitchen (Sprint 41).
///
/// **Staples and optional ingredients are not counted.** That is the rule
/// docs/USER_FLOWS.md §12 sets as an acceptance criterion — without it every meal
/// caps near 80% because nobody logs salt, and a percentage that never reaches
/// 100 is a percentage nobody trusts. Optional goes for a stronger reason still: a
/// recipe listing coriander as a garnish can be cooked without it, so counting it
/// missing would report a shortfall that does not exist.
///
/// Computed by `pantry_match()` rather than in Dart, because the spin's pool is up
/// to 200 meals and their ingredient lists are roughly six rows each — a payload
/// the one interaction that must not wait cannot afford.
@immutable
class PantryMatch {
  const PantryMatch({
    required this.needed,
    required this.have,
    this.missing = const <String>[],
  });

  factory PantryMatch.fromRow(Map<String, dynamic> row) {
    return PantryMatch(
      needed: (row['needed'] as num?)?.toInt() ?? 0,
      have: (row['have'] as num?)?.toInt() ?? 0,
      missing: <String>[
        for (final Object? name
            in (row['missing'] as List<Object?>?) ?? const <Object?>[])
          if (name is String) name,
      ],
    );
  }

  /// How many ingredients count toward the match at all.
  ///
  /// Zero is a real answer, not a missing one: a meal whose every ingredient is a
  /// staple has nothing it could be short of.
  final int needed;

  /// How many of those are in the kitchen.
  final int have;

  /// Up to three of the missing names, alphabetical.
  ///
  /// Capped in the database. "Everything but the bay leaves" is a sentence;
  /// "everything but nine things" is not, so past a couple the count carries the
  /// meaning and the names would be noise on the wire.
  final List<String> missing;

  /// 0 to 1. **One when nothing is needed**, because a meal built entirely from
  /// staples is ready rather than unmeasurable.
  double get fraction => needed == 0 ? 1 : have / needed;

  /// Everything is in.
  bool get isComplete => have >= needed;

  /// How many are missing.
  int get shortBy => (needed - have).clamp(0, needed);

  /// "everything but the bay leaves", or null when that is not the sentence.
  ///
  /// Only for one or two missing, and only when the names came back. Past that the
  /// phrase stops being encouraging and starts being a shopping list — and a
  /// result screen exists to make somebody feel good about a decision.
  String? get shortfallPhrase {
    if (isComplete || shortBy > _phraseLimit || missing.isEmpty) {
      return null;
    }
    if (missing.length == 1) {
      return 'everything but the ${missing.first}';
    }
    return 'everything but the ${missing.first} and the ${missing[1]}';
  }

  /// Most of the way there.
  ///
  /// The threshold the roulette rewards. Two thirds rather than a half: at a half
  /// "you mostly have this" is a claim somebody standing at their fridge will
  /// disagree with, and the whole signal depends on being believed.
  bool get isMostlyIn => fraction >= _mostlyThreshold;

  /// What share of the ingredient bonus a partial match earns, 0 to 1.
  ///
  /// Ramped across the band **above** the threshold rather than across the whole
  /// range, because the whole range is the wrong scale: with the generic ramp a
  /// meal two thirds in scored 16 of 20 against a complete meal's 20, which is not
  /// the gap between "go and cook this" and "go to the shop first".
  ///
  /// Starts at 0.3 rather than 0, so scraping past the threshold is worth
  /// something immediately — a reason worth zero points is a reason the result
  /// screen will never show, since it only ever displays positive ones.
  double get partialShare {
    final double above =
        ((fraction - _mostlyThreshold) / (1 - _mostlyThreshold)).clamp(
          0.0,
          1.0,
        );
    return 0.3 + 0.6 * above;
  }

  static const int _phraseLimit = 2;
  static const double _mostlyThreshold = 2 / 3;

  @override
  bool operator ==(Object other) =>
      other is PantryMatch &&
      other.needed == needed &&
      other.have == have &&
      other.missing.length == missing.length;

  @override
  int get hashCode => Object.hash(needed, have, missing.length);

  @override
  String toString() => 'PantryMatch($have/$needed)';
}
