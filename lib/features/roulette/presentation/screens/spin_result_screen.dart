import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/analytics/analytics.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_detail_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_controller.dart';

/// The payoff (docs/design_ui.md §13).
///
/// "The result should feel like a reward." What makes it one is that it is
/// **self-sufficient**: name, cost, time and servings without scrolling, which is
/// US-B-09's acceptance criterion word for word. Somebody standing in their
/// kitchen has to be able to act on this screen without touching it again.
///
/// The meal arrives through the route as `extra` — the spin already had it, and
/// making the reward wait on a round trip would undo the point of fetching
/// during the animation. The id in the path is what makes the screen survive a
/// deep link or a restart, where it falls back to fetching.
///
/// Two actions, and the asymmetry is deliberate. **This is it** is the loud one:
/// deciding is the whole product, and the app should look pleased. **Try again**
/// is quiet but not hidden — US-B-04 needs it one tap away, and it excludes this
/// meal for the rest of the session so a re-spin cannot offer the same thing
/// twice.
class SpinResultScreen extends ConsumerWidget {
  const SpinResultScreen({required this.mealId, this.pick, super.key});

  final String mealId;

  /// The meal the spin landed on, handed over by the route.
  final Meal? pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only consulted when the route arrived without a meal — a deep link, or a
    // restart on this screen. `pick` is the normal path.
    final AsyncValue<Meal>? fetched = pick == null
        ? ref.watch(mealDetailProvider(mealId))
        : null;

    final Meal? meal = pick ?? fetched?.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.screenMargin),
              child: switch ((meal, fetched)) {
                (final Meal found, _) => _Result(meal: found),
                (null, AsyncError<Meal>(:final Object error)) => ErrorState(
                  kind: error is AppException
                      ? error.errorStateKind
                      : ErrorStateKind.unknown,
                  body: error is AppException ? error.displayMessage : null,
                  onRetry: () => ref.invalidate(mealDetailProvider(mealId)),
                ),
                _ => const _ResultLoading(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The result, before the meal has arrived.
///
/// Only ever seen on the paths where the pick was *not* handed over — a deep link
/// into a result, or a restart on this screen — because the normal spin passes the
/// meal through the route and has nothing to wait for.
///
/// A shape rather than a spinner, and the shape is [_PickCard]'s: docs/COMPONENTS
/// on skeletons is blunt about why — "a skeleton that doesn't match its content is
/// worse than none". A centred spinner on this screen was worse than none twice
/// over, because it also threw away the one thing the reader already knows, which
/// is that a result is coming.
class _ResultLoading extends StatelessWidget {
  const _ResultLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Real text, not a bar. The overline is the same on every result, so
        // there is nothing to load and no reason to grey it out — and it keeps
        // the reader oriented while the card fills in.
        Text(
          "TONIGHT'S PICK",
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.borderXxxl,
            boxShadow: context.shadows.xl,
          ),
          child: Padding(
            // The card's own padding, so nothing moves when the meal lands.
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              children: <Widget>[
                const AppSkeleton.textLine(widthFactor: 0.3),
                const SizedBox(height: AppSpacing.space4),
                // Two lines at display height, matching the name's own two-line
                // allowance.
                const AppSkeleton(height: _titleLine),
                const SizedBox(height: AppSpacing.space2),
                const Align(
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    child: AppSkeleton(height: _titleLine),
                  ),
                ),
                const SizedBox(height: AppSpacing.space5),
                // The three metadata pills, as three pills.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space2,
                  children: <Widget>[
                    for (int index = 0; index < 3; index++)
                      const AppSkeleton(
                        width: _pillWidth,
                        height: _pillHeight,
                        borderRadius: AppRadius.borderFull,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const double _titleLine = 34;
  static const double _pillWidth = 86;
  static const double _pillHeight = 30;
}

class _Result extends ConsumerStatefulWidget {
  const _Result({required this.meal});

  final Meal meal;

  @override
  ConsumerState<_Result> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_Result> {
  /// True while the history row is being written.
  ///
  /// The button holds its width and shows a spinner rather than the screen
  /// changing: accepting is a write now, and the reader should not see a
  /// celebration that has not been saved yet.
  bool _isSaving = false;

  AppException? _failure;

  /// Records the decision, then hands over to the decided screen (Sprint 31).
  ///
  /// **Navigates rather than swapping state.** Until this sprint the celebration
  /// was a flag on this widget, because there was nothing to point a route at.
  /// Now there is a `meal_history` row, so the decision has an id — which means
  /// it survives a restart, can be reopened from the history list, and is the
  /// same screen either way.
  ///
  /// The session is cleared *after* the write succeeds. Clearing first and then
  /// failing would leave somebody with no decision and no exclusions, so a
  /// re-spin could offer the meal they just tried to accept.
  Future<void> _accept() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    try {
      final MealHistoryEntry entry = await ref
          .read(mealHistoryRepositoryProvider)
          .record(meal: widget.meal);

      // **Time to Decision closes here** (docs/ARCHITECTURE.md §10), and it is
      // recorded *after* the write and *before* the session is cleared. After,
      // because a decision that failed to save is not a decision and would
      // flatter the metric; before, because `accept()` resets the spin count the
      // event carries.
      ref.read(analyticsProvider).mealAccepted(
        mealId: widget.meal.id,
        spinCount: ref.read(spinControllerProvider.notifier).spinsThisSession,
      );

      // Whatever the kitchen is short of goes on the shopping list
      // (Sprint 43). **After the history write and not awaited before it**: the
      // decision is the thing that must succeed, and a shopping list that failed
      // to fill in is a minor annoyance where a dinner that failed to record is
      // the product not working. A failure here is swallowed on purpose — the
      // list is one tap away and visibly short, which is a better error message
      // than a banner on a celebration.
      final (int added, _) = await ref
          .read(groceryControllerProvider.notifier)
          .addMissingForMeal(widget.meal.id);

      ref.read(spinControllerProvider.notifier).accept();

      // The list is now wrong, and the screen that shows it is one tap away.
      ref.invalidate(mealHistoryProvider);

      if (!mounted) {
        return;
      }
      AppHaptics.decided();
      context.goNamed(
        AppRoute.decided.routeName,
        pathParameters: <String, String>{'historyId': entry.id},
        // How many things went on the shopping list, so the decided screen can
        // say so without asking again. Passed rather than re-derived: the count
        // is the difference between two states the list itself cannot tell apart
        // — "nothing was needed" and "nothing was added".
        extra: added,
      );
    } on Object catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _failure = ErrorMapper.map(error, stackTrace);
      });
    }
  }

  /// Turns this meal down and asks for another.
  ///
  /// The rejection is recorded here rather than on the next `spin_started`,
  /// because they are not the same event: a reader can leave by "Not now" or by
  /// the back gesture, and counting those as rejections would make the ratio the
  /// engine is judged on quietly wrong. This button is the only place somebody
  /// says *no, another one*.
  void _rejectAndRespin() {
    ref.read(analyticsProvider).record(
      MealRejected(
        mealId: widget.meal.id,
        spinCount: ref.read(spinControllerProvider.notifier).spinsThisSession,
      ),
    );
    context.goNamed(AppRoute.roulette.routeName);
  }

  /// What the kitchen already covers, in a sentence (Sprint 41).
  ///
  /// Says nothing at all rather than "0% available" when the pantry is empty or
  /// the match could not be computed. A result screen that reports on a fridge
  /// list nobody keeps is a result screen nagging about homework.
  String? get _kitchenLine {
    final PantryMatch? match =
        ref.watch(pantryMatchesProvider).value?[widget.meal.id];

    if (match == null || match.needed == 0) {
      return null;
    }
    if (match.isComplete) {
      return 'Everything for this is already in the kitchen.';
    }
    if (match.shortfallPhrase case final String phrase) {
      // "You have everything but the bay leaves" — the one shape of this
      // sentence that makes somebody more likely to cook rather than less.
      return AppFormat.sentenceCase('you have $phrase.');
    }
    if (match.isMostlyIn) {
      return 'Most of it is in the kitchen — ${match.shortBy} to pick up.';
    }
    // Deliberately silent below the threshold. "You are missing seven things" is
    // true, unhelpful, and reads as an argument against the meal the app just
    // chose.
    return null;
  }

  /// Why the engine chose this, when it has something to say (Sprint 32).
  ///
  /// Matched on the meal id, so a stale state from a previous spin cannot put
  /// last spin's reason under this spin's meal.
  String? get _reason {
    if (ref.watch(spinControllerProvider)
        case SpinSettled(:final Meal meal, :final String? reason)
        when meal.id == widget.meal.id) {
      return reason;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Meal meal = widget.meal;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "TONIGHT'S PICK",
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space4),
        _PickCard(meal: meal, isDecided: false),
        // design_ui §13's context line — its own example is "⭐ Loved by both of
        // you". This is the Sprint 32 version, and it is here because a weighted
        // engine that cannot say *why* it chose something is indistinguishable
        // from a random one, which throws away the whole point of the weighting.
        if (_reason case final String reason) ...<Widget>[
          const SizedBox(height: AppSpacing.space3),
          Text(
            reason,
            style: context.text.metadata,
            textAlign: TextAlign.center,
          ),
        ],

        // What the kitchen is short of (Sprint 41).
        //
        // Its own line rather than folded into the reason above, because the two
        // say different things: the reason is why this meal was chosen, and this
        // is what standing up and cooking it would take. Somebody deciding whether
        // to accept wants both, and the second one is the difference between yes
        // and a trip to the shop.
        if (_kitchenLine case final String line) ...<Widget>[
          const SizedBox(height: AppSpacing.space2),
          Text(
            line,
            style: context.text.metadata,
            textAlign: TextAlign.center,
          ),
        ],
        if (_failure case final AppException problem) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          // Inline rather than a snackbar. The tap failed and the meal is still
          // undecided, so the message belongs beside the button that has to be
          // pressed again.
          InlineErrorBanner(
            message: problem.displayMessage ?? problem.message,
            onRetry: _accept,
          ),
        ],
        const SizedBox(height: AppSpacing.space6),
        ..._pickActions(context, meal),
      ],
    );
  }

  List<Widget> _pickActions(BuildContext context, Meal meal) {
    return <Widget>[
      AppButton.primary(
        label: 'This is it',
        size: AppButtonSize.large,
        leadingIcon: AppIcons.favoriteActive,
        isLoading: _isSaving,
        // Disabled while saving, so a double tap cannot write two dinners. The
        // insert has no uniqueness to lean on, deliberately — a household can
        // eat the same meal twice in a day — so a duplicate would be
        // indistinguishable from the truth.
        onPressed: _isSaving ? null : _accept,
      ),
      const SizedBox(height: AppSpacing.space3),
      Row(
        children: <Widget>[
          Expanded(
            child: AppButton.secondary(
              label: 'Try again',
              leadingIcon: AppIcons.spin,
              // Straight back to the spin screen, which is the only thing that
              // starts a spin. This meal is already in the session's exclusions,
              // so it cannot come back round.
              onPressed: _isSaving ? null : _rejectAndRespin,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: AppButton.tertiary(
              label: 'Details',
              onPressed: _isSaving
                  ? null
                  : () => context.pushNamed(
                      AppRoute.mealDetail.routeName,
                      pathParameters: <String, String>{'id': meal.id},
                      extra: meal,
                    ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.space2),
      Align(
        child: AppButton.tertiary(
          label: 'Not now',
          size: AppButtonSize.small,
          onPressed: _isSaving
              ? null
              : () {
                  ref.read(spinControllerProvider.notifier).reset();
                  context.goNamed(AppRoute.home.routeName);
                },
        ),
      ),
    ];
  }
}

/// The meal, as a reward.
///
/// design_ui §13 puts a large image at the top; there is none, so the name takes
/// that place at display size and the cuisine tint carries what a photograph
/// would have. The metadata pills below it are §13's own list, in §13's order.
class _PickCard extends StatelessWidget {
  const _PickCard({required this.meal, required this.isDecided});

  final Meal meal;
  final bool isDecided;

  @override
  Widget build(BuildContext context) {
    final AppAccent accent = context.colors.accentFor(meal.cuisine.label);

    return AnimatedContainer(
      duration: AppMotion.celebrate,
      curve: AppMotion.curveCelebrate,
      decoration: BoxDecoration(
        // The card **inverts** on acceptance rather than growing a badge: the
        // whole surface flipping to ink is the celebration §14 asks for, and it
        // costs no confetti library. Inversion rather than a tint because the
        // palette has one accent and it belongs to the SPIN button — so the
        // loudest thing left to say is "black", and on a page of pale cards
        // that is loud (docs/DESIGN_SYSTEM.md §2.2).
        color: isDecided ? context.colors.surfaceInverse : accent.background,
        borderRadius: AppRadius.borderXxxl,
        boxShadow: context.shadows.xl,
      ),
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            meal.cuisine.label.toUpperCase(),
            style: context.text.overline.copyWith(
              // The pastel's paired foreground is unreadable once the card
              // inverts, so the inverted state carries its own.
              color: isDecided
                  ? context.colors.textOnInverse
                  : accent.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            meal.name,
            style: context.text.displayMedium.copyWith(
              color: isDecided ? context.colors.textOnInverse : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (isDecided) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              "You're eating this tonight.",
              style: context.text.bodyMedium.copyWith(
                color: context.colors.textOnInverse,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          // US-B-09: cost, time and servings visible without scrolling.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              MetadataPill(
                icon: AppIcons.budget,
                label: '${AppFormat.peso(meal.costPerServing)} a head',
              ),
              MetadataPill(
                icon: AppIcons.cookingTime,
                label: AppFormat.cookingTime(meal.cookingTimeMinutes),
              ),
              MetadataPill(
                icon: AppIcons.servings,
                label: AppFormat.servings(meal.servings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
