import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/provider_cache.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_toast.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';

part 'disliked_meals_screen.g.dart';

/// The meals behind the hidden ids.
///
/// Watches the set rather than reading it, so restoring something from this
/// screen removes the row: the control writes to `dislikesController`, this
/// rebuilds, and the meal is gone from the list it no longer belongs on.
@riverpod
Future<List<Meal>> dislikedMeals(Ref ref) async {
  ref.cacheFor(kReadCacheWindow);

  final Set<String> ids = await ref.watch(dislikesControllerProvider.future);
  if (ids.isEmpty) {
    return const <Meal>[];
  }
  return ref.read(mealRepositoryProvider).byIds(ids);
}

/// Meals this user has hidden (Sprint 25).
///
/// **On the wording.** The code says *dislike* everywhere — the table, the
/// repository, the route name — because that is the domain's word and the
/// schema's. The screen says *hidden*, because that is what actually happens: a
/// dislike is not a rating, it is an exclusion, and "hidden" is the only one of
/// the two words that tells the user what changed. The split is deliberate;
/// please do not tidy it into one.
///
/// The list exists because the exclusion is permanent and invisible everywhere
/// else. A hidden meal is gone from the feed, from search and — once Phase 6
/// lands — from the roulette, which means without this screen a mistaken tap
/// could not be undone at all.
class DislikedMealsScreen extends ConsumerWidget {
  const DislikedMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Meal>> meals = ref.watch(dislikedMealsProvider);

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
              onRefresh: ref.read(dislikesControllerProvider.notifier).refresh,
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
                                ? const _NothingHidden()
                                : _HiddenList(meals: value),
                          AsyncError<List<Meal>>(:final Object error) =>
                            _HiddenError(
                              failure: error is AppException
                                  ? error
                                  : const UnknownException(),
                              onRetry: () =>
                                  ref.invalidate(dislikesControllerProvider),
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
            child: Text('Hidden meals', style: context.text.headlineMedium),
          ),
        ],
      ),
    );
  }
}

/// The count as the hero figure, then the table.
class _HiddenList extends StatelessWidget {
  const _HiddenList({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Hidden',
                value: '${meals.length}',
                unit: meals.length == 1 ? 'meal' : 'meals',
              ),
              const SizedBox(height: AppSpacing.space4),
              // No stat columns here, unlike the saved list. A typical cost
              // across food you have chosen never to eat is a number about
              // nothing.
              Text(
                'These never appear in the feed, in search, or in a spin. '
                'Bring one back and it becomes a candidate again.',
                // `bodySmall` already carries the secondary colour.
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        DashboardPanel(
          title: 'Not for me',
          icon: AppIcons.dislikeActive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (int index, Meal meal) in meals.indexed) ...<Widget>[
                DashboardRule(inset: index == 0 ? 0 : MealTableRow.ruleInset),
                MealTableRow(
                  key: ValueKey<String>(meal.id),
                  meal: meal,
                  // Every row here is hidden, so saying so on each one adds
                  // nothing; and a heart would offer to save a meal the user
                  // just told us never to show them.
                  showHiddenMarker: false,
                  trailing: _RestoreButton(meal: meal),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Brings one meal back.
///
/// No confirmation, unlike hiding. Un-hiding is not destructive — it puts a meal
/// back among sixty others — and a dialog in front of an undo is how people
/// learn to dismiss dialogs without reading them (docs/COMPONENTS.md §10).
class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      icon: AppIcons.restore,
      semanticLabel: 'Stop hiding ${meal.name}',
      iconSize: AppIconSize.sm,
      onPressed: () => _restore(context, ref),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final AppException? failure = await ref
        .read(dislikesControllerProvider.notifier)
        .restore(meal.id);

    if (!context.mounted) {
      return;
    }

    // The row has already gone or already come back — the controller rolled its
    // own state. All that is left is to say which happened.
    if (failure case final AppException problem) {
      AppToast.failure(problem.displayMessage ?? problem.message);
      return;
    }
    AppToast.success('${meal.name} is back on the menu.');
  }
}

class _NothingHidden extends StatelessWidget {
  const _NothingHidden();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState.hiddenMeals(onBrowse: () => context.pop()),
    );
  }
}

class _HiddenError extends StatelessWidget {
  const _HiddenError({required this.failure, required this.onRetry});

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
