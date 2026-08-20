import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_controller.dart';

/// The spin (docs/design_ui.md §12, docs/DESIGN_SYSTEM.md §7).
///
/// **This screen owns starting the spin.** Home and Try Again both just navigate
/// here, and this calls `spin()` once on entry. One rule, one place — the
/// alternative was a caller that kicks off a spin *and* navigates, which double
/// spins the moment somebody adds a third entry point.
///
/// The four phases and their timings are fixed in [AppRouletteMotion] rather
/// than here, because the product's signature moment has to feel identical every
/// time. What this widget adds is the mapping from one animation value to a
/// **meal index**: linear through the fast cycle, then eased so the cards
/// visibly stretch apart before stopping. That easing is the suspense — nothing
/// else on the screen creates it.
///
/// **The animation does not wait for the network and the reveal does not lie.**
/// The pick is fetched while the cards are already flying, which is most of what
/// makes 2.6 seconds feel like a decision rather than a loading screen. But the
/// reveal only happens once the pick has actually landed: if the request is
/// slower than the animation, the cards keep turning. A reveal that beat its own
/// answer would have to show something and then change it.
///
/// Capped at [AppMotion.spinMaximum] by construction, and skippable by tapping
/// anywhere — docs/USER_FLOWS.md §7: "Suspense that outstays its welcome fails
/// the 60-second budget."
class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Set once the cards have finished turning, whether by time or by a tap.
  bool _isCycleDone = false;

  /// Guards the navigation to the result, which two callbacks race toward.
  bool _hasRevealed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      // The reveal is not in here: it belongs to the result route's entry
      // transition, so the card that lands is the card that stays.
      duration:
          AppRouletteMotion.windUp +
          AppRouletteMotion.fastCycle +
          AppRouletteMotion.decelerate,
      vsync: this,
    )..addStatusListener(_onStatus);

    // Read, not watched, and in `initState` rather than `build`: starting a
    // request from a build is a state change during build, and a rebuild must
    // not start a second spin.
    //
    // Deferred by a microtask because `ref.read` is not allowed during
    // `initState`, and re-checked for `mounted` because backing out that fast
    // is possible and reading a disposed ref throws.
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(spinControllerProvider.notifier).spin();
      }
    });

    HapticFeedback.lightImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Started here rather than in `initState` because it needs the media query.
    // Reduced motion gets no cycling at all — docs/DESIGN_SYSTEM.md §7 replaces
    // it with a cross-fade — so the animation is skipped and the reveal waits
    // only on the pick.
    // `_isCycleDone` is in here because a tap stops the controller without
    // completing it, and a later dependency change would otherwise restart the
    // cycle the reader just skipped.
    if (_isCycleDone || _controller.isAnimating || _controller.isCompleted) {
      return;
    }
    if (AppMotion.prefersReducedMotion(context)) {
      _isCycleDone = true;
      _maybeReveal();
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _isCycleDone = true;
      _maybeReveal();
    }
  }

  /// Ends the suspense early.
  ///
  /// Jumps rather than reverses: a tap means "show me", and easing to the end
  /// from 40% would take longer than letting it finish.
  void _skip() {
    if (_isCycleDone) {
      return;
    }
    _controller.stop();
    _isCycleDone = true;
    _maybeReveal();
  }

  /// Goes to the result, once both halves are ready.
  ///
  /// Called from the animation and from the state listener, either of which may
  /// be last. [_hasRevealed] is what stops them both navigating.
  void _maybeReveal() {
    if (_hasRevealed || !_isCycleDone || !mounted) {
      return;
    }

    if (ref.read(spinControllerProvider) case SpinSettled(:final Meal meal)) {
      _hasRevealed = true;
      HapticFeedback.mediumImpact();
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

  @override
  Widget build(BuildContext context) {
    final SpinState state = ref.watch(spinControllerProvider);

    // The pick can land after the cards have stopped, and this is where that is
    // noticed. `ref.listen` rather than acting on the watched value directly:
    // navigating from a build is not allowed, and this fires after it.
    ref.listen(spinControllerProvider, (SpinState? _, SpinState next) {
      if (next is SpinSettled) {
        _maybeReveal();
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
                  _ => _Cycling(
                    animation: _controller,
                    pool: state is SpinSettled ? state.pool : const <Meal>[],
                    isWaiting: _isCycleDone,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cards, turning.
class _Cycling extends StatelessWidget {
  const _Cycling({
    required this.animation,
    required this.pool,
    required this.isWaiting,
  });

  final Animation<double> animation;

  /// What flicks past. Empty until the pool lands, which is what the wind-up
  /// card covers.
  final List<Meal> pool;

  /// The cards have stopped but the pick has not arrived. Rare, and honest about
  /// itself rather than pretending to still be choosing.
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          isWaiting ? 'Almost' : 'Deciding',
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space5),
        AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? _) {
            if (pool.isEmpty) {
              return const _WindUpCard();
            }

            final int index = _mealIndex(animation.value, pool.length);
            return _MealFlash(meal: pool[index]);
          },
        ),
        const SizedBox(height: AppSpacing.space6),
        Text(
          'Tap to stop',
          style: context.text.metadata,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Which meal is showing at [t], the animation's progress from 0 to 1.
  ///
  /// The suspense lives in this function. Three stretches, matching
  /// [AppRouletteMotion]:
  ///
  /// * **wind-up** — nothing moves. A card that starts flying on the same frame
  ///   as the tap reads as a glitch rather than as a decision beginning.
  /// * **fast cycle** — linear, one meal every
  ///   [AppRouletteMotion.cyclePerMeal]. Linear on purpose: an eased fast phase
  ///   would already be slowing down, and there would be nothing left to slow.
  /// * **decelerate** — [AppMotion.curveSpinDecelerate] over a handful of final
  ///   cards, so the gaps visibly stretch. This is the whole effect; the rest is
  ///   setup.
  static int _mealIndex(double t, int poolSize) {
    const double windUp = 0.0909; // 200 / 2200
    const double fast = 0.5455; //  1200 / 2200
    final double fastTicks =
        AppRouletteMotion.fastCycle.inMilliseconds /
        AppRouletteMotion.cyclePerMeal.inMilliseconds;

    // Deliberately few. The deceleration has to be legible as *cards*, and
    // twenty of them easing out is a blur that stops rather than a slowdown.
    const double slowTicks = 6;

    final double ticks;
    if (t <= windUp) {
      ticks = 0;
    } else if (t <= windUp + fast) {
      ticks = ((t - windUp) / fast) * fastTicks;
    } else {
      final double eased = AppMotion.curveSpinDecelerate.transform(
        ((t - windUp - fast) / (1 - windUp - fast)).clamp(0, 1),
      );
      ticks = fastTicks + eased * slowTicks;
    }

    return ticks.floor() % poolSize;
  }
}

/// One meal, for the fraction of a second it is on screen.
///
/// The cuisine colour is what makes this read as cycling. Text alone changing at
/// 80 ms is a flicker; a card whose whole tint changes is a card being replaced.
class _MealFlash extends StatelessWidget {
  const _MealFlash({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final AppAccent accent = context.colors.accentFor(meal.cuisine.label);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.background,
        borderRadius: AppRadius.borderXxxl,
        boxShadow: context.shadows.lg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              meal.cuisine.label.toUpperCase(),
              style: context.text.overline.copyWith(color: accent.foreground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              meal.name,
              style: context.text.displayMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              AppFormat.metadata(<String?>[
                AppFormat.cookingTime(meal.cookingTimeMinutes),
                AppFormat.peso(meal.costPerServing),
              ]),
              style: context.text.metadata,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card before there is anything to put in it.
class _WindUpCard extends StatelessWidget {
  const _WindUpCard();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderXxxl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space7),
        child: Center(
          child: Text(
            'Looking at what you can cook…',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Nothing to offer — a designed screen, not an error.
///
/// docs/USER_FLOWS.md §7 requires it to name the blocking constraint and offer
/// the one thing that would open it up. With no filters yet, the constraint is
/// either the session's own history or the reader's hidden meals, and those want
/// different sentences: one is "you have seen everything", the other is "you
/// have hidden everything".
class _NoMatch extends ConsumerWidget {
  const _NoMatch({required this.state});

  final SpinNoMatch state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool exhausted = state.isSessionExhausted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          exhausted ? 'That is everything' : 'Nothing to offer',
          style: context.text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          exhausted
              ? 'You have turned down all '
                    '${state.seenThisSession} of them this time round. '
                    'Start again and they are all back in.'
              : state.hiddenCount > 0
              ? 'Every meal we have is one you hid. '
                    'Bring one back and we can offer it.'
              : 'The catalogue is empty, which is our problem rather than '
                    'yours.',
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space6),
        if (exhausted)
          AppButton.primary(
            label: 'Start again',
            onPressed: () =>
                ref.read(spinControllerProvider.notifier).startOver(),
          )
        else if (state.hiddenCount > 0)
          AppButton.primary(
            label: 'Hidden meals',
            onPressed: () =>
                context.pushNamed(AppRoute.dislikedMeals.routeName),
          ),
        const SizedBox(height: AppSpacing.space3),
        AppButton.tertiary(
          label: 'Back',
          onPressed: () {
            ref.read(spinControllerProvider.notifier).reset();
            context.goNamed(AppRoute.home.routeName);
          },
        ),
      ],
    );
  }
}
