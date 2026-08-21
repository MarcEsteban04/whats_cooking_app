import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/analytics/analytics.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_choice.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/disliked_ingredients_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';
import 'package:whats_cooking/features/roulette/domain/usecases/meal_scorer.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_filters_controller.dart';

part 'spin_controller.g.dart';

/// Where a spin has got to.
///
/// A sealed state rather than a bag of nullable fields. The spin has genuinely
/// distinct outcomes — a meal, nothing to offer, a failure — and each one is a
/// different screen. Nullable fields would let two of them be true at once, and
/// that disagreement shows up as a result card behind an error.
@immutable
sealed class SpinState {
  const SpinState();
}

/// Nothing has been asked for yet.
class SpinIdle extends SpinState {
  const SpinIdle();
}

/// A pool is being fetched.
///
/// The animation starts before this finishes — see `SpinScreen`. The reveal
/// waits for the pick, not the other way round.
class SpinRunning extends SpinState {
  const SpinRunning();
}

/// A meal was chosen.
class SpinSettled extends SpinState {
  const SpinSettled({
    required this.meal,
    required this.pool,
    this.reason,
    this.isAwaitingAssistant = false,
    this.chosenByAssistant = false,
  });

  /// True while the assistant is still deciding whether to improve on this pick
  /// (Sprint 47c).
  ///
  /// **The state is settled anyway**, and that is the design: the engine's pick is
  /// emitted immediately so the reel can start rolling with a real winner planted
  /// at its landing slot. The assistant is an *upgrade* that may or may not
  /// arrive, not a thing the spin waits on. This flag exists only so the screen
  /// knows it may hold the reveal for a moment longer.
  final bool isAwaitingAssistant;

  /// Whether the meal here came from the assistant rather than the weighted draw.
  final bool chosenByAssistant;

  final Meal meal;

  /// Everything that was eligible, for the cycling animation to flick through.
  ///
  /// The animation needs *plausible* meals rather than the winner repeated, and
  /// this is the pool it was drawn from — so what flashes past is food the user
  /// could actually have got.
  final List<Meal> pool;

  /// Why this one, in a phrase, or null when there is nothing worth saying.
  ///
  /// design_ui §13 leaves room for a context line on the result — its own
  /// example is *"Loved by both of you"*. This is the scored version:
  /// *"Filipino is one of your favourites"*, *"Well under budget"*, *"You have
  /// not had this yet"*. It exists because a scored engine that cannot say why
  /// it chose something is indistinguishable from a random one, which throws
  /// away the point of scoring it.
  ///
  /// Only ever a *positive* reason. "We picked this despite you eating it on
  /// Tuesday" is true and is not what a result screen is for.
  final String? reason;

  SpinSettled copyWith({
    Meal? meal,
    String? reason,
    bool? isAwaitingAssistant,
    bool? chosenByAssistant,
  }) {
    return SpinSettled(
      meal: meal ?? this.meal,
      pool: pool,
      reason: reason ?? this.reason,
      isAwaitingAssistant: isAwaitingAssistant ?? this.isAwaitingAssistant,
      chosenByAssistant: chosenByAssistant ?? this.chosenByAssistant,
    );
  }
}

/// Nothing could be offered, and this says which of the two reasons it was.
///
/// docs/USER_FLOWS.md §7: "The no-match state is a designed screen, not an
/// error. It names the specific blocking constraint — *'Nothing under ₱150 that
/// also takes under 20 minutes'* — and offers the single filter whose relaxation
/// opens the most options. It is never an empty grey screen."
///
/// Everything that sentence needs is computed before this is constructed, which
/// is why the type is this wide. The screen renders the answer; it does not go
/// looking for it.
class SpinNoMatch extends SpinState {
  const SpinNoMatch({
    required this.filters,
    required this.blocking,
    required this.seenThisSession,
    required this.hiddenCount,
    required this.eligibleCount,
    this.mostRelaxable,
    this.wouldOpen = 0,
    this.blockedByRepetition = 0,
    this.blockedByIngredient = 0,
  });

  /// What was applied when nothing came back.
  final SpinFilters filters;

  /// The active constraints, worst first — the one costing the most meals leads,
  /// because that is the one the sentence should name first.
  final List<SpinConstraint> blocking;

  /// How many this session has already offered.
  final int seenThisSession;

  /// How many meals the reader has hidden.
  final int hiddenCount;

  /// How many meals were eligible before the reader's filters were applied.
  ///
  /// The number that tells the two failures apart: nothing eligible at all is a
  /// hiding or exhaustion problem, and plenty eligible with nothing matching is a
  /// filter problem.
  final int eligibleCount;

  /// The one filter to offer dropping, or null when no single drop helps.
  ///
  /// Never [SpinConstraint.dietary]. The app does not offer to relax that, ever
  /// (docs/PRD.md principle 3).
  final SpinConstraint? mostRelaxable;

  /// How many meals dropping [mostRelaxable] would offer.
  final int wouldOpen;

  /// How many matched everything but were eaten too recently (Sprint 32).
  ///
  /// Its own number rather than folded into the others, because it is the one
  /// emptiness with a good explanation: the filters were fine and the household
  /// has simply eaten all of it lately. "Nothing fits" would be a lie about
  /// that, and the fix is different — wait a day, or widen the window.
  final int blockedByRepetition;

  /// How many were ruled out for containing a food the household avoids
  /// (Sprint 35).
  ///
  /// Its own number for the same reason [blockedByRepetition] is: the fix is
  /// different from every other emptiness. Nothing needs relaxing and nothing
  /// needs waiting — somebody typed a food that turns out to be in most of what
  /// they can cook, and the honest thing is to say so and point at the list.
  final int blockedByIngredient;

  /// Whether the reader's own filters are what emptied the pool.
  bool get isFilteredOut =>
      blockedByRepetition == 0 &&
      blockedByIngredient == 0 &&
      eligibleCount > 0 &&
      blocking.isNotEmpty;

  /// Whether avoided foods are what emptied it.
  ///
  /// Checked before the filters, because it is the more specific answer: if a
  /// disliked ingredient took the last candidate, saying "nothing under ₱150"
  /// sends the reader to change a budget that was never the problem.
  bool get isAllAvoided => blockedByIngredient > 0 && eligibleCount == 0;

  /// Whether everything that matched had been eaten too recently.
  bool get isAllTooRecent => blockedByRepetition > 0;

  /// Whether the session's own exclusions are what emptied it.
  bool get isSessionExhausted => eligibleCount == 0 && seenThisSession > 0;

  /// The specific sentence §7 asks for, or null when there is no filter to blame.
  ///
  /// Built from the two worst offenders rather than all of them: "nothing under
  /// ₱150 that also takes under 20 minutes" is a sentence somebody reads, and the
  /// five-clause version is one they skip.
  String? get blockingSentence {
    if (!isFilteredOut) {
      return null;
    }

    final String first = filters.describe(blocking.first);
    if (blocking.length == 1) {
      return 'Nothing $first.';
    }
    return 'Nothing $first that is also '
        '${filters.describe(blocking[1])}.';
  }
}

/// The pool could not be read.
class SpinFailed extends SpinState {
  const SpinFailed(this.failure);

  final AppException failure;
}

/// Drives the roulette (docs/USER_FLOWS.md §7 — *this is the product*).
///
/// **Selection is scored, as of Sprint 33.** Favourite cuisines, saved meals,
/// how far under budget, how far inside the time limit, cuisine variety and
/// recency each contribute points; the points become likelihoods; a weighted
/// draw picks one. `MealScorer` holds the table and the reasoning — including
/// what is *not* in it yet, and why.
///
/// **Three layers of narrowing, and they differ in kind.** The dislikes and the
/// session's own exclusions go into the *query*, because those are promises
/// rather than choices and must not depend on client code running correctly. The
/// reader's *filters* are applied over the whole eligible pool, which is what
/// lets the no-match state say which one is costing them dinner. And
/// *repetition* is applied last, over what survived the filters, because there
/// is no point weighting meals the reader has already ruled out.

///
/// `keepAlive`, because [_seenThisSession] is the session. Losing it when the
/// spin screen closes would let Try Again offer the same meal again, which
/// US-B-04 calls broken and it is hard to disagree.
@Riverpod(keepAlive: true)
class SpinController extends _$SpinController {
  /// Everything offered since the last accepted meal.
  ///
  /// docs/USER_FLOWS.md §7: "Re-spins exclude prior results for the session."
  /// Cleared by [accept], because deciding ends the session — the next spin is a
  /// new question, and the meal you ate last night is exactly the kind of thing
  /// the recency penalty will handle properly in Sprint 30.
  final Set<String> _seenThisSession = <String>{};

  /// Not seeded from a clock or an id: nothing here needs to be reproducible,
  /// and a fixed seed would make every install spin the same sequence.
  final Random _random = Random();

  /// How many spins it has taken to get here (Sprint 34).
  ///
  /// Counted separately from [_seenThisSession] rather than read off its length,
  /// because the two answer different questions and diverge on purpose: "start
  /// again" empties the exclusions but does not undo the spins it took to get
  /// stuck, and a `spin_count` that walked backwards would make the funnel a
  /// fiction.
  int _spinsThisSession = 0;

  /// Set once the assistant has been rate-limited, so the rest of the session
  /// stops asking.
  ///
  /// Better than skipping the assistant on Try Again, which was the other way to
  /// keep the hourly budget from being burnt: that would have made the *second*
  /// spin worse than the first on every evening, to solve a problem that only
  /// happens on a heavy one.
  bool _assistantRestedForSession = false;

  /// Set once the reel has stopped on this spin's answer. See [lockIn].
  bool _isLockedIn = false;

  @override
  SpinState build() => const SpinIdle();

  int get seenThisSession => _seenThisSession.length;

  /// Spins since the last accepted meal. Feeds `meal_accepted.spin_count`.
  int get spinsThisSession => _spinsThisSession;

  /// Picks a meal.
  ///
  /// Returns immediately after setting [SpinRunning]; the screen animates while
  /// this works. Nothing is thrown — a failed spin is a state, because the
  /// animation is already running by the time it happens and there is nowhere
  /// for an exception to go.
  Future<void> spin() async {
    state = const SpinRunning();

    _spinsThisSession++;

    // Timed from here, so the measurement covers everything the reader is
    // actually waiting through: the dislikes, the query, the history, the
    // scoring and the draw. A stopwatch rather than two timestamps — it is
    // monotonic, and a latency that can come out negative is worse than none.
    final Stopwatch elapsed = Stopwatch()..start();
    final Analytics analytics = ref.read(analyticsProvider);

    analytics.record(
      SpinStarted(
        filtersApplied: ref.read(spinFiltersProvider).chosenCount,
        mood: ref.read(spinFiltersProvider).mood?.value,
        householdSize:
            ref
                .read(profileControllerProvider)
                .value
                ?.preferences
                .preferredServings ??
            0,
        spinCountThisSession: _spinsThisSession,
      ),
    );

    try {
      // Read rather than watched: a dislike toggled mid-spin should not restart
      // the pick. The next spin will see it.
      final Set<String> hidden = await ref.read(
        dislikesControllerProvider.future,
      );

      // Meals carrying a food this household avoids (Sprint 35). Read here with
      // the hidden set because it belongs in the same place: both are promises
      // rather than choices, and a promise applied client-side is one that
      // breaks the first time a filter is skipped.
      final Set<String> avoided = await ref.read(
        mealsBlockedByDislikesProvider.future,
      );

      final MealQuery query = MealQuery(
        // All three exclusions in one set, because the query does not care why a
        // meal is out — only that it must not come back. Applied on the server,
        // so the pool is right rather than filtered after the fact.
        excludedMealIds: <String>{
          ...hidden,
          ...avoided,
          ..._seenThisSession,
        },
      );

      final MealPage page = await ref
          .read(mealRepositoryProvider)
          .search(query: query, limit: kSpinPoolSize);

      final SpinFilters filters = ref.read(spinFiltersProvider);
      final List<Meal> eligible = page.meals;
      final List<Meal> matching = eligible
          .where(filters.allows)
          .toList(growable: false);

      if (matching.isEmpty) {
        state = _settleOnNothing(
          analytics,
          _noMatch(
            filters: filters,
            eligible: eligible,
            hiddenCount: hidden.length,
            blockedByIngredient: avoided.length,
          ),
        );
        return;
      }

      // Scoring (Sprint 33). Runs *after* the filters, because there is no point
      // scoring meals the reader has ruled out — and before the pick, because
      // the scores are what the pick is for.
      final ScoringOutcome scoring = MealScorer.score(
        pool: matching,
        context: await _scoringContext(filters),
      );

      if (scoring.candidates.isEmpty) {
        state = _settleOnNothing(
          analytics,
          _noMatch(
            filters: filters,
            eligible: eligible,
            hiddenCount: hidden.length,
            blockedByRepetition: scoring.blocked,
            blockedByIngredient: avoided.length,
          ),
        );
        return;
      }

      final ScoredMeal? scored = MealScorer.pick(scoring.candidates, _random);
      if (scored == null) {
        state = _settleOnNothing(
          analytics,
          _noMatch(
            filters: filters,
            eligible: eligible,
            hiddenCount: hidden.length,
            blockedByRepetition: scoring.blocked,
            blockedByIngredient: avoided.length,
          ),
        );
        return;
      }

      _seenThisSession.add(scored.meal.id);

      analytics.record(
        SpinCompleted(
          mealId: scored.meal.id,
          score: scored.score,
          candidatePoolSize: scoring.candidates.length,
          latency: elapsed.elapsed,
        ),
      );

      // A fresh spin can be changed again, whatever the last one committed to.
      _isLockedIn = false;

      final bool willAsk = _shouldAskAssistant(scoring.candidates);

      state = SpinSettled(
        meal: scored.meal,
        // The reel flicks through the scored pool, not the raw one, so what
        // flashes past is food that could actually have won — and in the order
        // the engine liked it.
        pool: scoring.candidates
            .map((ScoredMeal candidate) => candidate.meal)
            .toList(growable: false),
        reason: scored.highlight?.label,
        isAwaitingAssistant: willAsk,
      );

      if (willAsk) {
        // Not awaited. The spin is already settled and the reel is already
        // rolling; this either improves the answer before the reveal or it does
        // not, and either way nothing waited on it.
        unawaited(_askAssistant(scoring.candidates, scored));
      }
    } on Object catch (error, stackTrace) {
      state = SpinFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Whether to ask the assistant to improve on the draw (Sprint 47c).
  ///
  /// Not with one candidate: choosing between one option is a round trip and a
  /// bill to be told the only answer. And not at all once the hour's rate limit
  /// has been hit — see [_assistantRestedForSession].
  bool _shouldAskAssistant(List<ScoredMeal> candidates) =>
      candidates.length > 1 && !_assistantRestedForSession;

  /// The screen has committed to what is on the reel — no more swapping.
  ///
  /// **The reel stopping is a promise.** Before this existed, an assistant answer
  /// arriving after the wheel came to rest still replaced the meal, and the result
  /// screen showed something the reel had not landed on: it stopped on champorado
  /// and served arroz caldo. A slot machine that does that is broken, whatever the
  /// second answer was worth.
  ///
  /// So the screen calls this the moment the travel ends, and after it the
  /// assistant can only clear the waiting flag. Its window is now *before* the
  /// roll rather than after it — see `SpinScreen`, which spends the same second
  /// and a half where it can still change the answer.
  void lockIn() {
    _isLockedIn = true;

    if (state case final SpinSettled current when current.isAwaitingAssistant) {
      state = current.copyWith(isAwaitingAssistant: false);
    }
  }

  /// Asks the assistant to pick from the shortlist, and takes its answer if it
  /// arrives in time (Sprint 47c).
  ///
  /// **The engine's pick is already on screen and already planted in the reel**, so
  /// this is strictly an upgrade path. Three things can happen:
  ///
  /// * it answers with a different meal, and the state changes before the reel
  ///   stops — the screen re-plants, which is invisible because the landing slot
  ///   is twenty cards away;
  /// * it agrees, and only the reason changes to the better sentence;
  /// * it fails, times out, or is rate-limited, and the flag simply clears.
  ///
  /// In none of them does the spin get slower than the reel plus the screen's own
  /// short grace. That is the whole reason the deterministic pick goes first.
  Future<void> _askAssistant(
    List<ScoredMeal> candidates,
    ScoredMeal drawn,
  ) async {
    final List<ScoredMeal> shortlist = candidates
        .take(_shortlistSize)
        .toList(growable: false);

    AssistantChoice? choice;
    try {
      choice = await ref.read(assistantRepositoryProvider).choose(
        options: <ChoiceOption>[
          for (final ScoredMeal candidate in shortlist)
            ChoiceOption(
              id: candidate.meal.id,
              name: candidate.meal.name,
              detail: _describe(candidate.meal),
            ),
        ],
        context: _assistantContext(),
        timeout: _assistantBudget,
      );
    } on RateLimitException {
      // The rest of the hour would fail the same way, so stop asking rather than
      // spending a round trip per spin to be told again.
      _assistantRestedForSession = true;
      AppLog.info(
        'Assistant rate-limited — the engine is choosing for the rest of the '
        'session.',
        name: 'spin',
      );
    }

    // The spin may have been left, restarted, or accepted while this was in
    // flight. Anything other than the state this call was started for is a state
    // this answer is no longer about.
    // Locked in means the reel has already stopped on the engine's pick and the
    // reader has seen it. The answer is discarded whole — including its reason,
    // which was written about a different meal.
    if (_isLockedIn) {
      if (state case final SpinSettled current
          when current.isAwaitingAssistant) {
        state = current.copyWith(isAwaitingAssistant: false);
      }
      return;
    }

    if (state case final SpinSettled current
        when current.meal.id == drawn.meal.id &&
            current.isAwaitingAssistant) {
      // Promoted to a local so the closure below sees a non-nullable value.
      // `choice` is a mutable local that the analyzer cannot prove stays
      // assigned across a lambda, which is a fair thing for it to refuse.
      final AssistantChoice? answered = choice;
      if (answered == null) {
        state = current.copyWith(isAwaitingAssistant: false);
        return;
      }

      final ScoredMeal? chosen = shortlist
          .where((ScoredMeal candidate) => candidate.meal.id == answered.id)
          .firstOrNull;

      if (chosen == null) {
        state = current.copyWith(isAwaitingAssistant: false);
        return;
      }

      // The session's exclusions follow the meal that is actually offered, or
      // Try Again could bring it straight back round.
      _seenThisSession
        ..remove(drawn.meal.id)
        ..add(chosen.meal.id);

      state = current.copyWith(
        meal: chosen.meal,
        reason: answered.reason,
        isAwaitingAssistant: false,
        chosenByAssistant: true,
      );
    }
  }

  /// One line the model can reason over.
  String _describe(Meal meal) => <String>[
    meal.cuisine.label,
    '₱${meal.costPerServing.round()} a head',
    '${meal.cookingTimeMinutes} min',
    if (meal.tags.isNotEmpty) meal.tags.take(3).join('/'),
  ].join(', ');

  /// What the assistant is told, for a choice rather than a conversation.
  ///
  /// Deliberately smaller than the chat screen's context. The shortlist already
  /// encodes the budget, the time limit, the dietary needs and the repetition
  /// window — every option in it passed all of them — so repeating them would be
  /// tokens spent restating a filter that has already run.
  ///
  /// What the model cannot see from the list is what the household has eaten
  /// lately and **what needs using up**, so those are what it gets. The second one
  /// was missing until Sprint 50, and it is the line that most changes which of
  /// twelve perfectly valid meals gets picked — a model that knows there is fish
  /// to use tonight both chooses differently and has something worth saying about
  /// why.
  ///
  /// The whole kitchen is still left out. Twenty ingredient names on every spin is
  /// tokens spent on a pantry bonus the scorer has already applied; the urgent
  /// shelf is short by definition and is the part the score cannot express.
  Map<String, Object?> _assistantContext() {
    final List<MealHistoryEntry> history =
        ref.read(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

    final List<String> recent = <String>[
      for (final MealHistoryEntry entry in history.take(5))
        if (entry.meal?.name case final String name) name,
    ];

    final DateTime now = DateTime.now();
    final List<String> urgent = <String>[
      for (final PantryItem item
          in ref.read(pantryControllerProvider).value ?? const <PantryItem>[])
        if (item.statusAsOf(now).needsAttention) item.name,
    ];

    // What meal this actually is. It said 'tonight' regardless, so a breakfast
    // spin asked the model to choose dinner and then showed the answer under a
    // breakfast heading — the same mismatch the result screen's overline had.
    final Set<MealCategory> categories = ref
        .read(spinFiltersControllerProvider)
        .categories;

    return <String, Object?>{
      if (recent.isNotEmpty) 'eaten_recently': recent.join(', '),
      if (urgent.isNotEmpty)
        'going_off_soon': urgent.take(_urgentForPrompt).join(', '),
      'deciding_for': switch (categories.length) {
        // Nothing narrowed. "Tonight" is the honest default: it is the meal this
        // app was built for and the one somebody opens it at.
        0 => 'tonight',
        1 => categories.first.label.toLowerCase(),
        _ => categories
            .map((MealCategory category) => category.label.toLowerCase())
            .join(' or '),
      },
    };
  }

  /// A shelf, not an inventory. Past this, "soon" has stopped meaning anything.
  static const int _urgentForPrompt = 6;

  /// Records a no-match and hands the state straight back.
  ///
  /// Shaped as a pass-through so the three places that produce this state cannot
  /// set it without recording it. They are three genuinely different failures —
  /// the filters excluded everything, the repetition window did, or the weighted
  /// draw came back empty — and `no_match` is the event that tells them apart,
  /// which it cannot do if one of the three forgets to fire it.
  SpinNoMatch _settleOnNothing(Analytics analytics, SpinNoMatch nothing) {
    analytics.record(
      NoMatchFound(
        // The constraint's wire value rather than its label: `time` is a series
        // name that survives the copy being rewritten, and "No longer than" is
        // not.
        blockingConstraint: nothing.blocking.firstOrNull?.name,
        eligibleCount: nothing.eligibleCount,
        blockedByRepetition: nothing.blockedByRepetition,
      ),
    );
    return nothing;
  }

  /// Works out what to say when nothing matched.
  ///
  /// docs/USER_FLOWS.md §7 asks for two things — name the blocking constraint,
  /// and offer the single filter whose relaxation opens the most options — and
  /// both are answered here by counting rather than guessing. For each active
  /// filter, how many of the eligible meals would come back if *that one* were
  /// dropped. The largest wins, and it is a real number the screen can quote.
  ///
  /// This is the reason the filters are applied client-side at all: on the server
  /// each of those questions is another round trip, and there are up to five of
  /// them at the exact moment the reader is already waiting.
  SpinNoMatch _noMatch({
    required SpinFilters filters,
    required List<Meal> eligible,
    required int hiddenCount,
    int blockedByRepetition = 0,
    int blockedByIngredient = 0,
  }) {
    // Sorted by what each one costs, so the sentence leads with the filter doing
    // the most damage rather than whichever happens to be declared first.
    final Map<SpinConstraint, int> opens = <SpinConstraint, int>{
      for (final SpinConstraint constraint in filters.active)
        if (constraint.isRelaxable)
          constraint: eligible.where(filters.without(constraint).allows).length,
    };

    final List<SpinConstraint> blocking = filters.active.toList()
      ..sort(
        (SpinConstraint a, SpinConstraint b) =>
            (opens[b] ?? -1).compareTo(opens[a] ?? -1),
      );

    SpinConstraint? best;
    int bestCount = 0;
    for (final (SpinConstraint constraint, int count) in opens.entries.map(
      (MapEntry<SpinConstraint, int> e) => (e.key, e.value),
    )) {
      if (count > bestCount) {
        best = constraint;
        bestCount = count;
      }
    }

    return SpinNoMatch(
      filters: filters,
      blocking: blocking,
      seenThisSession: _seenThisSession.length,
      hiddenCount: hiddenCount,
      eligibleCount: eligible.length,
      // Only offered when dropping it actually helps. "Relax the budget" that
      // opens nothing is worse than no suggestion: it spends the reader's tap
      // and returns them to the same screen.
      mostRelaxable: bestCount > 0 ? best : null,
      wouldOpen: bestCount,
      blockedByRepetition: blockedByRepetition,
      blockedByIngredient: blockedByIngredient,
    );
  }

  /// Everything the scorer needs about this household.
  ///
  /// Assembled here rather than inside [MealScorer], which is pure Dart with no
  /// providers in it — the placement docs/ARCHITECTURE.md §5.1 specifies for the
  /// engine, and the reason its behaviour can be checked without a device.
  ///
  /// The budget and the time limit come from the **filters**, not the profile, so
  /// a tighter budget set for one evening is what gets scored against — the same
  /// numbers Home is showing.
  Future<ScoringContext> _scoringContext(SpinFilters filters) async {
    final FoodPreferences? preferences = ref
        .read(profileControllerProvider)
        .value
        ?.preferences;

    return ScoringContext(
      favouriteCuisines: preferences?.favouriteCuisines ?? const <Cuisine>{},
      // Best effort, like the history below: a favourite that failed to load
      // costs fifteen points, and failing the spin over it would cost dinner.
      favouriteMealIds:
          ref.read(favoritesControllerProvider).value ?? const <String>{},
      recent: await _recentMeals(),
      budgetPerHead: filters.maxCostPerServing,
      maxCookingTimeMinutes: filters.maxCookingTimeMinutes,
      settings: RepetitionSettings.fromWindowDays(
        preferences?.repetitionWindowDays,
      ),
      // Tonight's mood (Sprint 36). From the filters rather than the profile: a
      // mood is a statement about this evening, and storing it would make it a
      // standing preference nobody asked for.
      mood: filters.mood,
      // What is already in the kitchen (Sprint 41). Best effort, like the
      // history above: an empty map means no information rather than no
      // ingredients, and the scorer treats it that way — a fridge we could not
      // read should cost a bonus, never a spin.
      pantry: await ref.read(pantryMatchesProvider.future),
    );
  }

  /// What the household has eaten, as the scorer wants it.
  ///
  /// The days-ago arithmetic happens here rather than in the rule, which is what
  /// keeps that file a pure function with no clock in it (docs/ARCHITECTURE.md
  /// §5.1). Midnight-to-midnight rather than elapsed hours: a meal eaten at
  /// eleven last night was "yesterday", not "thirteen hours ago", and a window
  /// measured in hours would let it back a day early for anyone who eats late.
  ///
  /// Best effort. The roulette is worth using without a history — a new
  /// household has none at all — so a failed read means no repetition rules
  /// rather than no spin.
  Future<List<RecentMeal>> _recentMeals() async {
    try {
      final List<MealHistoryEntry> history = await ref.read(
        mealHistoryProvider.future,
      );
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      return <RecentMeal>[
        for (final MealHistoryEntry entry in history)
          if (entry.meal?.cuisine case final Cuisine cuisine)
            RecentMeal(
              mealId: entry.mealId,
              cuisine: cuisine,
              daysAgo: today
                  .difference(
                    DateTime(
                      entry.eatenAt.year,
                      entry.eatenAt.month,
                      entry.eatenAt.day,
                    ),
                  )
                  .inDays,
            ),
      ];
    } on Object {
      return const <RecentMeal>[];
    }
  }

  /// Ends the session: this is what we are eating.
  ///
  /// Clears the exclusions so the next spin starts from the whole catalogue.
  /// Nothing is written anywhere yet — the meal becomes a `meal_history` row in
  /// Sprint 31, which is also where the accepted meal starts feeding the
  /// recency penalty.
  void accept() {
    _seenThisSession.clear();
    // Reset with the exclusions, because both are the session: the next spin is
    // a new question, and it is spin one of it.
    _spinsThisSession = 0;
    state = const SpinIdle();
  }

  /// Forgets the session's exclusions without accepting anything.
  ///
  /// For the exhausted no-match state: "start again" has to mean something when
  /// the only thing standing between the reader and a meal is that they have
  /// already seen it today.
  Future<void> startOver() {
    _seenThisSession.clear();
    return spin();
  }

  /// Drops one filter and spins again — the no-match state's one tap out.
  ///
  /// Goes through the filters controller rather than spinning with a local copy,
  /// because the relaxation has to *stick*: a reader who accepts "drop the time
  /// limit" and then taps Try Again should not have it silently reimposed.
  Future<void> relaxAndSpin(SpinConstraint constraint) {
    ref
        .read(spinFiltersControllerProvider.notifier)
        .replace(ref.read(spinFiltersProvider).without(constraint));
    return spin();
  }

  /// Drops back to idle, for leaving the spin without deciding.
  void reset() => state = const SpinIdle();

  /// How many candidates the assistant is offered.
  ///
  /// Twelve. Enough that its judgement has room to differ from the draw's, few
  /// enough that the prompt stays short and the model reliably answers with an
  /// index rather than prose — and few enough that a stray number is almost always
  /// out of range and therefore refused.
  static const int _shortlistSize = 12;

  /// How long the assistant gets.
  ///
  /// Four seconds. The reel runs 2.2 and the screen holds the reveal for a short
  /// grace beyond it, so anything slower than this has already lost its chance to
  /// matter — and holding the socket open past the moment its answer is useless is
  /// a request nobody is waiting for.
  static const Duration _assistantBudget = Duration(seconds: 4);
}

/// How many candidates a spin asks for.
///
/// The whole catalogue in one request, not a page of it. A uniform pick from the
/// first twenty of sixty alphabetically is not random — it is a bias toward
/// meals whose names begin with A, and the reader would feel it long before they
/// could name it.
///
/// Comfortably above the sixty the catalogue ships with plus whatever a
/// household writes. If it ever needs raising, the honest fix is picking on the
/// server rather than a bigger number here.
const int kSpinPoolSize = 200;
