import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/my_meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';

/// Your own recipes, and the way into editing them.
///
/// The catalogue is somebody else's food. This screen is the household's, and it
/// exists mainly so a recipe can be found again — a meal you can write but not
/// re-open is one you can only fix by writing it twice.
///
/// The edit and delete actions live on the meal itself rather than on these
/// rows. Two controls per row crowds out the name on a phone, and a delete one
/// tap from a scrolling list is a delete somebody does by accident.
class MyMealsScreen extends ConsumerWidget {
  const MyMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Meal>> meals = ref.watch(myMealsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(myMealsProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: AppLayout.screenMargin,
                      right: AppLayout.screenMargin,
                      bottom: AppLayout.scrollBottomPadding,
                    ),
                    sliver: SliverList.list(
                      children: <Widget>[
                        const _TopBar(),
                        const SizedBox(height: AppSpacing.space4),
                        switch (meals) {
                          AsyncData<List<Meal>>(:final List<Meal> value) =>
                            value.isEmpty
                                ? const _NothingWritten()
                                : _OwnList(meals: value),
                          AsyncError<List<Meal>>(:final Object error) =>
                            _OwnError(
                              failure: error is AppException
                                  ? error
                                  : const UnknownException(),
                              onRetry: () => ref.invalidate(myMealsProvider),
                            ),
                          _ => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.space7),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space4),
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
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text('Your meals', style: context.text.headlineMedium),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outline),
            ),
            child: AppIconButton(
              icon: AppIcons.add,
              semanticLabel: 'Write another meal',
              iconSize: AppIconSize.sm,
              onPressed: () => context.pushNamed(AppRoute.mealCreate.routeName),
            ),
          ),
        ],
      ),
    );
  }
}

/// The count as the hero figure, then the table.
class _OwnList extends StatelessWidget {
  const _OwnList({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final double averageCost =
        meals.fold<double>(
          0,
          (double sum, Meal meal) => sum + meal.costPerServing,
        ) /
        meals.length;
    final int steps = meals.fold<int>(
      0,
      (int sum, Meal meal) => sum + meal.instructions.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Written',
                value: '${meals.length}',
                unit: meals.length == 1 ? 'meal' : 'meals',
              ),
              const SizedBox(height: AppSpacing.space5),
              StatTrio(
                columns: <StatColumnData>[
                  StatColumnData(
                    label: 'Typical cost',
                    value: AppFormat.peso(averageCost),
                    unit: 'a head',
                  ),
                  // Steps written rather than a second cost figure: it is the
                  // one number here that says how much of the work is done, and
                  // a recipe with no steps is the one worth going back to.
                  StatColumnData(
                    label: 'Steps written',
                    value: '$steps',
                    unit: steps == 1 ? 'step' : 'steps',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        DashboardPanel(
          title: 'Your kitchen',
          icon: AppIcons.meals,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (int index, Meal meal) in meals.indexed) ...<Widget>[
                DashboardRule(inset: index == 0 ? 0 : MealTableRow.ruleInset),
                MealTableRow(key: ValueKey<String>(meal.id), meal: meal),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NothingWritten extends StatelessWidget {
  const _NothingWritten();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState.myMeals(
        onAddMeal: () => context.pushNamed(AppRoute.mealCreate.routeName),
      ),
    );
  }
}

class _OwnError extends StatelessWidget {
  const _OwnError({required this.failure, required this.onRetry});

  final AppException failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space6),
      child: ErrorState(
        kind: failure.errorStateKind,
        body: failure.displayMessage,
        errorCode: failure.supportCode,
        onRetry: failure.shouldOfferRetry ? onRetry : null,
      ),
    );
  }
}
