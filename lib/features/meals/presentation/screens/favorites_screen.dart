import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';

part 'favorites_screen.g.dart';

/// The meals behind the saved ids.
///
/// Watches the favourites set rather than reading it, so unfavouriting something
/// from this screen removes the row: the heart writes to
/// `favoritesController`, this rebuilds, and the meal is gone. That is the
/// behaviour people expect from a favourites list and it costs one `watch`.
///
/// A second fetch on top of the ids is unavoidable — `favorite_meals` stores ids
/// and nothing else, deliberately, so that a heart on a feed row can be answered
/// without loading twenty meals (see `FavoritesRepository`).
@riverpod
Future<List<Meal>> favoriteMeals(Ref ref) async {
  final Set<String> ids = await ref.watch(favoritesControllerProvider.future);
  if (ids.isEmpty) {
    return const <Meal>[];
  }
  return ref.read(mealRepositoryProvider).byIds(ids);
}

/// Meals you saved (Sprint 24).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Meal>> meals = ref.watch(favoriteMealsProvider);

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
              onRefresh: ref.read(favoritesControllerProvider.notifier).refresh,
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
                                ? const _NothingSaved()
                                : _SavedList(meals: value),
                          AsyncError<List<Meal>>(:final Object error) =>
                            _SavedError(
                              failure: error is AppException
                                  ? error
                                  : const UnknownException(),
                              onRetry: () =>
                                  ref.invalidate(favoritesControllerProvider),
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
          Expanded(child: Text('Saved', style: context.text.headlineMedium)),
        ],
      ),
    );
  }
}

/// The count as the hero figure, then the table.
class _SavedList extends StatelessWidget {
  const _SavedList({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final double averageCost =
        meals.fold<double>(
          0,
          (double sum, Meal meal) => sum + meal.costPerServing,
        ) /
        meals.length;
    final int quickest = meals
        .map((Meal meal) => meal.cookingTimeMinutes)
        .reduce((int a, int b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Saved',
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
                  StatColumnData(
                    label: 'Quickest',
                    value: '$quickest',
                    unit: 'min',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        DashboardPanel(
          title: 'Your list',
          icon: AppIcons.favoriteActive,
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

/// docs/COMPONENTS.md §12's favourites empty state: it points at the spin.
class _NothingSaved extends StatelessWidget {
  const _NothingSaved();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState.favorites(
        onSpin: () => context.goNamed(AppRoute.home.routeName),
      ),
    );
  }
}

class _SavedError extends StatelessWidget {
  const _SavedError({required this.failure, required this.onRetry});

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
