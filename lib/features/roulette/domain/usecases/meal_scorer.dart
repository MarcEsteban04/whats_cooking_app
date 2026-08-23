import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';

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
    this.favouriteMeal = 15,
    this.cuisineVariety = 10,
    this.cookingTimeMatch = 10,
    this.recentMeal = -15,
    this.moodMatch = 35,
    this.ourOwnMeal = 20,
    this.temperature = 25,
  });

  /// The meal's cuisine is one the household said it likes.
  final double preferenceMatch;

  /// It comes in under the budget, per head.
  final double budgetMatch;

  /// The ingredients are already in the kitchen (Sprint 41).
  ///
  /// Declared since Sprint 33 and unapplied until the pantry existed. It is applied
  /// now, and **only ever upward**: a full match earns the whole twenty, a partial
  /// one earns a share of it, and a poor one earns nothing at all.
  ///
  /// **There is no penalty, and that is the important half.** A pantry is optional,
  /// partial and always out of date — nobody logs the last two eggs. Marking a meal
  /// down because we were not told about the chicken would punish the reader for
  /// the app's ignorance, and the first thing they would notice is the roulette
  /// getting worse the moment they started using the fridge. A bonus for what we
  /// know is honest; a penalty for what we do not is not.
  final double ingredientMatch;

  /// `partnerCompatibility` (+25) is **gone**, not pending.
  ///
  /// It waited for a second person's preferences to reconcile. There is no second
  /// person's preferences: one phone, one account, two people who agree out loud
  /// (docs/USER_FLOWS.md §14). The two things that would have fed it — dietary needs
  /// and avoided foods — are handled the way that actually matters, as hard
  /// exclusions on every spin rather than as points in an average. A score reading
  /// "87% compatible" that then serves somebody fish is worse than no score.
  ///
  /// Recorded here rather than deleted silently, because a weight vanishing from a
  /// table reads as an oversight.
  static const double partnerCompatibilityWasCutAtSprint37 = 25;

  /// It is one of theirs.
  final double favouriteMeal;

  /// A change from the cuisines of the last few meals.
  final double cuisineVariety;

  /// It fits the time they said they have.
  final double cookingTimeMatch;

  /// Eaten inside the soft window. Scaled by how recently.
  final double recentMeal;

  /// We wrote it ourselves (Sprint 37).
  ///
  /// Twenty, between a favourite cuisine and a saved meal, and the reasoning is
  /// about **what writing a meal down means**. Nobody types out five steps and an
  /// ingredient list for food they are indifferent to. A meal in our own library is
  /// a meal we like *and* know how to cook — which is a stronger signal than a
  /// cuisine tapped once during onboarding, and weaker than a specific meal saved
  /// on purpose.
  ///
  /// This is why the catalogue can stay without swamping the library. Sixty seeded
  /// meals against a handful of ours would otherwise win on volume alone, and the
  /// app would spend months feeling like somebody else's recipe book.
  ///
  /// Stacks with [favouriteMeal] deliberately: a meal we wrote *and* saved is the
  /// best evidence in the whole table, and it should read that way.
  ///
  /// Not in docs/ARCHITECTURE.md §5.2's table, which predates the rescope.
  final double ourOwnMeal;

  /// It suits the mood asked for tonight (Sprint 36).
  ///
  /// **The heaviest single signal, above even a favourite cuisine at 30**, and
  /// the reasoning is about what kind of statement each one is. A favourite
  /// cuisine is a standing fact the household mentioned once; a mood is a request
  /// made thirty seconds ago about this evening. When the two disagree — somebody
  /// who loves Italian asking for something light — the fresher and more specific
  /// answer should win, or the mood row is decoration.
  ///
  /// Applied in both directions: the same figure is subtracted from a meal the
  /// mood argues against. That symmetry is what makes a mood legible in one spin.
  /// Promoting three `healthy` meals out of sixty barely moves a weighted draw;
  /// pushing the deep-fried pork down at the same time does.
  ///
  /// Not in docs/ARCHITECTURE.md §5.2's table, which predates the mood feature.
  /// Recorded here rather than added silently.
  final double moodMatch;

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
    this.mood,
    this.pantry = const <String, PantryMatch>{},
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

  /// What was asked for tonight, or null (Sprint 36).
  final Mood? mood;

  /// How much of each meal the kitchen already covers, by meal id (Sprint 41).
  ///
  /// Empty when the pantry is empty, when there is no backend, or when the match
  /// could not be computed — all three of which mean the same thing to the scorer,
  /// which is *no information*. Absent is not zero: a meal missing from this map is
  /// scored as though the pantry had never been mentioned.
  final Map<String, PantryMatch> pantry;

  /// The temperature this pass runs at.
  ///
  /// [Mood.surpriseMe] multiplies it, which flattens the weighted draw toward
  /// genuine chance. Resolved here rather than inside the scoring loop so there is
  /// exactly one place the engine's randomness is decided.
  double get temperature =>
      weights.temperature * (mood?.temperatureMultiplier ?? 1);
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
/// * *Ingredient match (+20)* needs a pantry. Sprint 41.
/// * *Partner compatibility (+25)* is **cut**, not pending — see [ScoreWeights].
///
/// The absent weight is declared on [ScoreWeights] anyway, so the gap is a stated
/// fact rather than something a reader has to notice.
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

      // --- Already in the kitchen ---------------------------------------------
      //
      // Upward only. See `ScoreWeights.ingredientMatch`: a pantry is partial and
      // always a little out of date, so a bonus for what we know is honest and a
      // penalty for what we do not would punish the reader for the app's
      // ignorance — and would make the roulette visibly worse the moment they
      // started keeping a fridge list.
      if (context.pantry[meal.id] case final PantryMatch match) {
        if (match.isComplete) {
          reasons.add(
            ScoreReason(
              label: 'You have everything for this',
              points: weights.ingredientMatch,
            ),
          );
        } else if (match.isMostlyIn) {
          reasons.add(
            ScoreReason(
              // Names what is short when it is one or two things, because
              // "everything but the bay leaves" is a reason to cook and "67%
              // available" is a spreadsheet.
              label: match.shortfallPhrase == null
                  ? 'Most of it is in the kitchen'
                  : 'You have ${match.shortfallPhrase}',
              // Scaled across the band above the threshold, so a meal missing one
              // thing clearly outranks one missing three — see
              // `PantryMatch.partialShare` for why the generic ramp was the wrong
              // scale here.
              points: weights.ingredientMatch * match.partialShare,
            ),
          );
        }
      }

      // --- Ours ---------------------------------------------------------------
      //
      // `isPublic` rather than a household comparison: RLS returns only "public,
      // or my household's", so anything not public is ours by construction.
      if (!meal.isPublic) {
        reasons.add(
          ScoreReason(label: 'One of yours', points: weights.ourOwnMeal),
        );
      }

      // --- Mood ---------------------------------------------------------------
      //
      // Both directions, deliberately. See `ScoreWeights.moodMatch`: promoting a
      // handful of tagged meals barely moves a weighted draw over sixty, and
      // pushing the contradiction down at the same time is what makes a mood
      // readable in one spin instead of ten.
      if (context.mood case final Mood mood) {
        if (mood.favoursAnyOf(meal.tags)) {
          reasons.add(
            ScoreReason(
              // Written as the mood's own claim about the meal rather than as
              // "matches your mood", because this line can end up under the
              // result as the reason it was chosen.
              label: switch (mood) {
                Mood.comfort => 'Proper comfort food',
                Mood.craving => 'Exactly what you were after',
                Mood.healthy => 'One of the healthier ones',
                Mood.spicy => 'This one has heat',
                Mood.junk => 'Gloriously bad for you',
                Mood.light => 'Light on its feet',
                Mood.highProtein => 'Plenty of protein',
                Mood.cheap => 'Cheap as anything',
                Mood.surpriseMe => 'Something different',
              },
              points: weights.moodMatch,
            ),
          );
        } else if (mood.discouragesAnyOf(meal.tags)) {
          reasons.add(
            ScoreReason(
              label: 'Not quite the mood',
              points: -weights.moodMatch,
            ),
          );
        }

        // Calories, where the meal states them. A third of the mood's weight:
        // it is a supporting signal, and the number is an estimate on a recipe
        // somebody typed rather than a measurement.
        if (mood.calories != CaloriePreference.none &&
            (meal.calories ?? 0) > 0) {
          final double perHead = meal.calories! / max(1, meal.servings);
          final double lightness =
              ((_calorieMidpoint - perHead) / _calorieMidpoint).clamp(
                -1.0,
                1.0,
              );
          final double direction = mood.calories == CaloriePreference.fewer
              ? lightness
              : -lightness;

          if (direction.abs() > 0.15) {
            reasons.add(
              ScoreReason(
                label: direction > 0
                    ? (mood.calories == CaloriePreference.fewer
                          ? 'Lighter than most'
                          : 'Substantial')
                    : 'Not what you asked for',
                points: weights.moodMatch / 3 * direction,
              ),
            );
          }
        }

        // Cheap as its own signal, because somebody asking for cheap has not
        // necessarily set a budget for the existing one to measure against.
        if (mood.favoursLowCost) {
          final double thrift =
              ((_cheapPerHead - meal.costPerServing) / _cheapPerHead).clamp(
                -1.0,
                1.0,
              );
          if (thrift.abs() > 0.15) {
            reasons.add(
              ScoreReason(
                label: thrift > 0
                    ? 'Barely costs anything'
                    : 'On the dear side',
                points: weights.moodMatch / 3 * thrift,
              ),
            );
          }
        }

        // Novelty, for the mood that exists to widen the draw. Additive on top
        // of the recency signal above rather than replacing it: that one asks
        // "how stale is this", and this one asks "has it ever been on the table".
        if (mood.favoursNovelty && daysAgo == null) {
          reasons.add(
            ScoreReason(
              label: 'You have never had this',
              points: weights.moodMatch / 2,
            ),
          );
        }
      }

      final double total = reasons.fold<double>(
        0,
        (double sum, ScoreReason reason) => sum + reason.points,
      );

      candidates.add(
        ScoredMeal(
          meal: meal,
          score: total,
          weight: _weightFor(total, context.temperature),
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
  /// Calories a head where a dish stops being light and starts being a meal.
  ///
  /// Six hundred. Roughly a third of a day for one adult, which is what the
  /// seeded catalogue clusters around for a dinner — so it sits near the middle
  /// of the real distribution rather than at a nutritional ideal, and the signal
  /// separates the pool instead of condemning most of it.
  static const double _calorieMidpoint = 600;

  /// Pesos a head where a meal stops feeling cheap.
  ///
  /// A hundred, matching the "under ₱100" figure the Meals dashboard already
  /// counts by — so the number the app shows and the number the engine believes
  /// are the same one.
  static const double _cheapPerHead = 100;

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
