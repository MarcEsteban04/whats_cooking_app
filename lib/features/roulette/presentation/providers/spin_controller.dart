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
/// error. It names the specific blocking constraint." With no filters yet
/// (Sprint 30) there are exactly two ways to get here, and they want different
/// words — one is a compliment about how much you have browsed, the other is a
/// consequence of hiding food.
class SpinNoMatch extends SpinState {
  const SpinNoMatch({required this.seenThisSession, required this.hiddenCount});

  /// How many this session has already offered.
  final int seenThisSession;

  /// How many meals the user has hidden.
  final int hiddenCount;

  /// Whether the session's own exclusions are what emptied the pool.
  bool get isSessionExhausted => seenThisSession > 0;
}

/// The pool could not be read.
class SpinFailed extends SpinState {
  const SpinFailed(this.failure);

  final AppException failure;
}

/// Drives the roulette (docs/USER_FLOWS.md §7 — *this is the product*).
///
/// **Selection here is deliberately naive.** It is a uniform pick from
/// everything eligible: no scoring, no weighting, no recency penalty. Those are
/// Sprints 29 and 30, and pretending otherwise now would mean a scoring model
/// tuned against a candidate pool that does not exist yet. What *is* already
/// honoured is the part that is not negotiable — hidden meals never appear, and
/// no meal is offered twice in one session.
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

      if (page.meals.isEmpty) {
        state = SpinNoMatch(
          seenThisSession: _seenThisSession.length,
          hiddenCount: hidden.length,
        );
        return;
      }

      final Meal pick = page.meals[_random.nextInt(page.meals.length)];
      _seenThisSession.add(pick.id);

      state = SpinSettled(meal: pick, pool: page.meals);
    } on Object catch (error, stackTrace) {
      state = SpinFailed(ErrorMapper.map(error, stackTrace));
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
