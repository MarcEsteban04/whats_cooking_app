import 'dart:async';
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
import 'package:whats_cooking/features/ai/domain/entities/assistant_choice.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant_filters.dart';
import 'package:whats_cooking/features/restaurants/domain/usecases/restaurant_scorer.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_visits.dart';
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
    this.isAwaitingAssistant = false,
    this.chosenByAssistant = false,
  });

  final Restaurant place;

  /// Everything eligible, for the reel to flick through — so what flashes past is
  /// somewhere we could actually have ended up.
  final List<Restaurant> pool;

  /// Why this one, in a phrase, or null when there is nothing worth saying.
  final String? reason;

  /// True while the assistant is still deciding whether to improve on this pick
  /// (Sprint 50).
  ///
  /// **The state is settled anyway**, exactly as it is for the meal roulette: the
  /// engine's pick is emitted immediately so the reel can start rolling with a
  /// real winner planted at its landing slot. The assistant is an *upgrade* that
  /// may or may not arrive, not a thing the spin waits on.
  final bool isAwaitingAssistant;

  /// Whether the place here came from the assistant rather than the weighted draw.
  final bool chosenByAssistant;

  RestaurantSpinSettled copyWith({
    Restaurant? place,
    String? reason,
    bool? isAwaitingAssistant,
    bool? chosenByAssistant,
  }) {
    return RestaurantSpinSettled(
      place: place ?? this.place,
      pool: pool,
      reason: reason ?? this.reason,
      isAwaitingAssistant: isAwaitingAssistant ?? this.isAwaitingAssistant,
      chosenByAssistant: chosenByAssistant ?? this.chosenByAssistant,
    );
  }
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

  /// Set once the assistant has been rate-limited, so the rest of the session
  /// stops asking. Mirrors the meal roulette, including the reasoning: skipping
  /// the assistant on Try Again instead would make the *second* spin worse than
  /// the first on every evening, to solve a problem that only happens on a heavy
  /// one.
  bool _assistantRestedForSession = false;

  /// Set once the reel has stopped on this spin's answer. See [lockIn].
  bool _isLockedIn = false;

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

      // Hoisted out of the scoring context (Sprint 50), because the assistant
      // wants the same history the scorer does — and fetching it twice for one
      // spin would be a second read of the same rows.
      final List<RecentVisit> recent = await _recentVisits();

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
          recent: recent,
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

      // A fresh spin can be changed again, whatever the last one committed to.
      _isLockedIn = false;

      final bool willAsk = _shouldAskAssistant(outcome.candidates);

      state = RestaurantSpinSettled(
        place: scored.restaurant,
        pool: outcome.candidates
            .map((ScoredRestaurant candidate) => candidate.restaurant)
            .toList(growable: false),
        reason: scored.highlight?.label,
        isAwaitingAssistant: willAsk,
      );

      if (willAsk) {
        // Not awaited. The spin is already settled and the reel is already
        // rolling; this either improves the answer before the reveal or it does
        // not, and either way nothing waited on it.
        // The names of the last few places, resolved here because this is the
        // only scope holding both the visits and the list they point at — a
        // `RecentVisit` carries an id and a cuisine, not a name.
        final Map<String, String> nameOf = <String, String>{
          for (final Restaurant place in all) place.id: place.name,
        };

        unawaited(
          _askAssistant(outcome.candidates, scored, <String>[
            for (final RecentVisit visit in recent.take(_recentNamesForPrompt))
              if (nameOf[visit.restaurantId] case final String name) name,
          ]),
        );
      }
    } on Object catch (error, stackTrace) {
      state = RestaurantSpinFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Whether to ask the assistant to improve on the draw (Sprint 50).
  ///
  /// The meal roulette got this at Sprint 47c and the night out did not, which
  /// made "the AI decides" half true — and eating out is the decision where a
  /// model has *more* to add, not less: the shortlist cannot see that you were at
  /// the ramen place on Friday and have been eating Japanese all month, and the
  /// reason under the answer is the whole product.
  ///
  /// Not with one candidate: choosing between one option is a round trip and a
  /// bill to be told the only answer. And not at all once the hour's rate limit
  /// has been hit — see [_assistantRestedForSession].
  bool _shouldAskAssistant(List<ScoredRestaurant> candidates) =>
      candidates.length > 1 && !_assistantRestedForSession;

  /// The screen has committed to what is on the reel — no more swapping.
  ///
  /// Mirrors `SpinController.lockIn`, including the reason: a wheel that stops on
  /// one place and hands over another is broken whatever the second answer was
  /// worth.
  void lockIn() {
    _isLockedIn = true;

    if (state case final RestaurantSpinSettled current
        when current.isAwaitingAssistant) {
      state = current.copyWith(isAwaitingAssistant: false);
    }
  }

  /// Asks the assistant to pick from the shortlist, and takes its answer if it
  /// arrives in time (Sprint 50).
  ///
  /// **The engine's pick is already on screen and already planted in the reel**, so
  /// this is strictly an upgrade path — the same three outcomes as the meal spin:
  /// a different place before the reel stops, the same place with a better reason,
  /// or nothing and the flag clears.
  Future<void> _askAssistant(
    List<ScoredRestaurant> candidates,
    ScoredRestaurant drawn,
    List<String> beenToRecently,
  ) async {
    final List<ScoredRestaurant> shortlist = candidates
        .take(_shortlistSize)
        .toList(growable: false);

    AssistantChoice? choice;
    try {
      choice = await ref.read(assistantRepositoryProvider).choose(
        options: <ChoiceOption>[
          for (final ScoredRestaurant candidate in shortlist)
            ChoiceOption(
              id: candidate.restaurant.id,
              name: candidate.restaurant.name,
              detail: _describePlace(candidate.restaurant),
            ),
        ],
        context: _assistantContext(beenToRecently),
        timeout: _assistantBudget,
      );
    } on RateLimitException {
      // The rest of the hour would fail the same way, so stop asking rather than
      // spending a round trip per spin to be told again.
      _assistantRestedForSession = true;
      AppLog.info(
        'Assistant rate-limited — the engine is choosing for the rest of the '
        'session.',
        name: 'restaurant-spin',
      );
    }

    // The spin may have been left, restarted, or accepted while this was in
    // flight. Anything other than the state this call was started for is a state
    // this answer is no longer about.
    // Locked in means the reel has stopped and the reader has seen where. The
    // answer goes, reason included — it was written about a different place.
    if (_isLockedIn) {
      if (state case final RestaurantSpinSettled current
          when current.isAwaitingAssistant) {
        state = current.copyWith(isAwaitingAssistant: false);
      }
      return;
    }

    if (state case final RestaurantSpinSettled current
        when current.place.id == drawn.restaurant.id &&
            current.isAwaitingAssistant) {
      final AssistantChoice? answered = choice;
      if (answered == null) {
        state = current.copyWith(isAwaitingAssistant: false);
        return;
      }

      final ScoredRestaurant? chosen = shortlist
          .where(
            (ScoredRestaurant candidate) =>
                candidate.restaurant.id == answered.id,
          )
          .firstOrNull;

      if (chosen == null) {
        state = current.copyWith(isAwaitingAssistant: false);
        return;
      }

      // The session's exclusions follow the place that is actually offered, or
      // Try Again could bring it straight back round.
      _seenThisSession
        ..remove(drawn.restaurant.id)
        ..add(chosen.restaurant.id);

      state = current.copyWith(
        place: chosen.restaurant,
        reason: answered.reason,
        isAwaitingAssistant: false,
        chosenByAssistant: true,
      );
    }
  }

  /// One line the model can reason over.
  String _describePlace(Restaurant place) => <String>[
    place.cuisine.label,
    '₱${place.costPerHead.round()} a head',
    place.proximity.label.toLowerCase(),
    if (place.delivers) 'delivers',
  ].join(', ');

  /// What the assistant is told, for a choice rather than a conversation.
  ///
  /// Deliberately smaller than the chat screen's context, for the same reason the
  /// meal spin's is: the shortlist already encodes the budget, the distance limit
  /// and the repetition window — every option in it passed all of them — so
  /// repeating those would be tokens spent restating a filter that has run. What
  /// the model cannot see from the list is where this household has been lately,
  /// so that is what it gets.
  Map<String, Object?> _assistantContext(List<String> beenToRecently) {
    return <String, Object?>{
      if (beenToRecently.isNotEmpty)
        'been_to_recently': beenToRecently.join(', '),
      'deciding_for': 'tonight, eating out',
    };
  }

  /// Records the decision and ends the session.
  Future<AppException?> accept(Restaurant place) async {
    try {
      await ref.read(restaurantHistoryRepositoryProvider).record(place);

      // The history just changed, and two screens read it: "Where we have been"
      // and Home's settled panel (Sprint 55). Without this, deciding to eat out
      // leaves Home still asking the question it has just been answered — the
      // exact bug the settled panel exists to fix, reintroduced on the other
      // half of the app.
      ref.invalidate(restaurantVisitsProvider);

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

  /// How many of the scored places the assistant is shown (Sprint 50).
  ///
  /// The same twelve the meal roulette uses, and for the same reason: an index
  /// between 1 and 12 is a number every model gets right, and a longer list buys
  /// nothing once the scorer has already ranked it.
  static const int _shortlistSize = 12;

  /// How long the assistant gets before the engine's pick simply stands.
  static const Duration _assistantBudget = Duration(seconds: 4);

  /// How many recent places go into the prompt. Five nights out is a month here.
  static const int _recentNamesForPrompt = 5;
}
