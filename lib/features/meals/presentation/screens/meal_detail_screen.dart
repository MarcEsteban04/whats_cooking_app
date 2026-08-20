import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/meal_card.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/auth/presentation/providers/current_user_provider.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_ingredient.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_detail_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/my_meals_controller.dart';

/// One meal, in full (Sprint 23, docs/design_ui.md §17).
///
/// §17 asks for a large edge-to-edge photograph with the name and metadata
/// beneath it. There is no photography — the catalogue ships sixty meals with
/// none — so the screen is built in the dashboard language instead, and the
/// hierarchy §17 actually wanted survives intact:
///
/// * the **name** where the image would have been, at display size;
/// * `Filipino · Easy · 45 min` beneath it, exactly as §17 specifies;
/// * the **cost shown prominently** — §17's words — as the hero figure, with
///   the per-head figure beside the total, because those are different numbers
///   and people compare the second one;
/// * **ingredients as a clean two-column list**, name left and amount right,
///   which is §17's own example rendered as the reference's table;
/// * **large numbered steps**, `01 02 03`, which §17 draws and the reference's
///   numbering style suits.
///
/// The heart and the hide control sit in the top bar beside the back button, as
/// §17 puts the heart over the image. Both wait for the set they read rather
/// than showing an empty state: an unfilled heart on a meal you saved is a lie,
/// and an outline thumb on one you hid is the same lie about a different set.
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({required this.mealId, super.key});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Meal> meal = ref.watch(mealDetailProvider(mealId));

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TopBar(mealId: mealId),
                Expanded(
                  child: switch (meal) {
                    AsyncData<Meal>(:final Meal value) => _Detail(meal: value),
                    AsyncError<Meal>(:final Object error) => _DetailError(
                      failure: error is AppException
                          ? error
                          : const UnknownException(),
                      onRetry: () => ref.invalidate(mealDetailProvider(mealId)),
                    ),
                    _ => const _DetailSkeleton(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular back button, floating on the ground as §17's overlay does.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;
    final bool? isFavorite = ref
        .watch(favoritesControllerProvider)
        .value
        ?.contains(mealId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenMargin,
        AppSpacing.space4,
        AppLayout.screenMargin,
        AppSpacing.space2,
      ),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: context.shadows.xs,
            ),
            child: AppIconButton(
              icon: AppIcons.back,
              semanticLabel: 'Back to meals',
              iconSize: AppIconSize.sm,
              // `pop` rather than a named route: a meal reached from the feed,
              // from a search or from the roulette should return where it came
              // from.
              onPressed: () => context.pop(),
            ),
          ),
          const Spacer(),
          // Hidden until the set has loaded. An empty heart on a meal you saved
          // is a lie, and it would only last until the first read returned.
          if (isFavorite case final bool saved)
            FavoriteButton(
              isFavorite: saved,
              onToggled: (_) => _toggle(context, ref),
            ),
          // Hiding needs the meal's name to name the consequence, so the control
          // waits for the meal rather than opening a dialog with a blank in it.
          if (ref.watch(mealDetailProvider(mealId)).value case final Meal meal)
            _HideButton(meal: meal),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final AppException? failure = await ref
        .read(favoritesControllerProvider.notifier)
        .toggle(mealId);

    if (failure == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.displayMessage ?? failure.message)),
    );
  }
}

/// Hides this meal from everywhere, or brings it back (Sprint 25).
///
/// **Asymmetric on purpose.** Hiding confirms, because it is a lasting exclusion
/// and an accidental tap erodes trust in the engine (docs/USER_FLOWS.md §10).
/// Restoring does not, because putting a meal back among sixty others is not
/// something anyone needs protecting from.
///
/// The dialog names the consequence rather than asking "are you sure?" — the
/// rule `ConfirmationDialog` exists to enforce (docs/COMPONENTS.md §10) — and it
/// names the way back, because an exclusion the user cannot find again is a
/// worse deal than the one they thought they were agreeing to.
class _HideButton extends ConsumerWidget {
  const _HideButton({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? isHidden = ref
        .watch(dislikesControllerProvider)
        .value
        ?.contains(meal.id);

    // Same rule as the heart: nothing rather than a wrong state. An outline
    // thumb on a meal you already hid invites a second tap that does nothing.
    if (isHidden == null) {
      return const SizedBox.shrink();
    }

    return AppIconButton(
      icon: isHidden ? AppIcons.dislikeActive : AppIcons.dislike,
      semanticLabel: isHidden
          ? 'Stop hiding ${meal.name}'
          : 'Hide ${meal.name} from suggestions',
      iconSize: AppIconSize.sm,
      onPressed: () => isHidden ? _restore(context, ref) : _hide(context, ref),
    );
  }

  Future<void> _hide(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: 'Hide ${meal.name}?',
      body:
          "It won't appear in the feed, in search, or in a spin. You can bring "
          'it back from Hidden meals.',
      confirmLabel: 'Hide it',
      icon: AppIcons.dislike,
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final AppException? failure = await ref
        .read(dislikesControllerProvider.notifier)
        .hide(meal.id);

    if (!context.mounted) {
      return;
    }

    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.displayMessage ?? failure.message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${meal.name} won't be suggested again.")),
    );

    // Back to wherever this was opened from, which is where the change is
    // visible: the meal is gone from the list behind it. Staying on the detail
    // page of a meal that no longer appears anywhere is a dead end.
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final AppException? failure = await ref
        .read(dislikesControllerProvider.notifier)
        .restore(meal.id);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? '${meal.name} is back on the menu.'
              : failure.displayMessage ?? failure.message,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return ListView(
      padding: const EdgeInsets.only(
        left: AppLayout.screenMargin,
        right: AppLayout.screenMargin,
        // Clears the floating navigation (docs/COMPONENTS.md §8).
        bottom: AppLayout.scrollBottomPadding,
      ),
      children: <Widget>[
        _Masthead(meal: meal),
        const SizedBox(height: AppSpacing.space5),
        _NumbersPanel(meal: meal),
        if (meal.dietaryTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          _DietaryPanel(tags: meal.dietaryTags),
        ],
        const SizedBox(height: AppSpacing.space4),
        _IngredientsPanel(meal: meal),
        const SizedBox(height: AppSpacing.space4),
        _InstructionsPanel(steps: meal.instructions),
        if (meal.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.space5),
          Text(
            meal.tags.map((String tag) => tag.replaceAll('_', ' ')).join(' · '),
            style: context.text.overline.copyWith(color: colors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
        _OwnerActions(meal: meal),
      ],
    );
  }
}

/// Edit and delete, for a meal this reader wrote (Sprint 26).
///
/// At the foot of the content rather than in the top bar, which already holds a
/// back button, a heart and a hide control. A fifth glyph up there would be a
/// row of guesses; down here they are two labelled tiles in the reference's own
/// action-row shape, and the destructive one is nowhere near the thing you tap
/// to go back.
///
/// Absent entirely on a meal this reader did not write. `update own meals` and
/// `delete own meals` are author-scoped, so offering these on a partner's recipe
/// would be offering an action the server will refuse — and a button that
/// errors teaches people to distrust the ones that work.
class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!meal.isWrittenBy(ref.watch(currentUserIdProvider))) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space4),
      child: DashboardPanel(
        child: DashboardActionRow(
          actions: <DashboardAction>[
            DashboardAction(
              label: 'Edit meal',
              icon: AppIcons.edit,
              onTap: () => context.pushNamed(
                AppRoute.mealEdit.routeName,
                pathParameters: <String, String>{'id': meal.id},
              ),
            ),
            DashboardAction(
              label: 'Delete meal',
              icon: AppIcons.delete,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete ${meal.name}?',
      // Names both halves of the consequence: what goes, and what stays. A
      // household that thinks deleting a recipe erases the record of having
      // eaten it will not delete anything (docs/COMPONENTS.md §10).
      body:
          'The recipe and its ingredients go for good. Meals you have already '
          'eaten stay in your history.',
      confirmLabel: 'Delete',
      icon: AppIcons.delete,
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(mealRepositoryProvider).delete(meal.id);

      // The feed reloads and the owner's list is dropped, rather than either
      // being patched: a deleted row changes what page two contains.
      await ref.read(mealsControllerProvider.notifier).refresh();
      ref.invalidate(myMealsProvider);

      if (!context.mounted) {
        return;
      }
      // Off the detail screen first — it is now showing a meal that no longer
      // exists, and a reload behind it would replace it with a not-found.
      if (context.canPop()) {
        context.pop();
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${meal.name} is deleted')));
    } on Object catch (error, stackTrace) {
      if (!context.mounted) {
        return;
      }
      final AppException failure = ErrorMapper.map(error, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.displayMessage ?? failure.message)),
      );
    }
  }
}

/// The name, the §17 metadata line, and the description.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(meal.cuisine.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.foreground,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: _dotSize),
            ),
            const SizedBox(width: AppSpacing.space2),
            // §17: "Filipino · Easy · 35 min", in that order.
            Expanded(
              child: Text(
                AppFormat.metadata(<String?>[
                  meal.cuisine.label,
                  meal.difficulty.label,
                  AppFormat.cookingTime(meal.cookingTimeMinutes),
                ]).toUpperCase(),
                style: context.text.overline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (meal.isMine) const DeltaBadge(label: 'YOURS', isPositive: true),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(meal.name, style: context.text.displayMedium),
        if (meal.description case final String description) ...<Widget>[
          const SizedBox(height: AppSpacing.space3),
          Text(
            description,
            style: context.text.bodyLarge.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }

  static const double _dotSize = 8;
}

/// The cost as the hero figure, then the three numbers that qualify it.
class _NumbersPanel extends StatelessWidget {
  const _NumbersPanel({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // §17: "Show estimated cost prominently." Per head, because that is
          // the figure comparable between two meals that feed different numbers.
          BigFigure(
            label: 'Cost a head',
            value: AppFormat.peso(meal.costPerServing),
            unit: 'a plate',
          ),
          const SizedBox(height: AppSpacing.space5),
          StatTrio(
            columns: <StatColumnData>[
              StatColumnData(
                label: 'All in',
                value: AppFormat.peso(meal.estimatedCost),
              ),
              StatColumnData(
                label: 'Time',
                value: '${meal.cookingTimeMinutes}',
                unit: 'min',
              ),
              StatColumnData(
                label: 'Feeds',
                value: '${meal.servings}',
                unit: meal.servings == 1 ? 'person' : 'people',
              ),
            ],
          ),
          if (meal.calories case final int calories) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            const DashboardRule(),
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: <Widget>[
                Text('ROUGHLY', style: context.text.overline),
                const Spacer(),
                Text(
                  '$calories kcal a plate',
                  style: context.text.metadata.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The dietary tags, which are the one thing on this screen with a safety
/// consequence.
///
/// Shown as their own panel rather than folded into the metadata line, because a
/// hard filter deserves to be read: the recommendation engine treats these as
/// absolute, so a wrong one does not skew a score, it offers someone food they
/// cannot eat.
class _DietaryPanel extends StatelessWidget {
  const _DietaryPanel({required this.tags});

  final Set<DietaryTag> tags;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      title: 'Suits',
      icon: AppIcons.check,
      child: Wrap(
        spacing: AppSpacing.space2,
        runSpacing: AppSpacing.space2,
        children: <Widget>[
          for (final DietaryTag tag in tags)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.success.surface,
                borderRadius: AppRadius.borderFull,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                  vertical: AppSpacing.space1,
                ),
                child: Text(
                  tag.label,
                  style: context.text.labelSmall.copyWith(
                    color: colors.success.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// §17's ingredient list: name on the left, amount on the right.
class _IngredientsPanel extends StatelessWidget {
  const _IngredientsPanel({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final List<MealIngredient> ingredients = meal.ingredients;

    if (ingredients.isEmpty) {
      return DashboardPanel(
        title: 'Ingredients',
        icon: AppIcons.pantry,
        child: Text(
          meal.isMine
              ? 'You did not list any. Edit the meal to add them.'
              : 'This one does not list its ingredients yet.',
          style: context.text.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return DashboardPanel(
      title: 'Ingredients',
      icon: AppIcons.pantry,
      trailing: Text(
        '${ingredients.length} ITEMS',
        style: context.text.overline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, MealIngredient item)
              in ingredients.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      // Stored lower-case in the shared vocabulary; capitalised
                      // here because this is the one place a person reads it.
                      AppFormat.sentenceCase(item.name),
                      style: context.text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.isOptional) ...<Widget>[
                    Text('OPTIONAL', style: context.text.overline),
                    const SizedBox(width: AppSpacing.space3),
                  ],
                  Text(
                    item.amount,
                    style: context.text.numeric.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (ingredients.any((MealIngredient item) => item.isStaple))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space3),
              child: Text(
                // The rule from docs/USER_FLOWS.md §12, said out loud once. It
                // is why a pantry match can read high with an empty cupboard.
                'Staples like salt, oil and garlic are assumed to be in.',
                style: context.text.metadata,
              ),
            ),
        ],
      ),
    );
  }
}

/// §17's large numbered steps.
class _InstructionsPanel extends StatelessWidget {
  const _InstructionsPanel({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    if (steps.isEmpty) {
      return DashboardPanel(
        title: 'How to cook it',
        icon: AppIcons.cookingTime,
        child: Text(
          'No steps written for this one.',
          style: context.text.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return DashboardPanel(
      title: 'How to cook it',
      icon: AppIcons.cookingTime,
      trailing: Text('${steps.length} STEPS', style: context.text.overline),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, String step) in steps.indexed) ...<Widget>[
            if (index > 0) const SizedBox(height: AppSpacing.space5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // §17 draws these as "01 / 02 / 03" — the number set large and
                // separate above its step, not inline with it.
                Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: context.text.headlineMedium.copyWith(
                    color: colors.series1,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(step, style: context.text.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.failure, required this.onRetry});

  final AppException failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      kind: failure.errorStateKind,
      body: failure.displayMessage,
      errorCode: failure.supportCode,
      onRetry: failure.shouldOfferRetry ? onRetry : null,
    );
  }
}

/// The shape of the screen, while it loads.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenMargin),
      children: const <Widget>[
        AppSkeleton.textLine(widthFactor: 0.3),
        SizedBox(height: AppSpacing.space3),
        AppSkeleton(height: 34, borderRadius: AppRadius.borderXs),
        SizedBox(height: AppSpacing.space3),
        AppSkeleton.textLine(),
        SizedBox(height: AppSpacing.space2),
        AppSkeleton.textLine(widthFactor: 0.8),
        SizedBox(height: AppSpacing.space5),
        AppSkeleton(height: 168, borderRadius: AppRadius.borderXl),
        SizedBox(height: AppSpacing.space4),
        AppSkeleton(height: 220, borderRadius: AppRadius.borderXl),
      ],
    );
  }
}
