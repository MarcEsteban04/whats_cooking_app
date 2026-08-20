import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// One reason a meal's score moved.
///
/// Kept as a list on each candidate rather than folded into a single number,
/// because a score nobody can explain is a score nobody can debug — and because
/// the result screen can say *"Filipino is one of your favourites"* only if
/// something remembered why.
@immutable
class ScoreReason {
  const ScoreReason({required this.label, required this.points});

  /// Written for a person, in case it reaches one. It does: the result screen
  /// shows the largest positive reason under the meal.
  final String label;

  /// How many points this added. Negative is a penalty.
  final double points;
}

/// A meal, its score, and why.
@immutable
class ScoredMeal {
  const ScoredMeal({
    required this.meal,
    required this.score,
    required this.weight,
    this.reasons = const <ScoreReason>[],
  });

  final Meal meal;

  /// The total, in points. Roughly -60 to +90 in practice.
  final double score;

  /// Relative likelihood of being picked. Never zero — see [MealScorer].
  final double weight;

  final List<ScoreReason> reasons;

  /// The reason worth showing, or null when nothing notable happened.
  ///
  /// The largest *positive* one. A result screen exists to make somebody feel
  /// good about a decision, and "we picked this despite you eating it on
  /// Tuesday" is true and is not that.
  ScoreReason? get highlight {
    ScoreReason? best;
    for (final ScoreReason reason in reasons) {
      if (reason.points > 0 && (best == null || reason.points > best.points)) {
        best = reason;
      }
    }
    return best;
  }
}

/// What each signal is worth (Sprint 33).
///
/// The table from docs/project_dev.md, as **data rather than constants** —
/// docs/ARCHITECTURE.md §5.1: "Scoring weights are stored as data, not
/// constants, so they can be moved to a remote config later without touching
/// the algorithm." Nothing in [MealScorer] hard-codes a number; changing the
/// balance of the engine means passing a different one of these.
@immutable
class ScoreWeights {
  const ScoreWeights({
    this.preferenceMatch = 30,
    this.budgetMatch = 20,
    this.ingredientMatch = 20,
    this.partnerCompatibility = 25,
    this.favouriteMeal = 15,
    this.cuisineVariety = 10,
    this.cookingTimeMatch = 10,
    this.recentMeal = -15,
    this.temperature = 25,
  });

  /// The meal's cuisine is one the household said it likes.
  final double preferenceMatch;

  /// It comes in under the budget, per head.
  final double budgetMatch;

  /// **Not yet applied.** Needs a pantry to match against, which is Sprint 50.
  ///
  /// Present so the table is complete and the gap is explicit: a weight that is
  /// simply missing reads as an oversight, and the next person to open this file
  /// should be able to see what the engine does *not* know yet.
  final double ingredientMatch;

  /// **Not yet applied.** Needs a second person's preferences, which is couple
  /// mode (Sprint 41 onward).
  final double partnerCompatibility;

  /// It is one of theirs.
  final double favouriteMeal;

  /// A change from the cuisines of the last few meals.
  final double cuisineVariety;

  /// It fits the time they said they have.
  final double cookingTimeMatch;

  /// Eaten inside the soft window. Scaled by how recently.
  final double recentMeal;

  /// **How random the roulette is.** The one number that decides whether this is
  /// a roulette or a ranking.
  ///
  /// Score becomes likelihood through `exp(score / temperature)`, so this is the
  /// spread in points that makes a meal *e* times more likely. At 25, a
  /// favourite cuisine (+30) is about three times likelier than a neutral meal —
  /// felt, but nowhere near guaranteed.
  ///
  /// Lower it and the engine becomes a menu that always serves the optimum.
  /// Raise it and the scores stop mattering. Sprint 33's brief is explicit that
  /// "the engine should still preserve randomness", and this is the knob that
  /// keeps that promise honest rather than the absence of one.
  final double temperature;

  /// Disliked meals are worth **-100** in the roadmap's table, and are not here.
  ///
  /// They are excluded in the query instead (Sprint 25), which is strictly
  /// stronger: -100 makes a hidden meal very unlikely, and "very unlikely" over
  /// enough evenings means somebody eventually gets offered the food they told
  /// the app never to show them. US-B-07 promises *never*.
  static const double dislikedMealIsAnExclusionNotAPenalty = -100;
}

/// How long a meal stays out of the running after being eaten.
///
/// The window itself is a user preference
/// (`user_preferences.repetition_window_days`); the shape of the taper is ours.
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
  /// unset. Somebody cooking for one may genuinely not mind eating the same
  /// thing two nights running, and an app that overrode that would be arguing
  /// with them.
  factory RepetitionSettings.fromWindowDays(int? windowDays) {
    if (windowDays == null) {
      return const RepetitionSettings();
    }

    return RepetitionSettings(
      blockDays: windowDays,
      // The soft window scales with the hard one rather than being a second
      // question. Somebody who says "three days" means "and I would rather not
      // have it next week either" — not "and after 72 hours it is exactly as
      // good as anything else".
      penaltyDays: windowDays == 0 ? 0 : windowDays * 3,
    );
  }

  /// Eaten inside this many days: **not offered at all**.
  ///
  /// The one hard exclusion the scorer applies. docs/PRD.md is unambiguous —
  /// "yesterday's dinner, a disliked meal, or something over budget is a product
  /// bug" — and a penalty, however heavy, still produces yesterday's dinner
  /// sometimes.
  final int blockDays;

  /// Eaten inside this many days: offered, but scored down.
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
  /// night's dinner back before anyone has finished the leftovers.
  static const int defaultBlockDays = 2;

  /// Two weeks of taper past the block.
  static const int defaultPenaltyDays = 14;

  static const int defaultCuisineLookback = 3;
}

/// One meal the household has eaten, as the scorer wants it.
///
/// Passed in rather than fetched, so this whole file stays pure Dart with no
/// Flutter and no Supabase — the placement docs/ARCHITECTURE.md §5.1 specifies
/// for the engine, and the reason its behaviour can be reasoned about without a
/// device or a clock.
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

/// Everything the scorer knows about this household.
@immutable
class ScoringContext {
  const ScoringContext({
    this.favouriteCuisines = const <Cuisine>{},
    this.favouriteMealIds = const <String>{},
    this.recent = const <RecentMeal>[],
    this.budgetPerHead,
    this.maxCookingTimeMinutes,
    this.settings = const RepetitionSettings(),
    this.weights = const ScoreWeights(),
  });

  /// Cuisines the household said it likes. A *preference*, weighted — never a
  /// filter. As a filter it would silently hide nine cuisines from somebody who
  /// once tapped "Italian".
  final Set<Cuisine> favouriteCuisines;

  final Set<String> favouriteMealIds;

  /// Newest first.
  final List<RecentMeal> recent;

  /// Pesos a head. Null when they have not said.
  final int? budgetPerHead;

  final int? maxCookingTimeMinutes;

  final RepetitionSettings settings;
  final ScoreWeights weights;
}

/// What came out of a scoring pass.
@immutable
class ScoringOutcome {
  const ScoringOutcome({required this.candidates, required this.blocked});

  /// What may be offered, scored and weighted, highest score first.
  final List<ScoredMeal> candidates;

  /// How many were excluded for having been eaten too recently.
  ///
  /// Reported rather than dropped silently, because it is the difference between
  /// "nothing matches your filters" and "you have eaten everything that matches
  /// your filters" — two sentences with two different fixes.
  final int blocked;
}

/// The weighted recommendation engine (Sprint 33).
///
/// Supersedes Sprint 32's `RepetitionRule`, which weighted three repetition
/// signals multiplicatively. This is the same idea generalised to the table in
/// docs/project_dev.md and made **additive**, because the roadmap's model is
/// points and because points compose: six signals multiplying each other is a
/// number nobody can predict, and six adding up is one anybody can read off the
/// reasons list.
///
/// **Score is not order.** Points decide *likelihood*, not rank:
/// `weight = exp(score / temperature)`, then a weighted draw. That is what keeps
/// Sprint 33's own instruction — "the engine should still preserve randomness" —
/// from being a comment rather than a property. A meal with the best score is
/// more likely and never certain, and the temperature is the single number that
/// says how much more likely.
///
/// **What is not in here, and why.**
///
/// * *Disliked meals (-100)* are excluded in the query instead (Sprint 25).
///   Strictly stronger than a penalty: -100 makes a hidden meal very unlikely,
///   and "very unlikely" over enough evenings is a meal somebody told us never to
///   show them. See [ScoreWeights].
/// * *Ingredient match (+20)* needs a pantry. Sprint 50.
/// * *Partner compatibility (+25)* needs a second person's preferences. Couple
///   mode, Sprint 41 onward.
///
/// Both absent weights are declared on [ScoreWeights] anyway, so the gap is a
/// stated fact rather than something a reader has to notice.
abstract final class MealScorer {
  /// Scores [pool] against [context].
  ///
  /// Pure: same inputs, same outputs, no clock and no I/O. The caller works out
  /// how many days ago each meal was eaten, which is what keeps this testable
  /// without a fake clock.
  static ScoringOutcome score({
    required List<Meal> pool,
    required ScoringContext context,
  }) {
    final ScoreWeights weights = context.weights;
    final RepetitionSettings settings = context.settings;

    final Map<String, int> lastEatenDaysAgo = <String, int>{};
    for (final RecentMeal entry in context.recent) {
      // The most recent occurrence wins. A meal eaten on Monday and again on
      // Thursday is three days stale, not seven.
      final int? existing = lastEatenDaysAgo[entry.mealId];
      if (existing == null || entry.daysAgo < existing) {
        lastEatenDaysAgo[entry.mealId] = entry.daysAgo;
      }
    }

    final Set<Cuisine> recentCuisines = <Cuisine>{
      for (final RecentMeal entry in context.recent.take(
        settings.cuisineLookback,
      ))
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

      final List<ScoreReason> reasons = <ScoreReason>[];

      // --- Preference match ---------------------------------------------------
      if (context.favouriteCuisines.contains(meal.cuisine)) {
        reasons.add(
          ScoreReason(
            label: '${meal.cuisine.label} is one of your favourites',
            points: weights.preferenceMatch,
          ),
        );
      }

      // --- Favourite meal -----------------------------------------------------
      if (context.favouriteMealIds.contains(meal.id)) {
        reasons.add(
          ScoreReason(
            label: 'You saved this one',
            points: weights.favouriteMeal,
          ),
        );
      }

      // --- Budget -------------------------------------------------------------
      //
      // Scaled by how far under, not a flat bonus for squeaking in. A meal at
      // half the budget is a better answer to "we have ₱200" than one at ₱199,
      // and a household watching what it spends can feel the difference.
      if (context.budgetPerHead case final int budget when budget > 0) {
        final double headroom = (budget - meal.costPerServing) / budget;
        if (headroom >= 0) {
          reasons.add(
            ScoreReason(
              label: headroom >= 0.4 ? 'Well under budget' : 'Within budget',
              points: weights.budgetMatch * _ramp(headroom),
            ),
          );
        }
        // Nothing for going over. A meal over budget should not be here at all —
        // the budget is a hard filter (`SpinFilters`) — so if one arrives, it is
        // because the reader has no budget filter set, and penalising it against
        // a number they did not ask us to enforce would be inventing a rule.
      }

      // --- Cooking time -------------------------------------------------------
      if (context.maxCookingTimeMinutes case final int limit when limit > 0) {
        final double headroom = (limit - meal.cookingTimeMinutes) / limit;
        if (headroom >= 0) {
          reasons.add(
            ScoreReason(
              label: headroom >= 0.4
                  ? 'Quicker than you asked'
                  : 'Fits your time',
              points: weights.cookingTimeMatch * _ramp(headroom),
            ),
          );
        }
      }

      // --- Cuisine variety ----------------------------------------------------
      //
      // The signal that actually stops the app feeling repetitive. Sixty meals
      // across twelve cuisines will happily serve Filipino food five nights
      // running, and each individual suggestion was perfectly good.
      if (recentCuisines.isNotEmpty) {
        if (recentCuisines.contains(meal.cuisine)) {
          reasons.add(
            ScoreReason(
              label: '${meal.cuisine.label} again',
              points: -weights.cuisineVariety,
            ),
          );
        } else {
          reasons.add(
            ScoreReason(
              label: 'A change from ${recentCuisines.first.label}',
              points: weights.cuisineVariety,
            ),
          );
        }
      }

      // --- Recency ------------------------------------------------------------
      if (daysAgo == null) {
        // Novelty is folded into the recency signal rather than being a weight of
        // its own: "never eaten" is simply the far end of "not eaten lately", and
        // two knobs for one axis is two things to keep in agreement.
        reasons.add(
          ScoreReason(
            label: 'You have not had this yet',
            points: -weights.recentMeal / 2,
          ),
        );
      } else if (daysAgo < settings.penaltyDays) {
        // Linear taper: just past the block window it takes nearly the whole
        // penalty, at the far edge almost none. Linear rather than curved because
        // nobody can justify the curve, and a straight line is honest about being
        // a guess.
        final double staleness =
            1 -
            (daysAgo - settings.blockDays) /
                max(1, settings.penaltyDays - settings.blockDays);

        reasons.add(
          ScoreReason(
            label: daysAgo == 0
                ? 'Eaten today'
                : 'Eaten ${daysAgo == 1 ? 'yesterday' : '$daysAgo days ago'}',
            points: weights.recentMeal * staleness.clamp(0.0, 1.0),
          ),
        );
      }

      final double total = reasons.fold<double>(
        0,
        (double sum, ScoreReason reason) => sum + reason.points,
      );

      candidates.add(
        ScoredMeal(
          meal: meal,
          score: total,
          weight: _weightFor(total, weights.temperature),
          reasons: reasons,
        ),
      );
    }

    // Best first. Not because the order decides anything — the draw is weighted,
    // not ranked — but because a caller inspecting this list wants to see what
    // the engine liked, and because the reel reads better leading with a plausible
    // card than with whatever came back first alphabetically.
    candidates.sort((ScoredMeal a, ScoredMeal b) => b.score.compareTo(a.score));

    return ScoringOutcome(candidates: candidates, blocked: blocked);
  }

  /// Picks one, respecting the weights.
  ///
  /// The standard cumulative walk: sum the weights, roll inside the sum, take the
  /// first candidate whose running total passes the roll. A flat pick would throw
  /// away every signal above.
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
    // is empty — which is handled. Guarded anyway, because a division by a sum is
    // the kind of thing that becomes possible three sprints later.
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

  /// Turns a score into a likelihood.
  ///
  /// `exp(score / temperature)`, clamped. Exponential rather than linear because
  /// linear cannot express "much more likely" without letting a good score become
  /// a certainty: with `weight = 100 + score`, thirty points is a 1.3× edge, which
  /// nobody would ever notice. Exponentially, thirty points is about 3×, which is
  /// felt across an evening and still loses two times in three.
  ///
  /// Floored so nothing is unreachable, and capped so one runaway score cannot
  /// swallow the whole draw and turn the roulette into an answer.
  static double _weightFor(double score, double temperature) {
    if (temperature <= 0) {
      // A temperature of zero would mean "always the best meal", which is a
      // ranking. Treated as flat instead: refusing to divide by zero by picking
      // the *other* extreme is the safer of the two failures.
      return 1;
    }
    return exp(score / temperature).clamp(_minimumWeight, _maximumWeight);
  }

  /// Two percent of a neutral meal's odds: rare enough to feel like variety,
  /// possible enough that nothing is excluded by arithmetic rather than by a rule.
  static const double _minimumWeight = 0.02;

  /// Twenty times. Past this the draw stops being a draw.
  static const double _maximumWeight = 20;

  /// Eases a 0–1 headroom so that "just inside" earns much less than "comfortably
  /// inside", without a cliff between them.
  static double _ramp(double headroom) => 0.4 + 0.6 * headroom.clamp(0.0, 1.0);
}
