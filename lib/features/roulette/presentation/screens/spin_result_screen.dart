import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/analytics/analytics.dart';
import 'package:whats_cooking/core/domain/meal_moment.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
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
        // Real text, not a bar — it keeps the reader oriented while the card
        // fills in. Neutral, because the meal is not known yet and the category
        // is what decides the wording: guessing "tonight's" here would flicker
        // to "BREAKFAST PICK" a moment later.
        Text(
          'YOUR PICK',
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

    // **Anchored, not floated.** This was one centred column, which on a tall
    // phone left a couple of hundred pixels of nothing above the overline and the
    // same below the last button — the payoff of the whole app arriving in the
    // middle of an empty page. The card now sits high, the actions sit at the
    // bottom where a thumb is, and the slack goes between them instead of around
    // everything.
    //
    // Scrollable rather than flexed, because a three-line meal name plus a
    // reason, a kitchen line and an error banner genuinely can exceed a short
    // screen — and the one thing worse than empty space is a clipped button.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: _spaceAbove),
                Text(
                  // From the meal's own category rather than from the filter, so
                  // it is right on a deep link and on a spin nobody narrowed.
                  meal.category.pickOverline,
                  style: context.text.overline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space4),
                _PickCard(meal: meal, isDecided: false),

                // Why this one — design_ui §13's context line, whose own example
                // is "⭐ Loved by both of you".
                //
                // **Framed as something said, not as a caption.** It was grey
                // `metadata` centred under the card, which is where an image
                // credit goes — and this is the single most valuable sentence on
                // the screen, because a weighted engine that cannot say *why* is
                // indistinguishable from a random one. Now it is attributed: a
                // mark, a quiet surface, and body type somebody will actually
                // read.
                if (_reason case final String reason) ...<Widget>[
                  const SizedBox(height: AppSpacing.space4),
                  _Reason(reason: reason),
                ],

                // What the kitchen is short of (Sprint 41).
                //
                // Its own line rather than folded into the reason above, because
                // the two say different things: the reason is why this meal was
                // chosen, and this is what standing up and cooking it would take.
                // Somebody deciding whether to accept wants both, and the second
                // one is the difference between yes and a trip to the shop.
                if (_kitchenLine case final String line) ...<Widget>[
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    line,
                    style: context.text.metadata,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_failure case final AppException problem) ...<Widget>[
                  const SizedBox(height: AppSpacing.space4),
                  // Inline rather than a snackbar. The tap failed and the meal is
                  // still undecided, so the message belongs beside the button
                  // that has to be pressed again.
                  InlineErrorBanner(
                    message: problem.displayMessage ?? problem.message,
                    onRetry: _accept,
                  ),
                ],
                const Spacer(flex: _spaceBelow),
                const SizedBox(height: AppSpacing.space6),
                ..._pickActions(context, meal),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The slack, split unevenly on purpose.
  ///
  /// Two parts above the card to one below, so the card lands a little above
  /// centre — where a title page puts its title — and the actions keep a stable
  /// distance from the bottom edge rather than drifting with the name's length.
  static const int _spaceAbove = 2;
  static const int _spaceBelow = 3;

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
      // **Equal weights on one row.** This paired an outlined pill with a bare
      // text button at equal widths, which read as one button and one gap — the
      // eye could not tell whether "Details" was disabled or decoration. Two
      // secondary buttons make it a choice between two things, which is what it
      // is: spin again, or go and look properly.
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
            child: AppButton.secondary(
              label: 'Details',
              leadingIcon: AppIcons.forward,
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
      const SizedBox(height: AppSpacing.space3),
      // The way out, and the only tertiary on the screen — which is what makes it
      // legible as the quiet option rather than as a fourth button competing with
      // the other three.
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space5,
      ),
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
              // Tighter than the display default, which was built for one-line
              // headings: a three-line meal name at the default leading opens a
              // visible gap between its lines and stops reading as one title.
              height: 1.05,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (isDecided) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              // Follows the clock like everything else now. It said "tonight" at
              // every hour, which on a breakfast pick was two lies in one line.
              "You're eating this ${MealMoment.current.phrase}.",
              style: context.text.bodyMedium.copyWith(
                color: context.colors.textOnInverse,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.space6),

          // **Three figures behind hairlines, not three floating pills.**
          //
          // The pills were a `Wrap`, so on a normal phone they broke two-and-one
          // and left "2 servings" centred on a row of its own — which reads as a
          // layout accident rather than a decision. They were also this screen
          // inventing its own vocabulary: every panel in this app states its
          // numbers as a divided trio, so three lozenges here made the payoff
          // look like a different product's screen.
          _PickStats(meal: meal, isDecided: isDecided, accent: accent),
        ],
      ),
    );
  }
}

/// The card's cost, time and servings — divided, not floating.
///
/// Its own widget rather than `StatTrio`, and that is the one piece of
/// duplication worth having here: `StatTrio` reads its label and divider colours
/// from the theme, and this card **inverts to near-black** on acceptance, where
/// theme-derived greys vanish. Parameterising the shared widget for one caller's
/// inversion would put a colour override into every dashboard that does not want
/// one.
class _PickStats extends StatelessWidget {
  const _PickStats({
    required this.meal,
    required this.isDecided,
    required this.accent,
  });

  final Meal meal;
  final bool isDecided;
  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // Explicit rather than themed, so the whole block survives the flip to ink.
    // `accent.foreground` is the pastel's paired ink, which the overline above
    // already uses — so the card has one ink rather than two.
    final Color figure = isDecided ? colors.textOnInverse : colors.textPrimary;
    final Color label = isDecided
        ? colors.textOnInverse.withValues(alpha: _quiet)
        : accent.foreground;
    final Color divider = isDecided
        ? colors.textOnInverse.withValues(alpha: _hairline)
        : accent.foreground.withValues(alpha: _hairline);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, (String, String) column) in _columns.indexed)
            ...<Widget>[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                  ),
                  child: SizedBox(width: 1, child: ColoredBox(color: divider)),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      column.$1,
                      style: context.text.overline.copyWith(color: label),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      column.$2,
                      style: context.text.titleMedium.copyWith(color: figure),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// Label over figure, which is the order every other panel uses — the caps line
  /// says what the number is before the eye reaches it.
  List<(String, String)> get _columns => <(String, String)>[
    ('A HEAD', AppFormat.peso(meal.costPerServing)),
    ('READY IN', AppFormat.cookingTime(meal.cookingTimeMinutes)),
    ('SERVES', '${meal.servings}'),
  ];

  static const double _quiet = 0.7;
  static const double _hairline = 0.2;
}

/// Why this meal, attributed.
///
/// **The best sentence on the screen was styled like a photo credit.** It was
/// grey `metadata`, centred, floating under the card — and it is the one thing
/// that distinguishes a recommendation from a coin toss. When the assistant chose,
/// it is genuinely somebody's reasoning ("you have the chicken and have not had it
/// in weeks"); when the engine chose, it is the scorer explaining its own
/// highlight. Either way it deserves to look said rather than annotated.
///
/// A quiet inset surface with a mark, not a speech bubble: a chat bubble here
/// would imply a conversation to reply to, and there is none on this screen.
class _Reason extends StatelessWidget {
  const _Reason({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderXl,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              // Nudged to sit on the first line's baseline rather than its box.
              padding: const EdgeInsets.only(top: _markDrop),
              child: Icon(
                AppIcons.assistant,
                size: AppIconSize.xs,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                // Sentence-cased. The model answers in lower case more often than
                // not, and a lower-case opening under a display-size name reads as
                // a fragment rather than a sentence.
                AppFormat.sentenceCase(reason),
                style: context.text.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _markDrop = 2;
}
