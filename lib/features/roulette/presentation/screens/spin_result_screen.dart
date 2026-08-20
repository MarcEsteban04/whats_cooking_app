import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_detail_controller.dart';
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
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends ConsumerStatefulWidget {
  const _Result({required this.meal});

  final Meal meal;

  @override
  ConsumerState<_Result> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_Result> {
  /// Set by "This is it".
  ///
  /// The celebration replaces this screen rather than pushing another route,
  /// because it is the same meal at the end of the same sentence — and a route
  /// would give it a back button leading to a decision already made.
  bool _isDecided = false;

  void _accept() {
    HapticFeedback.mediumImpact();

    // Ends the session, so the next spin starts from the whole catalogue.
    // Nothing is written anywhere yet: the meal becomes a `meal_history` row in
    // Sprint 31, and `/home/decided/:historyId` takes over from this state when
    // there is an id to put in it.
    ref.read(spinControllerProvider.notifier).accept();
    setState(() => _isDecided = true);
  }

  @override
  Widget build(BuildContext context) {
    final Meal meal = widget.meal;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _isDecided ? 'DINNER DECIDED' : "TONIGHT'S PICK",
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space4),
        _PickCard(meal: meal, isDecided: _isDecided),
        const SizedBox(height: AppSpacing.space6),
        if (_isDecided)
          ..._decidedActions(context)
        else
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
        onPressed: _accept,
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
              onPressed: () => context.goNamed(AppRoute.roulette.routeName),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: AppButton.tertiary(
              label: 'Details',
              onPressed: () => context.pushNamed(
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
          onPressed: () {
            ref.read(spinControllerProvider.notifier).reset();
            context.goNamed(AppRoute.home.routeName);
          },
        ),
      ),
    ];
  }

  List<Widget> _decidedActions(BuildContext context) {
    return <Widget>[
      AppButton.primary(
        label: 'Done',
        size: AppButtonSize.large,
        onPressed: () => context.goNamed(AppRoute.home.routeName),
      ),
      const SizedBox(height: AppSpacing.space3),
      Text(
        // Said plainly rather than implied. Sprint 31 is what makes this
        // sentence untrue, and until then claiming a saved decision would be
        // the one lie a decision screen cannot afford.
        'Not saved anywhere yet — meal history arrives in a later build.',
        style: context.text.metadata,
        textAlign: TextAlign.center,
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
        // The card changes colour on acceptance rather than growing a badge:
        // the whole surface saying "settled" is the celebration §14 asks for,
        // and it costs no confetti library.
        color: isDecided ? context.colors.primaryContainer : accent.background,
        borderRadius: AppRadius.borderXxxl,
        boxShadow: context.shadows.xl,
      ),
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (isDecided) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              "You're eating this tonight.",
              style: context.text.bodyMedium,
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
