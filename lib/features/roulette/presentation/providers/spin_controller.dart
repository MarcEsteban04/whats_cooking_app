import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';
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
  const SpinSettled({required this.meal, required this.pool});

  final Meal meal;

  /// Everything that was eligible, for the cycling animation to flick through.
  ///
  /// The animation needs *plausible* meals rather than the winner repeated, and
  /// this is the pool it was drawn from — so what flashes past is food the user
  /// could actually have got.
  final List<Meal> pool;
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

  /// Whether the reader's own filters are what emptied the pool.
  bool get isFilteredOut => eligibleCount > 0 && blocking.isNotEmpty;

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
/// **Selection is still a uniform pick.** No scoring, no weighting, no recency
/// penalty — those are Sprint 34's, and tuning a model against a candidate pool
/// that has just changed shape would be work thrown away. What is honoured is
/// everything that is not negotiable: hidden meals never appear, no meal is
/// offered twice in a session, and the reader's filters are hard.
///
/// **Two layers of narrowing, and they are different in kind.** The dislikes and
/// the session's own exclusions go into the query, because those are promises
/// rather than choices and must not depend on client code running correctly. The
/// reader's filters are applied here, over the whole eligible pool, because that
/// is what makes the no-match state able to say *which* filter is costing them
/// dinner — see [SpinFilters] for the trade in full.
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

  @override
  SpinState build() => const SpinIdle();

  int get seenThisSession => _seenThisSession.length;

  /// Picks a meal.
  ///
  /// Returns immediately after setting [SpinRunning]; the screen animates while
  /// this works. Nothing is thrown — a failed spin is a state, because the
  /// animation is already running by the time it happens and there is nowhere
  /// for an exception to go.
  Future<void> spin() async {
    state = const SpinRunning();

    try {
      // Read rather than watched: a dislike toggled mid-spin should not restart
      // the pick. The next spin will see it.
      final Set<String> hidden = await ref.read(
        dislikesControllerProvider.future,
      );

      final MealQuery query = MealQuery(
        // Both exclusions in one set, because the query does not care why a meal
        // is out — only that it must not come back. Applied on the server, so
        // the pool is right rather than filtered after the fact.
        excludedMealIds: <String>{...hidden, ..._seenThisSession},
      );

      final MealPage page = await ref
          .read(mealRepositoryProvider)
          .search(query: query, limit: kSpinPoolSize);

      final SpinFilters filters = ref.read(spinFiltersProvider);
      final List<Meal> eligible = page.meals;
      final List<Meal> candidates = eligible
          .where(filters.allows)
          .toList(growable: false);

      if (candidates.isEmpty) {
        state = _noMatch(
          filters: filters,
          eligible: eligible,
          hiddenCount: hidden.length,
        );
        return;
      }

      final Meal pick = candidates[_random.nextInt(candidates.length)];
      _seenThisSession.add(pick.id);

      state = SpinSettled(meal: pick, pool: candidates);
    } on Object catch (error, stackTrace) {
      state = SpinFailed(ErrorMapper.map(error, stackTrace));
    }
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
    );
  }

  /// Ends the session: this is what we are eating.
  ///
  /// Clears the exclusions so the next spin starts from the whole catalogue.
  /// Nothing is written anywhere yet — the meal becomes a `meal_history` row in
  /// Sprint 31, which is also where the accepted meal starts feeding the
  /// recency penalty.
  void accept() {
    _seenThisSession.clear();
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
