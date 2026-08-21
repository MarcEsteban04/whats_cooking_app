import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/roulette/domain/usecases/spin_weighting.dart';

/// One reason a place's score moved.
@immutable
class RestaurantReason {
  const RestaurantReason({required this.label, required this.points});

  final String label;
  final double points;
}

/// A place, its score, and why.
@immutable
class ScoredRestaurant {
  const ScoredRestaurant({
    required this.restaurant,
    required this.score,
    required this.weight,
    this.reasons = const <RestaurantReason>[],
  });

  final Restaurant restaurant;
  final double score;
  final double weight;
  final List<RestaurantReason> reasons;

  /// The largest *positive* reason, for the result screen.
  ///
  /// Positive only, for the reason `ScoredMeal.highlight` gives: a result screen
  /// exists to make somebody feel good about a decision, and "we picked this
  /// despite you going on Tuesday" is true and is not that.
  RestaurantReason? get highlight {
    RestaurantReason? best;
    for (final RestaurantReason reason in reasons) {
      if (reason.points > 0 && (best == null || reason.points > best.points)) {
        best = reason;
      }
    }
    return best;
  }
}

/// What each signal is worth when picking a place (Sprint 46).
///
/// **Its own table, not the meal scorer's.** Four of the meal weights are
/// meaningless here — cooking time, the pantry match, "we wrote it ourselves", and
/// dietary needs, which are a hard filter for both — and two weights here are
/// meaningless there. A single table with half its rows always unused would be one
/// function pretending to be two. What *is* shared is the arithmetic, in
/// [SpinWeighting].
///
/// The numbers deliberately echo the meal table where the signal is the same, so
/// the two roulettes feel like one product: a favourite cuisine is worth 30 in both,
/// and the mood still outranks it.
@immutable
class RestaurantWeights {
  const RestaurantWeights({
    this.moodMatch = 35,
    this.preferenceMatch = 30,
    this.budgetMatch = 20,
    this.favourite = 25,
    this.closeBy = 15,
    this.cuisineVariety = 10,
    this.recentVisit = -20,
    this.temperature = 25,
  });

  /// The place suits the mood asked for. Matches the meal table's 35, and outranks
  /// a standing cuisine preference for the same reason: a mood is a request made
  /// thirty seconds ago.
  final double moodMatch;

  /// Its cuisine is one the household said it likes.
  final double preferenceMatch;

  /// It comes in under the budget, a head. Scaled by how far under.
  final double budgetMatch;

  /// **Starred, and worth more than a favourite meal is (15).**
  ///
  /// A saved meal is one somebody tapped a heart on while browsing. A starred
  /// restaurant is a place two people have been to, liked, and bothered to mark —
  /// with a note about what to order. The evidence is much stronger, and there are
  /// twenty candidates rather than sixty, so the signal has to be loud enough to be
  /// felt in a smaller pool.
  final double favourite;

  /// It is walkable.
  ///
  /// Only rewarded, never penalised. "Worth the trip" is a category somebody chose
  /// on purpose — marking those down would slowly hide the best places on the list,
  /// which is the opposite of what a list of favourites is for. Proximity as a
  /// *filter* is available for the nights when it matters.
  final double closeBy;

  /// A change from the cuisines of the last few nights out.
  final double cuisineVariety;

  /// Went recently. **Heavier than a meal's −15**, and the reason is money: eating
  /// at the same place twice in a week is a bigger thing to be nudged away from
  /// than cooking the same dinner twice, because it also costs four times as much.
  final double recentVisit;

  /// How random this roulette is. The same 25 the meal engine uses, so both feel
  /// equally like chance.
  final double temperature;
}

/// One night out the household has had.
@immutable
class RecentVisit {
  const RecentVisit({
    required this.restaurantId,
    required this.cuisine,
    required this.daysAgo,
  });

  final String restaurantId;
  final Cuisine cuisine;

  /// Whole days between then and now. Zero is today.
  final int daysAgo;
}

/// How long a place stays out of the running after a visit.
///
/// **Its own window, separate from the meal one**, and this resolved
/// docs/DATABASE.md §9's open question: one setting does not cover both. A
/// household happy to cook adobo twice in a week is not necessarily happy to eat
/// out twice in a week, and the money is the reason. The default here is longer.
@immutable
class VisitSettings {
  const VisitSettings({
    this.blockDays = defaultBlockDays,
    this.penaltyDays = defaultPenaltyDays,
    this.cuisineLookback = defaultCuisineLookback,
  });

  /// Visited inside this many days: **not offered at all**.
  final int blockDays;

  /// Visited inside this many days: offered, but scored down.
  final int penaltyDays;

  /// How many recent nights out count toward cuisine variety.
  final int cuisineLookback;

  /// A week. Going back to the same place inside seven days is a thing to have to
  /// ask for rather than be offered — where a meal's block is two days, because
  /// leftovers and a weekly shop make repeating a dinner normal.
  static const int defaultBlockDays = 7;

  /// A month of taper past the block.
  static const int defaultPenaltyDays = 30;

  static const int defaultCuisineLookback = 3;
}

/// Everything the restaurant scorer knows.
@immutable
class RestaurantScoringContext {
  const RestaurantScoringContext({
    this.favouriteCuisines = const <Cuisine>{},
    this.recent = const <RecentVisit>[],
    this.budgetPerHead,
    this.mood,
    this.settings = const VisitSettings(),
    this.weights = const RestaurantWeights(),
  });

  final Set<Cuisine> favouriteCuisines;

  /// Newest first.
  final List<RecentVisit> recent;

  /// Pesos a head. Null when they have not said.
  final int? budgetPerHead;

  final Mood? mood;

  final VisitSettings settings;
  final RestaurantWeights weights;

  /// The temperature this pass runs at.
  ///
  /// [Mood.surpriseMe] multiplies it here exactly as it does for meals, so the one
  /// mood whose whole job is widening the draw behaves the same in both roulettes.
  double get temperature =>
      weights.temperature * (mood?.temperatureMultiplier ?? 1);
}

/// What came out of a scoring pass.
@immutable
class RestaurantOutcome {
  const RestaurantOutcome({required this.candidates, required this.blocked});

  /// What may be offered, highest score first.
  final List<ScoredRestaurant> candidates;

  /// How many were excluded for being too recent.
  ///
  /// Reported rather than dropped silently, because it is the difference between
  /// "nothing matches" and "you have been to all of these lately" — two sentences
  /// with two different fixes.
  final int blocked;
}

/// The roulette for the nights nobody is cooking (Sprint 46).
///
/// Shares its arithmetic with the meal engine through [SpinWeighting] and nothing
/// else: see [RestaurantWeights] for why the tables are separate.
abstract final class RestaurantScorer {
  /// Scores [pool] against [context].
  ///
  /// Pure: same inputs, same outputs, no clock and no I/O. The caller works out how
  /// many days ago each visit was, which is what keeps this testable without a fake
  /// clock — the same rule `MealScorer` follows.
  static RestaurantOutcome score({
    required List<Restaurant> pool,
    required RestaurantScoringContext context,
  }) {
    final RestaurantWeights weights = context.weights;
    final VisitSettings settings = context.settings;

    final Map<String, int> lastVisitDaysAgo = <String, int>{};
    for (final RecentVisit visit in context.recent) {
      final int? existing = lastVisitDaysAgo[visit.restaurantId];
      if (existing == null || visit.daysAgo < existing) {
        lastVisitDaysAgo[visit.restaurantId] = visit.daysAgo;
      }
    }

    final Set<Cuisine> recentCuisines = <Cuisine>{
      for (final RecentVisit visit in context.recent.take(
        settings.cuisineLookback,
      ))
        visit.cuisine,
    };

    final List<ScoredRestaurant> candidates = <ScoredRestaurant>[];
    int blocked = 0;

    for (final Restaurant place in pool) {
      final int? daysAgo = lastVisitDaysAgo[place.id];

      if (daysAgo != null && daysAgo < settings.blockDays) {
        blocked++;
        continue;
      }

      final List<RestaurantReason> reasons = <RestaurantReason>[];

      // --- Mood ---------------------------------------------------------------
      //
      // Both directions, as for meals. The tags are the same vocabulary, which is
      // the whole reason `restaurants.tags` exists.
      if (context.mood case final Mood mood) {
        if (mood.favoursAnyOf(place.tags)) {
          reasons.add(
            RestaurantReason(
              label: 'Exactly the mood',
              points: weights.moodMatch,
            ),
          );
        } else if (mood.discouragesAnyOf(place.tags)) {
          reasons.add(
            RestaurantReason(
              label: 'Not quite the mood',
              points: -weights.moodMatch,
            ),
          );
        }
      }

      // --- Favourite ----------------------------------------------------------
      if (place.isFavorite) {
        reasons.add(
          RestaurantReason(
            label: 'One of your places',
            points: weights.favourite,
          ),
        );
      }

      // --- Preference ---------------------------------------------------------
      if (context.favouriteCuisines.contains(place.cuisine)) {
        reasons.add(
          RestaurantReason(
            label: '${place.cuisine.label} is one of your favourites',
            points: weights.preferenceMatch,
          ),
        );
      }

      // --- Budget -------------------------------------------------------------
      //
      // Scaled by how far under, like meals: a place at half the budget is a
      // better answer to "we have ₱500" than one at ₱499.
      if (context.budgetPerHead case final int budget when budget > 0) {
        final double headroom = (budget - place.costPerHead) / budget;
        if (headroom >= 0) {
          reasons.add(
            RestaurantReason(
              label: headroom >= 0.4 ? 'Well under budget' : 'Within budget',
              points: weights.budgetMatch * SpinWeighting.ramp(headroom),
            ),
          );
        }
        // Nothing for going over: the budget is a hard filter, so a place that is
        // here at all is one the reader did not ask us to enforce a limit on.
      }

      // --- Close by -----------------------------------------------------------
      //
      // Rewarded, never penalised. See `RestaurantWeights.closeBy`.
      if (place.proximity == Proximity.walk) {
        reasons.add(
          RestaurantReason(
            label: 'You can walk there',
            points: weights.closeBy,
          ),
        );
      }

      // --- Cuisine variety ----------------------------------------------------
      if (recentCuisines.isNotEmpty) {
        if (recentCuisines.contains(place.cuisine)) {
          reasons.add(
            RestaurantReason(
              label: '${place.cuisine.label} again',
              points: -weights.cuisineVariety,
            ),
          );
        } else {
          reasons.add(
            RestaurantReason(
              label: 'A change from ${recentCuisines.first.label}',
              points: weights.cuisineVariety,
            ),
          );
        }
      }

      // --- Recency ------------------------------------------------------------
      if (daysAgo == null) {
        // Never been. Folded into the recency signal rather than given its own
        // weight, for the reason the meal engine gives: "never" is the far end of
        // "not lately", and two knobs for one axis is two things to keep in
        // agreement.
        reasons.add(
          RestaurantReason(
            label: 'You have not been here yet',
            points: -weights.recentVisit / 2,
          ),
        );
      } else if (daysAgo < settings.penaltyDays) {
        final double staleness =
            1 -
            (daysAgo - settings.blockDays) /
                max(1, settings.penaltyDays - settings.blockDays);

        reasons.add(
          RestaurantReason(
            label: daysAgo == 0
                ? 'You went today'
                : 'You went ${daysAgo == 1 ? 'yesterday' : '$daysAgo days ago'}',
            points: weights.recentVisit * staleness.clamp(0.0, 1.0),
          ),
        );
      }

      final double total = reasons.fold<double>(
        0,
        (double sum, RestaurantReason reason) => sum + reason.points,
      );

      candidates.add(
        ScoredRestaurant(
          restaurant: place,
          score: total,
          weight: SpinWeighting.weightFor(total, context.temperature),
          reasons: reasons,
        ),
      );
    }

    candidates.sort(
      (ScoredRestaurant a, ScoredRestaurant b) => b.score.compareTo(a.score),
    );

    return RestaurantOutcome(candidates: candidates, blocked: blocked);
  }

  /// Draws one, weighted.
  static ScoredRestaurant? pick(
    List<ScoredRestaurant> candidates,
    Random random,
  ) {
    return SpinWeighting.draw<ScoredRestaurant>(
      candidates,
      (ScoredRestaurant candidate) => candidate.weight,
      random,
    );
  }
}
