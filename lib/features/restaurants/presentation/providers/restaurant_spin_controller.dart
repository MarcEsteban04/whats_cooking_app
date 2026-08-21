import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/analytics/analytics.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant_filters.dart';
import 'package:whats_cooking/features/restaurants/domain/usecases/restaurant_scorer.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';

part 'restaurant_spin_controller.g.dart';

/// Where a night out has got to.
///
/// Mirrors `SpinState` deliberately — a sealed state with genuinely distinct
/// outcomes rather than a bag of nullable fields, so a result card can never
/// render behind an error.
@immutable
sealed class RestaurantSpinState {
  const RestaurantSpinState();
}

class RestaurantSpinIdle extends RestaurantSpinState {
  const RestaurantSpinIdle();
}

class RestaurantSpinRunning extends RestaurantSpinState {
  const RestaurantSpinRunning();
}

/// A place was chosen.
class RestaurantSpinSettled extends RestaurantSpinState {
  const RestaurantSpinSettled({
    required this.place,
    required this.pool,
    this.reason,
  });

  final Restaurant place;

  /// Everything eligible, for the reel to flick through — so what flashes past is
  /// somewhere we could actually have ended up.
  final List<Restaurant> pool;

  /// Why this one, in a phrase, or null when there is nothing worth saying.
  final String? reason;
}

/// Nothing to offer, and which of the reasons it was.
class RestaurantSpinNoMatch extends RestaurantSpinState {
  const RestaurantSpinNoMatch({
    required this.filters,
    required this.blocking,
    required this.eligibleCount,
    required this.blockedByRecency,
    required this.seenThisSession,
    this.mostRelaxable,
    this.wouldOpen = 0,
  });

  final RestaurantFilters filters;

  /// The active constraints, worst first.
  final List<RestaurantConstraint> blocking;

  /// How many places existed before the filters were applied.
  final int eligibleCount;

  /// How many were ruled out for being visited too recently.
  final int blockedByRecency;

  /// How many this session has already offered and had turned down.
  final int seenThisSession;

  final RestaurantConstraint? mostRelaxable;
  final int wouldOpen;

  /// Nothing on the list at all.
  bool get isEmptyList => eligibleCount == 0 && seenThisSession == 0;

  /// Every place has been somewhere we went lately.
  bool get isAllTooRecent => blockedByRecency > 0;

  /// Everything eligible has been turned down this session.
  bool get isSessionExhausted => eligibleCount == 0 && seenThisSession > 0;

  /// The reader's own filters emptied it.
  bool get isFilteredOut =>
      blockedByRecency == 0 && eligibleCount > 0 && blocking.isNotEmpty;

  /// The sentence §7 asks for, or null when no filter is to blame.
  String? get blockingSentence {
    if (!isFilteredOut) {
      return null;
    }
    final String first = filters.describe(blocking.first);
    if (blocking.length == 1) {
      return 'Nothing $first.';
    }
    return 'Nothing $first that is also ${filters.describe(blocking[1])}.';
  }
}

class RestaurantSpinFailed extends RestaurantSpinState {
  const RestaurantSpinFailed(this.failure);

  final AppException failure;
}

/// The restaurant history backend.
@Riverpod(keepAlive: true)
RestaurantHistoryRepository restaurantHistoryRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: nights out will not be remembered.',
      name: 'restaurantHistoryRepository',
    );
    return InMemoryRestaurantHistoryRepository();
  }

  return SupabaseRestaurantHistoryRepository(ref.read(supabaseClientProvider));
}

/// What the night-out roulette will narrow by.
///
/// A per-spin scratchpad like `SpinFiltersController`, seeded from the profile's
/// budget once with `read` rather than `watch` so it never rebuilds and can never
/// lose an edit somebody has just made.
@Riverpod(keepAlive: true)
class RestaurantFiltersController extends _$RestaurantFiltersController {
  @override
  RestaurantFilters build() {
    final FoodPreferences? preferences = ref
        .read(profileControllerProvider)
        .value
        ?.preferences;

    // The household's meal budget as a *starting point*, not a rule. Eating out
    // costs more than cooking and everybody knows it, so this seeds generously
    // rather than pretending a ₱150 dinner budget is a restaurant budget — the
    // alternative is a first spin that finds nothing and a reader who concludes
    // the feature is broken.
    return RestaurantFilters(
      maxCostPerHead: preferences?.budget == null
          ? null
          : preferences!.budget! * _eatingOutMultiplier,
    );
  }

  void setBudget(int? pesosPerHead) => state = pesosPerHead == null
      ? state.copyWith(clearBudget: true)
      : state.copyWith(maxCostPerHead: pesosPerHead);

  void setDistance(Proximity? furthest) => state = furthest == null
      ? state.copyWith(clearDistance: true)
      : state.copyWith(maxDistance: furthest);

  void setMustDeliver(bool mustDeliver) =>
      state = state.copyWith(mustDeliver: mustDeliver);

  void toggleCuisine(Cuisine cuisine) {
    final Set<Cuisine> next = state.cuisines.toSet();
    if (!next.remove(cuisine)) {
      next.add(cuisine);
    }
    state = state.copyWith(cuisines: next);
  }

  /// Tapping the chosen mood again clears it.
  void setMood(Mood? mood) => state = mood == null || state.mood == mood
      ? state.copyWith(clearMood: true)
      : state.copyWith(mood: mood);

  void replace(RestaurantFilters filters) => state = filters;

  void clear() => state = state.cleared();

  /// Twice the cooking budget. Not a measured figure — a starting point chosen so
  /// the first spin finds something, and one the reader can move in a tap.
  static const int _eatingOutMultiplier = 2;
}

/// Drives the night-out roulette (Sprint 46).
///
/// The same shape as `SpinController`, and the resemblance is the point: one
/// interaction, two pools. What differs is only what the engine reads — see
/// `RestaurantWeights` for why the tables are separate even though the arithmetic
/// is shared.
///
/// `keepAlive`, because [_seenThisSession] *is* the session: losing it when the
/// screen closes would let Try Again offer the same place again.
@Riverpod(keepAlive: true)
class RestaurantSpinController extends _$RestaurantSpinController {
  final Set<String> _seenThisSession = <String>{};
  final Random _random = Random();

  int _spinsThisSession = 0;

  @override
  RestaurantSpinState build() => const RestaurantSpinIdle();

  int get spinsThisSession => _spinsThisSession;

  /// Picks a place.
  ///
  /// Nothing is thrown — a failed spin is a state, because the animation is already
  /// running by the time it happens and there is nowhere for an exception to go.
  Future<void> spin() async {
    state = const RestaurantSpinRunning();
    _spinsThisSession++;

    final Stopwatch elapsed = Stopwatch()..start();
    final Analytics analytics = ref.read(analyticsProvider);
    final RestaurantFilters filters = ref.read(
      restaurantFiltersControllerProvider,
    );

    analytics.record(
      SpinStarted(
        filtersApplied: filters.chosenCount,
        householdSize:
            ref
                .read(profileControllerProvider)
                .value
                ?.preferences
                .preferredServings ??
            0,
        spinCountThisSession: _spinsThisSession,
        mood: filters.mood?.value,
        // Which roulette. ARCHITECTURE §10 records why this matters: "we cooked"
        // and "we went out" are the two things this app most needs to be able to
        // tell apart, and without this field every figure blends them.
        surface: SpinSurface.eatingOut,
      ),
    );

    try {
      final List<Restaurant> all = await ref.read(
        restaurantsControllerProvider.future,
      );

      // The session's exclusions, applied in Dart. There is no query to push them
      // into — the whole list is one read — so this is the only place they can go.
      final List<Restaurant> eligible = <Restaurant>[
        for (final Restaurant place in all)
          if (!_seenThisSession.contains(place.id)) place,
      ];

      final List<Restaurant> matching = eligible
          .where(filters.allows)
          .toList(growable: false);

      if (matching.isEmpty) {
        state = _settleOnNothing(
          analytics,
          _noMatch(filters: filters, eligible: eligible),
        );
        return;
      }

      final RestaurantOutcome outcome = RestaurantScorer.score(
        pool: matching,
        context: RestaurantScoringContext(
          favouriteCuisines:
              ref
                  .read(profileControllerProvider)
                  .value
                  ?.preferences
                  .favouriteCuisines ??
              const <Cuisine>{},
          recent: await _recentVisits(),
          budgetPerHead: filters.maxCostPerHead,
          mood: filters.mood,
        ),
      );

      if (outcome.candidates.isEmpty) {
        state = _settleOnNothing(
          analytics,
          _noMatch(
            filters: filters,
            eligible: eligible,
            blockedByRecency: outcome.blocked,
          ),
        );
        return;
      }

      final ScoredRestaurant? scored = RestaurantScorer.pick(
        outcome.candidates,
        _random,
      );
      if (scored == null) {
        state = _settleOnNothing(
          analytics,
          _noMatch(
            filters: filters,
            eligible: eligible,
            blockedByRecency: outcome.blocked,
          ),
        );
        return;
      }

      _seenThisSession.add(scored.restaurant.id);

      analytics.record(
        SpinCompleted(
          mealId: scored.restaurant.id,
          score: scored.score,
          candidatePoolSize: outcome.candidates.length,
          latency: elapsed.elapsed,
          surface: SpinSurface.eatingOut,
        ),
      );

      state = RestaurantSpinSettled(
        place: scored.restaurant,
        pool: outcome.candidates
            .map((ScoredRestaurant candidate) => candidate.restaurant)
            .toList(growable: false),
        reason: scored.highlight?.label,
      );
    } on Object catch (error, stackTrace) {
      state = RestaurantSpinFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Records the decision and ends the session.
  Future<AppException?> accept(Restaurant place) async {
    try {
      await ref.read(restaurantHistoryRepositoryProvider).record(place);

      ref.read(analyticsProvider).mealAccepted(
        mealId: place.id,
        spinCount: _spinsThisSession,
        surface: SpinSurface.eatingOut,
      );

      _seenThisSession.clear();
      _spinsThisSession = 0;
      state = const RestaurantSpinIdle();
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Turns this place down and asks for another.
  void reject(Restaurant place) {
    ref.read(analyticsProvider).record(
      MealRejected(
        mealId: place.id,
        spinCount: _spinsThisSession,
        surface: SpinSurface.eatingOut,
      ),
    );
  }

  /// Forgets the session's exclusions without accepting anything.
  Future<void> startOver() {
    _seenThisSession.clear();
    return spin();
  }

  /// Drops one filter and spins again.
  Future<void> relaxAndSpin(RestaurantConstraint constraint) {
    ref
        .read(restaurantFiltersControllerProvider.notifier)
        .replace(ref.read(restaurantFiltersControllerProvider).without(constraint));
    return spin();
  }

  void reset() => state = const RestaurantSpinIdle();

  /// Records a no-match and hands the state straight back.
  ///
  /// A pass-through, like the meal controller's, so the three places that produce
  /// this state cannot set it without recording it.
  RestaurantSpinNoMatch _settleOnNothing(
    Analytics analytics,
    RestaurantSpinNoMatch nothing,
  ) {
    analytics.record(
      NoMatchFound(
        blockingConstraint: nothing.blocking.firstOrNull?.name,
        eligibleCount: nothing.eligibleCount,
        blockedByRepetition: nothing.blockedByRecency,
        surface: SpinSurface.eatingOut,
      ),
    );
    return nothing;
  }

  /// Works out what to say when nothing matched.
  ///
  /// The same counting the meal controller does: for each active filter, how many
  /// places would come back if *that one* were dropped. The largest wins, and it is
  /// a real number the screen can quote.
  RestaurantSpinNoMatch _noMatch({
    required RestaurantFilters filters,
    required List<Restaurant> eligible,
    int blockedByRecency = 0,
  }) {
    final Map<RestaurantConstraint, int> opens =
        <RestaurantConstraint, int>{
          for (final RestaurantConstraint constraint in filters.active)
            constraint: eligible
                .where(filters.without(constraint).allows)
                .length,
        };

    final List<RestaurantConstraint> blocking = filters.active.toList()
      ..sort(
        (RestaurantConstraint a, RestaurantConstraint b) =>
            (opens[b] ?? -1).compareTo(opens[a] ?? -1),
      );

    RestaurantConstraint? best;
    int bestCount = 0;
    for (final MapEntry<RestaurantConstraint, int> entry in opens.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }

    return RestaurantSpinNoMatch(
      filters: filters,
      blocking: blocking,
      eligibleCount: eligible.length,
      blockedByRecency: blockedByRecency,
      seenThisSession: _seenThisSession.length,
      // Only offered when dropping it actually helps: a relaxation that opens
      // nothing spends the reader's tap and returns them to the same screen.
      mostRelaxable: bestCount > 0 ? best : null,
      wouldOpen: bestCount,
    );
  }

  /// Recent nights out, as the scorer wants them.
  ///
  /// The days-ago arithmetic happens here rather than in the scorer, which is what
  /// keeps that file a pure function with no clock in it. Midnight to midnight, for
  /// the reason the meal engine gives: a Friday night out that ran past midnight
  /// was Friday.
  ///
  /// Best effort. A history that failed to load costs a penalty, and failing the
  /// spin over it would cost dinner.
  Future<List<RecentVisit>> _recentVisits() async {
    try {
      final List<RestaurantVisit> visits = await ref
          .read(restaurantHistoryRepositoryProvider)
          .recent(limit: _historyLookback);

      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      return <RecentVisit>[
        for (final RestaurantVisit visit in visits)
          RecentVisit(
            restaurantId: visit.restaurantId,
            cuisine: visit.cuisine,
            daysAgo: today
                .difference(
                  DateTime(
                    visit.eatenAt.year,
                    visit.eatenAt.month,
                    visit.eatenAt.day,
                  ),
                )
                .inDays,
          ),
      ];
    } on Object {
      return const <RecentVisit>[];
    }
  }

  /// How far back the recency penalty looks.
  ///
  /// Forty nights out. Comfortably past the thirty-day taper, and far more than a
  /// household produces in a month.
  static const int _historyLookback = 40;
}
