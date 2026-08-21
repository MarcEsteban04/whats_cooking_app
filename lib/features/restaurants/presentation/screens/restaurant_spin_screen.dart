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
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant_filters.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_spin_controller.dart';
import 'package:whats_cooking/features/roulette/presentation/widgets/meal_reel.dart';

/// The night-out spin (Sprint 46).
///
/// **The same reel, the same timing, the same haptics.** Not a copy — literally the
/// same widget and the same `reelOffsetAt` curve, because the animation is the
/// product's signature moment and two of them would drift apart the first time
/// either was touched. What differs is what the cards say and what the pool is.
///
/// The structure mirrors `SpinScreen` exactly, down to arming the reel rather than
/// starting it: the reel begins when there are cards, with a two-second backstop,
/// because an animation with nothing to animate is a stall with a spinner's
/// manners.
class RestaurantSpinScreen extends ConsumerStatefulWidget {
  const RestaurantSpinScreen({super.key});

  @override
  ConsumerState<RestaurantSpinScreen> createState() =>
      _RestaurantSpinScreenState();
}

class _RestaurantSpinScreenState extends ConsumerState<RestaurantSpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  List<Restaurant>? _reelPool;
  bool _isReelStopped = false;
  bool _hasRevealed = false;
  int _lastTickedCard = 0;

  Timer? _revealTimer;
  Timer? _poolTimer;

  /// Holds the roll while the assistant is still deciding.
  Timer? _graceTimer;

  /// True while the assistant is choosing — `SpinScreen` carries the reasoning.
  /// The engine shortlists, the model picks, and the weighted draw is the
  /// fallback for a rate limit or an outage.
  bool _isAwaitingAssistant = false;

  bool _isReducedMotion = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
            duration:
                AppRouletteMotion.windUp +
                AppRouletteMotion.fastCycle +
                AppRouletteMotion.decelerate,
            vsync: this,
          )
          ..addStatusListener(_onStatus)
          ..addListener(_onTick);

    Future<void>.microtask(() {
      if (mounted) {
        ref.read(restaurantSpinControllerProvider.notifier).spin();
      }
    });

    AppHaptics.spinBegun();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isReelStopped || _controller.isAnimating || _controller.isCompleted) {
      return;
    }

    if (AppMotion.prefersReducedMotion(context)) {
      _isReducedMotion = true;
      _controller.value = 1;
      _isReelStopped = true;
      _scheduleReveal();
      return;
    }

    _poolTimer ??= Timer(_maxPoolWait, _startReel);
  }

  /// [force] is the assistant window closing — see `_isAwaitingAssistant`.
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

    // The card the reel landed on is now the answer — told to the controller so a
    // late assistant reply cannot replace it. See `SpinScreen` for the bug this
    // closes.
    ref.read(restaurantSpinControllerProvider.notifier).lockIn();

    _scheduleReveal();
  }

  void _skip() {
    if (_isReelStopped || !_controller.isAnimating) {
      return;
    }
    _controller.animateTo(1, duration: AppMotion.fast, curve: AppMotion.curveFast);
  }

  void _scheduleReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(AppRouletteMotion.reveal, _maybeReveal);
  }

  /// Goes to the result, once the reel has stopped and the pick has arrived.
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

    if (ref.read(restaurantSpinControllerProvider)
        case RestaurantSpinSettled(:final Restaurant place)) {
      _hasRevealed = true;
      AppHaptics.reveal();
      context.goNamed(
        AppRoute.restaurantResult.routeName,
        pathParameters: <String, String>{'id': place.id},
        extra: place,
      );
    }
  }

  /// Reorders [pool] so the reel's landing slot holds [winner].
  ///
  /// A swap rather than a rotation, for the reason the meal reel gives: only one
  /// card needs to be in the right place, and a swap cannot drop or duplicate an
  /// entry the way a mis-written rotation can.
  List<Restaurant> _plant(List<Restaurant> pool, Restaurant winner) {
    final List<Restaurant> reel = List<Restaurant>.of(pool);
    final int target = reelSettleIndex(reelTotalTravel) % reel.length;
    final int current = reel.indexWhere(
      (Restaurant place) => place.id == winner.id,
    );

    if (current < 0) {
      reel[target] = winner;
      return reel;
    }

    reel[current] = reel[target];
    reel[target] = winner;
    return reel;
  }

  @override
  Widget build(BuildContext context) {
    final RestaurantSpinState state = ref.watch(
      restaurantSpinControllerProvider,
    );

    ref.listen(restaurantSpinControllerProvider, (
      RestaurantSpinState? _,
      RestaurantSpinState next,
    ) {
      if (next case RestaurantSpinSettled(
        :final Restaurant place,
        :final List<Restaurant> pool,
      )) {
        if (_reelPool == null) {
          setState(() => _reelPool = _plant(pool, place));
        }

        // The assistant's window sits *before* the roll, not after the stop —
        // `SpinScreen` carries the reasoning. Held here so the reel rolls to the
        // final answer, and rolled anyway once the timer is up.
        if (next case RestaurantSpinSettled(isAwaitingAssistant: true)) {
          _isAwaitingAssistant = true;
          _graceTimer ??= Timer(
            _assistantGrace,
            () => _startReel(force: true),
          );
        } else {
          _isAwaitingAssistant = false;
          _graceTimer?.cancel();
          _graceTimer = null;
          _startReel(force: true);
        }

        _maybeReveal();
        return;
      }

      if (next is RestaurantSpinNoMatch || next is RestaurantSpinFailed) {
        _controller.stop();
        if (next is RestaurantSpinNoMatch) {
          AppHaptics.nothingFound();
        }
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppLayout.screenMargin),
                child: switch (state) {
                  RestaurantSpinFailed(:final failure) => ErrorState(
                    kind: failure.errorStateKind,
                    body: failure.displayMessage,
                    errorCode: failure.supportCode,
                    onRetry: failure.shouldOfferRetry
                        ? () => ref
                              .read(restaurantSpinControllerProvider.notifier)
                              .spin()
                        : null,
                  ),
                  final RestaurantSpinNoMatch noMatch => _NoMatch(
                    state: noMatch,
                  ),
                  _ => _Spinning(
                    animation: _controller,
                    pool: _reelPool ?? const <Restaurant>[],
                    isStopped: _isReelStopped,
                    isAsking:
                        state is RestaurantSpinSettled &&
                        state.isAwaitingAssistant,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Duration _maxPoolWait = Duration(seconds: 2);

  /// How long the reveal waits for the assistant (Sprint 50).
  ///
  /// The same second and a half the meal roulette holds. Long enough that most
  /// answers land, short enough that the worst case is under four seconds.
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
  final List<Restaurant> pool;
  final bool isStopped;

  /// Whether the assistant is still deciding (Sprint 50).
  final bool isAsking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          switch ((pool.isEmpty, isStopped, isAsking)) {
            (true, _, _) => 'LOOKING AT WHERE WE COULD GO',
            // Says what the pause is, on the one screen where a pause without a
            // reason reads as a stall.
            (false, true, true) => 'ASKING THE ASSISTANT',
            (false, true, false) => 'ALMOST',
            (false, false, _) => '${pool.length} PLACES ON THE LIST',
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
              // A restaurant's metadata line is cost and distance, where a meal's
              // is time and cost. Same reel, different sentence.
              pool: <ReelEntry>[
                for (final Restaurant place in pool)
                  ReelEntry(
                    id: place.id,
                    overline: place.cuisine.label,
                    title: place.name,
                    metadata: AppFormat.metadata(<String?>[
                      '${AppFormat.peso(place.costPerHead.round())} a head',
                      place.proximity.label.toLowerCase(),
                    ]),
                    tint: place.cuisine.label,
                  ),
              ],
              settledIndex: isStopped ? reelSettleIndex(offset) : null,
            );
          },
        ),
        const SizedBox(height: AppSpacing.space5),
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

/// Nothing to offer — a designed screen, not an error.
///
/// Four branches, like the meal version, because they have four different fixes:
/// an empty list wants a place added, an exhausted session wants starting again,
/// too-recent visits want time or a wider window, and a filtered-out pool wants one
/// filter dropped — with the number it would open.
class _NoMatch extends ConsumerWidget {
  const _NoMatch({required this.state});

  final RestaurantSpinNoMatch state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(_title, style: context.text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.space3),
        Text(_body, style: context.text.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.space6),
        ..._actions(context, ref),
      ],
    );
  }

  String get _title {
    if (state.isEmptyList) {
      return 'No places on the list';
    }
    if (state.isAllTooRecent) {
      return 'You have been to all of them';
    }
    if (state.isSessionExhausted) {
      return 'That is everywhere';
    }
    if (state.isFilteredOut) {
      return 'Nothing fits';
    }
    return 'Nothing to offer';
  }

  String get _body {
    if (state.isEmptyList) {
      return 'Add the places you actually go and the app can pick one.';
    }
    if (state.isAllTooRecent) {
      final int blocked = state.blockedByRecency;
      return 'All $blocked ${blocked == 1 ? 'place' : 'places'} that fit are '
          'somewhere you went in the last week. Give it a few days, or cook '
          'instead.';
    }
    if (state.blockingSentence case final String sentence) {
      return sentence;
    }
    if (state.isSessionExhausted) {
      return 'You have turned down all ${state.seenThisSession} of them this '
          'time round. Start again and they are all back in.';
    }
    return 'Nothing on the list matches tonight.';
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    return <Widget>[
      if (state.isEmptyList)
        AppButton.primary(
          label: 'Add a place',
          leadingIcon: AppIcons.add,
          onPressed: () =>
              context.pushNamed(AppRoute.restaurantCreate.routeName),
        )
      else if (state.mostRelaxable case final RestaurantConstraint constraint)
        AppButton.primary(
          label: 'Drop ${constraint.label}',
          onPressed: () => ref
              .read(restaurantSpinControllerProvider.notifier)
              .relaxAndSpin(constraint),
        )
      else if (state.isSessionExhausted)
        AppButton.primary(
          label: 'Start again',
          onPressed: () => ref
              .read(restaurantSpinControllerProvider.notifier)
              .startOver(),
        ),

      if (state.mostRelaxable != null) ...<Widget>[
        const SizedBox(height: AppSpacing.space2),
        Text(
          '${state.wouldOpen} ${state.wouldOpen == 1 ? 'place' : 'places'} '
          'would come back.',
          style: context.text.metadata,
          textAlign: TextAlign.center,
        ),
      ],

      const SizedBox(height: AppSpacing.space3),
      // Always offered, because the other answer to this question is always
      // available — and on a night when nowhere fits, cooking is the answer.
      AppButton.secondary(
        label: 'Cook instead',
        leadingIcon: AppIcons.spin,
        onPressed: () {
          ref.read(restaurantSpinControllerProvider.notifier).reset();
          context.goNamed(AppRoute.roulette.routeName);
        },
      ),

      const SizedBox(height: AppSpacing.space2),
      AppButton.tertiary(
        label: 'Back',
        size: AppButtonSize.small,
        onPressed: () {
          ref.read(restaurantSpinControllerProvider.notifier).reset();
          context.goNamed(AppRoute.home.routeName);
        },
      ),
    ];
  }
}
