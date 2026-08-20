import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// One reason a meal's chances went up or down.
///
/// Kept as a list on each candidate rather than folded into a single number,
/// because a score nobody can explain is a score nobody can debug — and because
/// the result screen can say *"you have not had this in three weeks"* only if
/// something remembered why.
///
/// Sprint 33 adds the rest of the table (preference match, budget match, partner
/// compatibility). This is the shape those arrive in.
@immutable
class ScoreReason {
  const ScoreReason({required this.label, required this.delta});

  /// Written for a person, in case it reaches one.
  final String label;

  /// How much this moved the weight. Negative is a penalty.
  final double delta;
}

/// A meal with its chances, and why.
@immutable
class ScoredMeal {
  const ScoredMeal({
    required this.meal,
    required this.weight,
    this.reasons = const <ScoreReason>[],
  });

  final Meal meal;

  /// Relative likelihood of being picked. Never zero — see [RepetitionRule].
  final double weight;

  final List<ScoreReason> reasons;

  /// The reason worth showing, or null when nothing notable happened.
  ///
  /// The largest *positive* one: a result screen exists to make somebody feel
  /// good about a decision, and "we picked this despite you eating it on Tuesday"
  /// is not that.
  ScoreReason? get highlight {
    ScoreReason? best;
    for (final ScoreReason reason in reasons) {
      if (reason.delta > 0 && (best == null || reason.delta > best.delta)) {
        best = reason;
      }
    }
    return best;
  }
}

/// How long a meal stays out of the running (Sprint 32).
///
/// Stored as data rather than baked into the algorithm, which is what
/// docs/ARCHITECTURE.md §5.1 asks for: "Scoring weights are stored as data, not
/// constants, so they can be moved to a remote config later without touching the
/// algorithm." The window itself is a user preference
/// (`user_preferences.repetition_window_days`); the weights are still ours.
@immutable
class RepetitionSettings {
  const RepetitionSettings({
    this.blockDays = defaultBlockDays,
    this.penaltyDays = defaultPenaltyDays,
    this.cuisineLookback = defaultCuisineLookback,
  });

  /// Built from what the household chose, falling back to the defaults.
  ///
  /// A window of 0 is honoured as *no exclusion at all* rather than treated as
  /// unset. Somebody cooking for one may genuinely not mind eating the same thing
  /// two nights running, and an app that overrode that would be arguing with them.
  factory RepetitionSettings.fromWindowDays(int? windowDays) {
    if (windowDays == null) {
      return const RepetitionSettings();
    }

    return RepetitionSettings(
      blockDays: windowDays,
      // The soft window scales with the hard one rather than being a second
      // question. Somebody who says "three days" means "and I would rather not
      // have it next week either" — they do not mean "and after 72 hours it is
      // exactly as good as anything else".
      penaltyDays: windowDays == 0 ? 0 : windowDays * 3,
    );
  }

  /// Eaten inside this many days: **not offered at all**.
  ///
  /// A hard exclusion rather than a penalty, and the only one in this class.
  /// docs/PRD.md is unambiguous — "yesterday's dinner, a disliked meal, or
  /// something over budget is a product bug" — and a penalty, however heavy,
  /// still produces yesterday's dinner sometimes.
  final int blockDays;

  /// Eaten inside this many days: offered, but less often.
  ///
  /// The taper is what stops the catalogue feeling like a rota. Past the block
  /// window a meal comes back gradually rather than snapping to full odds
  /// overnight.
  final int penaltyDays;

  /// How many recent meals count toward cuisine variety.
  ///
  /// Deliberately short. Three Filipino dinners in a row is a pattern worth
  /// breaking; three in the last fortnight, in a Filipino household, is Tuesday.
  final int cuisineLookback;

  /// Two days, so last night and the night before are both out.
  ///
  /// Not one: a household that eats late has "yesterday" and "this morning" land
  /// on the same calendar day often enough that a 24-hour window lets last
  /// night's dinner back in before anyone has finished the leftovers.
  static const int defaultBlockDays = 2;

  /// Two weeks of taper past the block.
  static const int defaultPenaltyDays = 14;

  static const int defaultCuisineLookback = 3;
}

/// What the roulette knows about what has been eaten.
///
/// Passed in rather than fetched, so this whole file stays pure Dart with no
/// Flutter and no Supabase — the placement docs/ARCHITECTURE.md §5.1 specifies
/// for the engine, and the reason its behaviour can be reasoned about without a
/// device.
@immutable
class RecentMeal {
  const RecentMeal({
    required this.mealId,
    required this.cuisine,
    required this.daysAgo,
  });

  final String mealId;
  final Cuisine cuisine;

  /// Whole days between then and now. Zero is today.
  final int daysAgo;
}

/// The outcome of applying repetition rules to a pool.
@immutable
class RepetitionOutcome {
  const RepetitionOutcome({required this.candidates, required this.blocked});

  /// What may still be offered, weighted.
  final List<ScoredMeal> candidates;

  /// How many were excluded for having been eaten too recently.
  ///
  /// Reported rather than discarded silently, because it is the difference
  /// between "nothing matches your filters" and "you have eaten everything that
  /// matches your filters" — two sentences with two different fixes.
  final int blocked;
}

/// Repetition prevention (Sprint 32).
///
/// Three signals, in order of severity:
///
/// 1. **Eaten very recently — excluded.** Not a penalty. PRD principle: last
///    night's dinner appearing is a product bug, and a heavy penalty still
///    produces it sometimes.
/// 2. **Eaten fairly recently — down-weighted**, tapering back to normal odds
///    across [RepetitionSettings.penaltyDays]. A cliff would make the catalogue
///    feel like a rota; a taper makes it feel like variety.
/// 3. **Same cuisine as the last few meals — down-weighted.** The one that
///    actually stops the app feeling repetitive: sixty meals with twelve
///    cuisines will happily serve Filipino food five nights running, and each
///    individual meal was a perfectly good suggestion.
///
/// **Randomness is preserved**, which Sprint 33 will say again about the full
/// engine. Weights are multipliers with a floor, never zero: a penalised meal is
/// less likely, not forbidden, because an engine that only ever offers the
/// optimal answer is a menu, not a roulette — and it stops feeling like a
/// decision the household made.
abstract final class RepetitionRule {
  /// Scores [pool] against [recent].
  ///
  /// Pure: same inputs, same outputs, no clock and no I/O. The caller works out
  /// how many days ago each meal was eaten, which is what keeps this testable
  /// without a fake clock.
  static RepetitionOutcome apply({
    required List<Meal> pool,
    required List<RecentMeal> recent,
    RepetitionSettings settings = const RepetitionSettings(),
  }) {
    final Map<String, int> lastEatenDaysAgo = <String, int>{};
    for (final RecentMeal entry in recent) {
      // The most recent occurrence wins. A meal eaten on Monday and again on
      // Thursday is three days stale, not seven.
      final int? existing = lastEatenDaysAgo[entry.mealId];
      if (existing == null || entry.daysAgo < existing) {
        lastEatenDaysAgo[entry.mealId] = entry.daysAgo;
      }
    }

    final Set<Cuisine> recentCuisines = <Cuisine>{
      for (final RecentMeal entry in recent.take(settings.cuisineLookback))
        entry.cuisine,
    };

    final List<ScoredMeal> candidates = <ScoredMeal>[];
    int blocked = 0;

    for (final Meal meal in pool) {
      final int? daysAgo = lastEatenDaysAgo[meal.id];

      if (daysAgo != null && daysAgo < settings.blockDays) {
        blocked++;
        continue;
      }

      double weight = 1;
      final List<ScoreReason> reasons = <ScoreReason>[];

      if (daysAgo != null && daysAgo < settings.penaltyDays) {
        // Linear taper: just past the block window it is heavily penalised, at
        // the far edge it is barely touched. Linear rather than curved because
        // nobody can justify the curve, and a straight line is honest about
        // being a guess.
        final double staleness =
            1 -
            (daysAgo - settings.blockDays) /
                (settings.penaltyDays - settings.blockDays);
        final double factor = 1 - _recentPenalty * staleness.clamp(0.0, 1.0);

        weight *= factor;
        reasons.add(
          ScoreReason(
            label: daysAgo == 0
                ? 'Eaten today'
                : 'Eaten ${daysAgo == 1 ? 'yesterday' : '$daysAgo days ago'}',
            delta: factor - 1,
          ),
        );
      } else if (daysAgo == null) {
        reasons.add(
          const ScoreReason(label: 'Not had this yet', delta: _noveltyBonus),
        );
        weight *= 1 + _noveltyBonus;
      } else {
        reasons.add(
          const ScoreReason(
            label: 'Not had this in a while',
            delta: _noveltyBonus / 2,
          ),
        );
        weight *= 1 + _noveltyBonus / 2;
      }

      if (recentCuisines.contains(meal.cuisine)) {
        weight *= 1 - _cuisinePenalty;
        reasons.add(
          ScoreReason(
            label: '${meal.cuisine.label} again',
            delta: -_cuisinePenalty,
          ),
        );
      } else if (recentCuisines.isNotEmpty) {
        weight *= 1 + _cuisineBonus;
        reasons.add(
          ScoreReason(
            label: 'A change from ${recentCuisines.first.label}',
            delta: _cuisineBonus,
          ),
        );
      }

      candidates.add(
        ScoredMeal(
          // Floored, never zero. A meal that can never be picked is excluded in
          // all but name, and the exclusions here are meant to be the one rule
          // above that says so explicitly.
          meal: meal,
          weight: max(weight, _minimumWeight),
          reasons: reasons,
        ),
      );
    }

    return RepetitionOutcome(candidates: candidates, blocked: blocked);
  }

  /// Picks one, respecting the weights.
  ///
  /// A flat pick over a weighted list would throw away everything above. This is
  /// the standard cumulative-weight walk: sum the weights, roll inside the sum,
  /// and take the first candidate whose running total passes the roll.
  ///
  /// [random] is injected so a caller can make a spin reproducible without this
  /// file knowing what a test is.
  static ScoredMeal? pick(List<ScoredMeal> candidates, Random random) {
    if (candidates.isEmpty) {
      return null;
    }

    final double total = candidates.fold<double>(
      0,
      (double sum, ScoredMeal candidate) => sum + candidate.weight,
    );

    // Every weight is floored above zero, so this cannot be zero unless the list
    // is empty — which is handled. Guarded anyway, because a division by a sum
    // is the kind of thing that becomes possible three sprints later.
    if (total <= 0) {
      return candidates[random.nextInt(candidates.length)];
    }

    double roll = random.nextDouble() * total;
    for (final ScoredMeal candidate in candidates) {
      roll -= candidate.weight;
      if (roll <= 0) {
        return candidate;
      }
    }

    // Floating-point drift only. The last candidate is the right answer.
    return candidates.last;
  }

  /// How much a meal eaten one day past the block window loses.
  ///
  /// 0.85 rather than 0.99: the point of the taper is that a meal eaten two days
  /// ago is *nearly* excluded, and 15% of normal odds reads as "unlucky" rather
  /// than "broken" when it does come up.
  static const double _recentPenalty = 0.85;

  /// What a meal never eaten gains.
  ///
  /// Modest. Novelty is worth something, but a household with fifty untried
  /// meals should not find the ten it likes buried.
  static const double _noveltyBonus = 0.35;

  /// What sharing a cuisine with the last few meals costs.
  static const double _cuisinePenalty = 0.55;

  /// What breaking a cuisine run gains.
  static const double _cuisineBonus = 0.25;

  /// The floor. Two percent of normal odds — rare enough to feel like variety,
  /// possible enough that the pool never empties on a technicality.
  static const double _minimumWeight = 0.02;
}
