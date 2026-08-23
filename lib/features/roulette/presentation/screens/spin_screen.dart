import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_controller.dart';
import 'package:whats_cooking/features/roulette/presentation/widgets/meal_reel.dart';
import 'package:whats_cooking/features/roulette/presentation/widgets/picking_card.dart';

/// The spin (docs/design_ui.md §12, docs/DESIGN_SYSTEM.md §7).
///
/// **This screen owns starting the spin.** Home and Try Again both just navigate
/// here, and this calls `spin()` once on entry. One rule, one place — the
/// alternative was a caller that kicks off a spin *and* navigates, which double
/// spins the moment somebody adds a third entry point.
///
/// The four phases and their timings are fixed in [AppRouletteMotion] rather
/// than here, because the product's signature moment has to feel identical every
/// time. What this screen adds is the arrangement: a [MealReel] carrying the
/// whole candidate pool through a window, driven by [reelOffsetAt].
///
/// **The reel lands on the winner rather than near it.** The travel distance is
/// known in advance, so the pool is reordered when it arrives to put the picked
/// meal exactly where the reel will stop. The alternative — stopping wherever it
/// likes and then showing a different meal on the next screen — is the version of
/// this interaction that feels rigged, and people notice within two spins.
///
/// **The animation does not wait for the network and the reveal does not lie.**
/// The pick is fetched while the reel is already turning, which is most of what
/// makes 2.6 seconds feel like a decision rather than a loading screen. But the
/// reveal only happens once the pick has landed: if the request is slower than
/// the reel, the reel stops and the line above it says so. A reveal that beat its
/// own answer would have to show something and then change it.
///
/// Capped at [AppMotion.spinMaximum] by construction, and skippable by tapping
/// anywhere — docs/USER_FLOWS.md §7: "Suspense that outstays its welcome fails
/// the 60-second budget." A tap does not cut the reel off mid-card; it runs the
/// remaining travel out fast, so the landing stays exact.
class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The pool, reordered so the reel's landing slot holds the winner.
  ///
  /// Built once, the first time a settled state arrives. Rebuilding it would move
  /// the cards under the reader mid-spin.
  List<Meal>? _reelPool;

  /// Set when the reel has come to rest.
  bool _isReelStopped = false;

  /// Which meal is currently sitting in the reel's landing slot (Sprint 47c).
  ///
  /// Tracked because the winner can *change* now: the engine's pick is planted
  /// immediately so the reel can roll, and the assistant may replace it before the
  /// reel stops. Re-planting mid-roll is invisible — the landing slot is twenty
  /// cards away and only five are on screen — but only if something notices the
  /// swap is needed.
  String? _plantedId;

  /// Fires when the assistant has had long enough.
  Timer? _graceTimer;

  /// True while the assistant is still choosing, so the reel holds.
  ///
  /// **The AI decides, and the wheel waits for it.** The deterministic engine
  /// filters the pool and shortlists it — that is what keeps the dietary needs,
  /// the avoided foods, the hidden meals and the repetition window, none of which
  /// a model can be trusted with — and then the model picks from that shortlist.
  /// Its weighted draw is the *fallback*, for a rate limit or an outage.
  ///
  /// Before this the window was a second and a half, which a model usually lost,
  /// so the draw answered most spins and the AI was decoration.
  bool _isAwaitingAssistant = false;

  /// Guards the navigation to the result, which two callbacks race toward.
  bool _hasRevealed = false;

  /// The last whole card the reel passed, for the deceleration haptics.
  int _lastTickedCard = 0;

  Timer? _revealTimer;

  /// Fires if the pool takes too long, so a slow night still turns the reel.
  Timer? _poolTimer;

  /// Set when the device asks for less motion, so the reel is never started.
  bool _isReducedMotion = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
            // Three phases, not four: the fourth is the beat spent letting the
            // landed card settle, and then the result route's own transition
            // finishes the job.
            duration:
                AppRouletteMotion.windUp +
                AppRouletteMotion.fastCycle +
                AppRouletteMotion.decelerate,
            vsync: this,
          )
          ..addStatusListener(_onStatus)
          ..addListener(_onTick);

    // Read, not watched, and deferred by a microtask because `ref.read` is not
    // allowed during `initState`. Re-checked for `mounted` because backing out
    // that fast is possible and reading a disposed ref throws.
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(spinControllerProvider.notifier).spin();
      }
    });

    AppHaptics.spinBegun();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Started here rather than in `initState` because it needs the media query.
    if (_isReelStopped || _controller.isAnimating || _controller.isCompleted) {
      return;
    }

    // Reduced motion gets no reel at all — docs/DESIGN_SYSTEM.md §7 replaces the
    // cycling with a cross-fade — so the travel is skipped and the reveal waits
    // only on the pick.
    if (AppMotion.prefersReducedMotion(context)) {
      _isReducedMotion = true;
      _controller.value = 1;
      _isReelStopped = true;
      _scheduleReveal();
      return;
    }

    // **Armed, not started.** The reel used to begin turning the moment this
    // screen mounted, which meant that on a cold first spin it spent its whole
    // 2.2 seconds showing the wind-up card and stopped just as the meals
    // arrived — no roll at all, while Try Again (with everything cached) rolled
    // perfectly. An animation with nothing to animate is not suspense, it is a
    // stall with a spinner's manners.
    //
    // So the travel starts when there are cards, and this timer is only the
    // backstop: past [_maxPoolWait] it rolls the wind-up card anyway, because
    // waiting silently is worse than moving early.
    _poolTimer ??= Timer(_maxPoolWait, _startReel);
  }

  /// Begins the travel, once.
  ///
  /// [force] is the assistant window closing. Without it the roll is refused
  /// while the assistant is still deciding, because the card the reel lands on is
  /// the answer — see `_isAwaitingAssistant`.
  void _startReel({bool force = false}) {
    if (!force && _isAwaitingAssistant) {
      return;
    }

    _poolTimer?.cancel();
    _poolTimer = null;

    if (_isReducedMotion ||
        _isReelStopped ||
        _controller.isAnimating ||
        _controller.isCompleted) {
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _poolTimer?.cancel();
    _graceTimer?.cancel();
    _controller
      ..removeStatusListener(_onStatus)
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  /// A click per card, but only while the reel is slowing.
  ///
  /// Fifteen clicks through the fast phase would be a buzz; five through the
  /// deceleration is the reel being *felt* as it settles, which is what
  /// design_ui §12 means by "haptic feedback" for a moment lasting under a
  /// second.
  void _onTick() {
    final int card = reelOffsetAt(_controller.value).floor();
    if (card == _lastTickedCard) {
      return;
    }
    _lastTickedCard = card;

    if (_controller.value > _decelerationBegins) {
      AppHaptics.reelTick();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _isReelStopped) {
      return;
    }
    setState(() => _isReelStopped = true);

    // **The card the reel landed on is now the answer.** Told to the controller
    // rather than merely remembered here, because it is the controller that a
    // late assistant reply would otherwise change — and the reader has just
    // watched the wheel stop.
    ref.read(spinControllerProvider.notifier).lockIn();

    _scheduleReveal();
  }

  /// Ends the suspense early.
  ///
  /// Runs the rest of the travel out at speed rather than cutting it: a reel
  /// frozen mid-card looks broken, and the landing has to stay exact because the
  /// card it lands on is the meal the next screen shows.
  void _skip() {
    if (_isReelStopped || !_controller.isAnimating) {
      return;
    }
    _controller.animateTo(
      1,
      duration: AppMotion.fast,
      curve: AppMotion.curveFast,
    );
  }

  /// Gives the landed card its beat before the screen changes.
  void _scheduleReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(AppRouletteMotion.reveal, _maybeReveal);
  }

  /// Goes to the result, once the reel has stopped.
  ///
  /// **No grace window here any more** (Sprint 53b). It used to hold the reveal
  /// for a second and a half after the reel stopped, so a slow assistant could
  /// still be adopted — and that is exactly what produced a reel stopped on
  /// champorado and a result screen showing arroz caldo. The same second and a
  /// half is now spent *before* the roll, where the answer it buys can still
  /// change what the wheel lands on.
  void _maybeReveal() {
    if (_hasRevealed || !_isReelStopped || !mounted) {
      return;
    }

    _reveal();
  }

  /// Goes, without asking again whether to wait.
  void _reveal() {
    if (_hasRevealed || !_isReelStopped || !mounted) {
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = null;

    if (ref.read(spinControllerProvider) case SpinSettled(:final Meal meal)) {
      _hasRevealed = true;
      AppHaptics.reveal();
      context.goNamed(
        AppRoute.rouletteResult.routeName,
        pathParameters: <String, String>{'mealId': meal.id},
        // The meal itself, so the result screen has nothing to fetch. The pick
        // is already in hand; making the payoff wait on a round trip would undo
        // the point of fetching during the animation.
        extra: meal,
      );
    }
  }

  /// Reorders [pool] so the reel's landing slot holds [winner].
  ///
  /// A swap rather than a rotation: only one card needs to be in the right
  /// place, and a swap cannot drop or duplicate a meal the way a mis-written
  /// rotation can.
  List<Meal> _plant(List<Meal> pool, Meal winner) {
    final List<Meal> reel = List<Meal>.of(pool);
    final int target = reelSettleIndex(reelTotalTravel) % reel.length;
    final int current = reel.indexWhere((Meal meal) => meal.id == winner.id);

    if (current < 0) {
      // Cannot happen — the winner came out of this pool — but a reel landing on
      // the wrong meal is the one failure here worth being defensive about.
      reel[target] = winner;
      return reel;
    }

    reel[current] = reel[target];
    reel[target] = winner;
    return reel;
  }

  @override
  Widget build(BuildContext context) {
    final SpinState state = ref.watch(spinControllerProvider);

    // The pick can land after the reel has stopped, and this is where that is
    // noticed. `ref.listen` rather than acting on the watched value directly:
    // navigating from a build is not allowed, and this fires after it.
    ref.listen(spinControllerProvider, (SpinState? _, SpinState next) {
      if (next case SpinSettled(:final Meal meal, :final List<Meal> pool)) {
        // Planted, or **re-planted**: the assistant may have replaced the
        // engine's pick while the reel was rolling (Sprint 47c). Safe until the
        // reel stops, because the landing slot is the last card of twenty and only
        // five are ever on screen.
        if (_plantedId != meal.id && !_isReelStopped) {
          _plantedId = meal.id;
          setState(() => _reelPool = _plant(pool, meal));
        }

        // **The roll waits for the assistant, not the reveal** (Sprint 53b).
        //
        // The window used to sit after the reel stopped, which is the one place
        // it cannot be spent honestly: the wheel had already landed on the
        // engine's pick and the reader had seen it, so adopting a different meal
        // meant the result screen contradicted the reel — champorado on the
        // wheel, arroz caldo on the card.
        //
        // Held here instead, for the same second and a half. If the answer lands
        // first the reel rolls to the *final* winner and the reveal is immediate;
        // if it does not, the timer rolls anyway and `lockIn` makes the engine's
        // pick permanent. Either way the card the wheel stops on is the card the
        // next screen shows, which is the only promise a reel makes.
        if (next case SpinSettled(isAwaitingAssistant: true)) {
          _isAwaitingAssistant = true;
          _graceTimer ??= Timer(_assistantGrace, () => _startReel(force: true));
        } else {
          _isAwaitingAssistant = false;
          _graceTimer?.cancel();
          _graceTimer = null;
          _startReel(force: true);
        }

        _maybeReveal();
        return;
      }

      // The two endings that are not a meal. Both replace this screen outright,
      // so the reel is stopped rather than left running behind them — and both
      // get a haptic, because a screen that silently swaps itself for a wall of
      // text reads as a stall the reader caused.
      if (next is SpinNoMatch || next is SpinFailed) {
        _controller.stop();
        if (next is SpinNoMatch) {
          AppHaptics.nothingFound();
        }
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: _skip,
          // Opaque so a tap anywhere counts, including the gaps.
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppLayout.screenMargin),
                child: switch (state) {
                  SpinFailed(:final failure) => ErrorState(
                    kind: failure.errorStateKind,
                    body: failure.displayMessage,
                    errorCode: failure.supportCode,
                    onRetry: failure.shouldOfferRetry
                        ? () => ref.read(spinControllerProvider.notifier).spin()
                        : null,
                  ),
                  final SpinNoMatch noMatch => _NoMatch(state: noMatch),
                  // **Nothing nameable until there is something to name.**
                  //
                  // While the assistant is choosing, the reel has not started —
                  // and rendering it anyway drew its pool at offset zero, which
                  // put a meal in the landing slot looking exactly like a result
                  // for up to four seconds. Usually the engine's pick, which the
                  // assistant was in the middle of overruling.
                  _ when _isAwaitingAssistant && !_isReelStopped =>
                    const PickingCard(),
                  _ => _Spinning(
                    animation: _controller,
                    pool: _reelPool ?? const <Meal>[],
                    isStopped: _isReelStopped,
                    isAsking: state is SpinSettled && state.isAwaitingAssistant,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How long the reel waits for meals before turning regardless.
  ///
  /// Two seconds. Long enough that a normal request lands first and the roll is
  /// the whole spin; short enough that a bad connection does not leave somebody
  /// staring at a static card wondering whether they tapped it.
  static const Duration _maxPoolWait = Duration(seconds: 2);

  /// How long the reveal waits for the assistant once the reel has stopped.
  /// How long the roll waits for the assistant to choose.
  ///
  /// **The controller's own budget, plus a beat.** It was a second and a half,
  /// which a model usually lost — so the weighted draw answered most spins and
  /// the AI was decoration. Matching the request's timeout means the answer that
  /// arrives is the one the wheel lands on, and the draw only stands when the
  /// request genuinely failed.
  ///
  /// The cost is honest and it is real: a slow provider makes the spin about four
  /// seconds longer, spent on a screen that says "ASKING THE ASSISTANT". Groq
  /// usually answers in well under one.
  static const Duration _assistantGrace = Duration(milliseconds: 4200);

  /// Where the deceleration starts, as a fraction of the whole travel. Derived
  /// from [AppRouletteMotion] so changing a phase length moves this too.
  static final double _decelerationBegins =
      (AppRouletteMotion.windUp + AppRouletteMotion.fastCycle).inMilliseconds /
      (AppRouletteMotion.windUp +
              AppRouletteMotion.fastCycle +
              AppRouletteMotion.decelerate)
          .inMilliseconds;
}

/// The reel, with a line above it and a hint below.
class _Spinning extends StatelessWidget {
  const _Spinning({
    required this.animation,
    required this.pool,
    required this.isStopped,
    required this.isAsking,
  });

  final Animation<double> animation;
  final List<Meal> pool;
  final bool isStopped;

  /// Whether the assistant is still deciding (Sprint 47c).
  final bool isAsking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Says what is happening rather than that something is. "Deciding" is
        // equally true of a spinner; a count is the reel explaining itself.
        Text(
          switch ((pool.isEmpty, isStopped, isAsking)) {
            (true, _, _) => 'LOOKING AT WHAT YOU CAN COOK',
            // Says what the pause is, on the one screen where a pause without a
            // reason reads as a stall. It is also the truth: the answer exists and
            // something is deciding whether to improve on it.
            (false, true, true) => 'ASKING THE ASSISTANT',
            (false, true, false) => 'ALMOST',
            (false, false, _) => '${pool.length} MEALS ON THE TABLE',
          },
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space5),
        AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? _) {
            final double offset = reelOffsetAt(animation.value);
            return MealReel(
              offset: offset,
              // Mapped here rather than by the reel (Sprint 46). The reel takes
              // a view model now so the restaurant roulette can be the *same*
              // reel rather than a copy — and a meal's metadata line is time and
              // cost, which is not what a restaurant's says.
              pool: <ReelEntry>[
                for (final Meal meal in pool)
                  ReelEntry(
                    id: meal.id,
                    overline: meal.cuisine.label,
                    title: meal.name,
                    metadata: AppFormat.metadata(<String?>[
                      AppFormat.cookingTime(meal.cookingTimeMinutes),
                      '${AppFormat.peso(meal.costPerServing)} a head',
                    ]),
                    tint: meal.cuisine.label,
                  ),
              ],
              settledIndex: isStopped ? reelSettleIndex(offset) : null,
            );
          },
        ),
        const SizedBox(height: AppSpacing.space5),
        // Fades once there is nothing left to stop, rather than sitting there
        // telling the reader to do something that no longer works.
        AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: isStopped ? 0 : 1,
          child: Text(
            'Tap anywhere to stop',
            style: context.text.metadata,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Nothing to offer — a designed screen, not an error (docs/USER_FLOWS.md §7).
///
/// Three different failures, three different sentences, because they have three
/// different fixes and a generic "no results" leaves the reader to guess which
/// one they are looking at:
///
/// * **Filtered out** — plenty of meals exist, none match. The screen quotes the
///   blocking constraint by name and offers to drop the one filter that opens the
///   most options, with the number it would open. That number is real: it was
///   counted over the eligible pool before this was built.
/// * **Exhausted** — every eligible meal has already been turned down this
///   session. Starting again is the fix and nothing needs relaxing.
/// * **Everything hidden** — the reader hid it all. The hidden list is the fix.
/// * **Everything avoided** — every remaining meal uses a food on the avoid
///   list. Editing that list is the fix, and the screen never offers to ignore
///   it: an avoided food is a promise, like a dietary need.
///
/// It never offers to relax a dietary need, at any point, for any reason.
class _NoMatch extends ConsumerWidget {
  const _NoMatch({required this.state});

  final SpinNoMatch state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _title,
          style: context.text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          _body,
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space6),
        ..._actions(context, ref),
      ],
    );
  }

  String get _title {
    if (state.isAllAvoided) {
      return 'Everything has something you avoid';
    }
    if (state.isAllTooRecent) {
      return 'You have had them all';
    }
    if (state.isFilteredOut) {
      // The reader's own words back at them, not "no results found". They set a
      // budget and a time limit; the headline should sound like it knows that.
      return 'Nothing fits';
    }
    if (state.isSessionExhausted) {
      return 'That is everything';
    }
    return 'Nothing to offer';
  }

  String get _body {
    if (state.isAllAvoided) {
      final int blocked = state.blockedByIngredient;
      final String noun = blocked == 1 ? 'meal' : 'meals';
      return 'All $blocked $noun use a food on your avoid list. Take one off '
          'and we will have something to offer.';
    }
    if (state.isAllTooRecent) {
      final int blocked = state.blockedByRepetition;
      final String noun = blocked == 1 ? 'meal' : 'meals';
      return 'All $blocked $noun that fit have been eaten too recently. '
          'Give it a day, or shorten how long we wait before offering '
          'something again.';
    }
    if (state.blockingSentence case final String sentence) {
      return sentence;
    }
    if (state.isSessionExhausted) {
      return 'You have turned down all ${state.seenThisSession} of them this '
          'time round. Start again and they are all back in.';
    }
    if (state.hiddenCount > 0) {
      return 'Every meal we have is one you hid. Bring one back and we can '
          'offer it.';
    }
    return 'The catalogue is empty, which is our problem rather than yours.';
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    return <Widget>[
      // The one-tap relaxation §7 asks for. Named and quantified, because
      // "loosen a filter" is a request to trust the app and "37 meals" is a
      // reason to.
      // The repetition window is a setting rather than a filter, so the way
      // out is the preference that owns it — not a one-tap relaxation.
      // Offering "ignore what we ate recently, just this once" would undo the
      // one rule the household explicitly asked for.
      // The avoided list is a promise, so this never offers to ignore it — the
      // way out is editing the list itself, which is the reader's call and not
      // a relaxation the app gets to suggest.
      if (state.isAllAvoided)
        AppButton.primary(
          label: 'What you avoid',
          onPressed: () => context.pushNamed(AppRoute.preferences.routeName),
        )
      else if (state.isAllTooRecent)
        AppButton.primary(
          label: 'Change how often we repeat',
          onPressed: () => context.pushNamed(AppRoute.preferences.routeName),
        )
      else if (state.mostRelaxable case final SpinConstraint constraint)
        AppButton.primary(
          // The constraint's own name rather than its current value: "Drop the
          // budget" is an instruction, and "Drop under ₱150 a head" is a
          // fragment somebody has to re-read.
          label: 'Drop ${constraint.label}',
          onPressed: () => ref
              .read(spinControllerProvider.notifier)
              .relaxAndSpin(constraint),
        )
      else if (state.isSessionExhausted)
        AppButton.primary(
          label: 'Start again',
          onPressed: () =>
              ref.read(spinControllerProvider.notifier).startOver(),
        )
      else if (state.hiddenCount > 0)
        AppButton.primary(
          label: 'Hidden meals',
          onPressed: () => context.pushNamed(AppRoute.dislikedMeals.routeName),
        ),

      if (state.mostRelaxable != null) ...<Widget>[
        const SizedBox(height: AppSpacing.space2),
        Text(
          '${state.wouldOpen} ${state.wouldOpen == 1 ? 'meal' : 'meals'} '
          'would come back.',
          style: context.text.metadata,
          textAlign: TextAlign.center,
        ),
      ],

      const SizedBox(height: AppSpacing.space3),

      // Always offered when anything is filtering, because the app's suggestion
      // is a guess about which filter the reader minds least — and they know.
      if (state.filters.hasChosen)
        AppButton.secondary(
          label: 'Change the filters',
          onPressed: () =>
              context.pushNamed(AppRoute.rouletteFilters.routeName),
        ),

      // The answer the app cannot reach on its own (Sprint 37).
      //
      // Every other action here loosens something. This one adds something, and it
      // is often the real fix: a spin finds nothing because we have not told it
      // about the thing we actually cook on a Tuesday. Offered on every no-match
      // rather than only the "only ours" one, because a filtered-out pool is just
      // as often a thin library as it is a tight budget.
      AppButton.tertiary(
        label: 'Add one of your own',
        size: AppButtonSize.small,
        leadingIcon: AppIcons.add,
        onPressed: () => context.pushNamed(AppRoute.mealCreate.routeName),
      ),

      const SizedBox(height: AppSpacing.space2),
      AppButton.tertiary(
        label: 'Back',
        size: AppButtonSize.small,
        onPressed: () {
          ref.read(spinControllerProvider.notifier).reset();
          context.goNamed(AppRoute.home.routeName);
        },
      ),
    ];
  }
}
