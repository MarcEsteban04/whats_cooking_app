import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// The reel of meals, rolling (docs/design_ui.md §12).
///
/// **A continuous reel, not a slideshow.** The first version showed one card at a
/// time and swapped its contents on a timer, which reads as text being replaced.
/// This scrolls: three cards are on screen at any moment, they move through a
/// fixed window, and the one in the middle is the one being considered. That is
/// the difference between "the app is thinking" and "the app is looking through
/// the food I could eat" — and the second is the thing worth watching.
///
/// The offset is a **continuous double** rather than an index. A whole-number
/// index would step, and stepping is what made the old version flicker; a
/// fractional offset means the cards are always mid-travel, so the deceleration
/// is visible as motion slowing rather than as pauses getting longer.
///
/// Not a `ListWheelScrollView`, deliberately. Its perspective transform is the
/// one thing design_ui §12 rules out — "do not make it look like a casino slot
/// machine" — and it also insists on owning the scroll physics, which is exactly
/// what has to be driven by the spin's own curve here.
class MealReel extends StatelessWidget {
  const MealReel({
    required this.offset,
    required this.pool,
    required this.settledIndex,
    super.key,
  });

  /// How far the reel has travelled, in cards. Fractional between cards.
  final double offset;

  /// What is on the reel. Cycled endlessly by wrapping the index.
  final List<Meal> pool;

  /// Set once the reel has stopped, so the landed card can be lifted out of the
  /// row of neighbours it was travelling with.
  final int? settledIndex;

  @override
  Widget build(BuildContext context) {
    if (pool.isEmpty) {
      return const _ReelPlaceholder();
    }

    return SizedBox(
      height: _windowHeight,
      child: ClipRRect(
        borderRadius: AppRadius.borderXxxl,
        child: Stack(
          children: <Widget>[
            // The cards, positioned by how far they are from the window's centre.
            //
            // Two either side of the centre are built and no more: the ones
            // beyond that are off-window, and building the whole pool on every
            // frame of a 2.2-second animation is how a spin drops frames on the
            // device that needs it least.
            for (int step = -2; step <= 2; step++) _positioned(context, step),

            // The window's own edges. A reel is only legible as a reel if it
            // looks like something is passing behind an opening, and that is
            // what the fade does — without it the cards look like they are
            // being cut off, which reads as a bug.
            const Positioned.fill(child: IgnorePointer(child: _EdgeFade())),
          ],
        ),
      ),
    );
  }

  /// One card, placed by its distance from the centre of the window.
  Widget _positioned(BuildContext context, int step) {
    final int slot = offset.floor() + step;
    final double distance = slot - offset;

    // Off-window. Cheaper to skip than to paint at zero opacity.
    if (distance.abs() > 1.6) {
      return const SizedBox.shrink();
    }

    final Meal meal = pool[slot % pool.length];
    final double from = distance.abs();

    // Neighbours are smaller, dimmer and pushed back. All three fall off
    // together so that the centre card is unambiguous even mid-travel — at any
    // frame there is exactly one card the eye reads as "this one".
    final double scale = 1 - (from * 0.14).clamp(0.0, 0.42);
    final double opacity = (1 - from * 0.55).clamp(0.0, 1.0);

    final bool isSettled = settledIndex != null && slot == settledIndex;

    return Positioned(
      left: 0,
      right: 0,
      top: _windowHeight / 2 - _cardHeight / 2 + distance * _cardExtent,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: _ReelCard(meal: meal, isSettled: isSettled),
          ),
        ),
      ),
    );
  }

  /// The visible opening. Three cards' worth, so a neighbour is always partly in
  /// view — a one-card window would hide the reel and leave a slideshow again.
  static const double _windowHeight = 300;

  /// The card itself, and the distance between two card centres. The gap is what
  /// keeps the neighbours from touching the one being read.
  static const double _cardHeight = 156;
  static const double _cardExtent = _cardHeight + AppSpacing.space3;
}

/// One meal on the reel.
///
/// The cuisine tint is doing real work: at speed, what the eye tracks is the
/// block of colour changing, not the letters. Text alone at 80 ms a card is a
/// flicker; a card whose whole surface changes is a card being replaced.
class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.meal, required this.isSettled});

  final Meal meal;

  /// The reel has stopped and this is the one it stopped on.
  final bool isSettled;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(meal.cuisine.label);

    return AnimatedContainer(
      duration: AppRouletteMotion.reveal,
      curve: AppMotion.curveCelebrate,
      height: MealReel._cardHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: accent.background,
        borderRadius: AppRadius.borderXxl,
        // The landed card takes an ink outline rather than a colour change: the
        // palette has one accent and it belongs to the SPIN button, so emphasis
        // here has to come from weight (docs/DESIGN_SYSTEM.md §2.2).
        border: Border.all(
          color: isSettled ? colors.textPrimary : Colors.transparent,
          width: isSettled ? 2 : 0,
        ),
        boxShadow: isSettled ? context.shadows.xl : context.shadows.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            meal.cuisine.label.toUpperCase(),
            style: context.text.overline.copyWith(color: accent.foreground),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            meal.name,
            style: context.text.headlineMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            AppFormat.metadata(<String?>[
              AppFormat.cookingTime(meal.cookingTimeMinutes),
              '${AppFormat.peso(meal.costPerServing)} a head',
            ]),
            style: context.text.metadata,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Fades the top and bottom of the window so cards read as passing behind it.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade();

  @override
  Widget build(BuildContext context) {
    final Color ground = context.colors.background;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[ground, ground.withValues(alpha: 0), ground],
          // Tight bands at the very edges. A wide fade would dim the neighbours
          // that make the reel readable as a reel.
          stops: const <double>[0, 0.28, 1],
        ),
      ),
    );
  }
}

/// The window before the pool has arrived.
///
/// Sized like the reel so nothing shifts when the cards appear — a window that
/// grows at the moment the first card lands looks like a mistake being
/// corrected.
class _ReelPlaceholder extends StatelessWidget {
  const _ReelPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return SizedBox(
      height: MealReel._windowHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: AppRadius.borderXxl,
          ),
          child: SizedBox(
            height: MealReel._cardHeight,
            width: double.infinity,
            child: Center(
              child: Text(
                'Looking at what you can cook…',
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the reel is, at a given point in the spin.
///
/// Split out from the widget because it is the whole feel of the interaction and
/// it is worth being able to read on its own. Three stretches, matching
/// [AppRouletteMotion]:
///
/// * **wind-up** — nothing moves. A reel that starts flying on the same frame as
///   the tap reads as a glitch rather than as a decision beginning.
/// * **fast cycle** — linear, one card every [AppRouletteMotion.cyclePerMeal].
///   Linear on purpose: an eased fast phase is already slowing down, and then
///   there is nothing left to slow.
/// * **decelerate** — [AppMotion.curveSpinDecelerate] over a handful of final
///   cards, so the travel visibly stretches out. This is the suspense; the rest
///   is setup.
///
/// The total lands on a whole card by construction — 15 fast plus 5 slow — which
/// is what lets the spin screen plant the winner at [reelSettleIndex] and know
/// the card the reel rests on *is* the pick. Nothing snaps at the end, because
/// there is nothing left to snap to.
double reelOffsetAt(double t) {
  const double windUpShare = 0.0909; //  200 / 2200
  const double fastShare = 0.5455; // 1200 / 2200

  final double fastCards =
      AppRouletteMotion.fastCycle.inMilliseconds /
      AppRouletteMotion.cyclePerMeal.inMilliseconds;

  // Deliberately few. The deceleration has to be legible as *cards*, and twenty
  // of them easing out is a blur that stops rather than a reel slowing down.
  const double slowCards = 5;

  // **Anticipation** (Sprint 34). The wind-up phase used to return a flat zero,
  // which spent the first 200 ms of the product's signature moment showing a
  // motionless card — the reader's tap landing on nothing. Now the reel draws
  // *backwards* first, the way a hand pulls a wheel back before letting go, and
  // arrives at the fast phase already moving forward.
  //
  // A half sine, so it is zero at both ends of the wind-up and continuous into
  // what follows: a linear pull-back would hit the fast phase with a corner in
  // the motion, and a corner reads as a dropped frame.
  if (t <= windUpShare) {
    return -_anticipation * sin(pi * (t / windUpShare));
  }
  if (t <= windUpShare + fastShare) {
    return ((t - windUpShare) / fastShare) * fastCards;
  }

  final double eased = AppMotion.curveSpinDecelerate.transform(
    ((t - windUpShare - fastShare) / (1 - windUpShare - fastShare)).clamp(
      0.0,
      1.0,
    ),
  );
  return fastCards + eased * slowCards;
}

/// How many cards the reel travels in total, for choosing where the winner sits.
///
/// The spin screen plants the winning meal at this offset in the pool so that the
/// card the reel comes to rest on *is* the pick — rather than the reel stopping
/// wherever it likes and the result screen showing something else, which is the
/// version of this interaction that feels rigged.
double get reelTotalTravel => reelOffsetAt(1);

/// The nearest whole card to [offset] — where a stopped reel should settle.
int reelSettleIndex(double offset) => offset.round();

/// How far back the reel pulls before it starts, in cards.
///
/// A sixth of a card. Enough to be felt as a load rather than seen as a glitch —
/// at this size the neighbouring card above only just begins to enter the window,
/// which is the point: the eye registers the direction, not the distance.
const double _anticipation = 0.17;
