import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/my_meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/selectable_meal_row.dart';

/// Your own recipes, and the way into editing them.
///
/// The catalogue is somebody else's food. This screen is the household's, and it
/// exists mainly so a recipe can be found again — a meal you can write but not
/// re-open is one you can only fix by writing it twice.
///
/// The edit and delete actions live on the meal itself rather than on these
/// rows. Two controls per row crowds out the name on a phone, and a delete one
/// tap from a scrolling list is a delete somebody does by accident.
class MyMealsScreen extends ConsumerStatefulWidget {
  const MyMealsScreen({super.key});

  @override
  ConsumerState<MyMealsScreen> createState() => _MyMealsScreenState();
}

class _MyMealsScreenState extends ConsumerState<MyMealsScreen> {
  /// The ids picked out for a bulk action, or empty when not selecting.
  ///
  /// **This screen and not the main feed**, deliberately. `delete own meals` is
  /// author-scoped, so a bulk delete on the catalogue would offer an action the
  /// server refuses for the sixty seeded rows — and a button that errors teaches
  /// people to distrust the ones that work. Here every row is one this reader
  /// wrote, so every row can genuinely go.
  final Set<String> _selected = <String>{};

  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
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
                        _TopBar(
                          selectedCount: _selected.length,
                          isBusy: _isDeleting,
                          onCancel: () => setState(_selected.clear),
                          onDelete: _deleteSelected,
                          onEdit: _selected.length == 1 ? _editSelected : null,
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        switch (meals) {
                          AsyncData<List<Meal>>(:final List<Meal> value) =>
                            value.isEmpty
                                ? const _NothingWritten()
                                : _OwnList(
                                    meals: value,
                                    selected: _selected,
                                    isBusy: _isDeleting,
                                    onToggle: _toggle,
                                  ),
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

  /// Picks a meal out, or puts it back.
  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) {
      _selected.add(id);
    }
  });

  /// Opens the one selected meal in the form.
  ///
  /// Only offered at exactly one selection, because "edit" has no meaning for
  /// three. Editing was always reachable — it is two taps down on the meal's own
  /// screen — but nothing on a list said so, which for somebody looking at a list
  /// of their own recipes is the same as it not existing.
  void _editSelected() {
    final String id = _selected.first;
    setState(_selected.clear);
    context.pushNamed(
      AppRoute.mealEdit.routeName,
      pathParameters: <String, String>{'id': id},
    );
  }

  /// Deletes everything picked out.
  ///
  /// **One confirmation for the batch, and it names the count.** Asking per meal
  /// would defeat the point of selecting several; asking nothing would make a
  /// long-press into a destructive gesture.
  ///
  /// Sequential and tolerant, like every other batch in this app: one refusal
  /// costs that meal rather than the other five, and the message says how many
  /// actually went.
  Future<void> _deleteSelected() async {
    final int count = _selected.length;

    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: count == 1 ? 'Delete this meal?' : 'Delete $count meals?',
      // Says what survives, because it is the question somebody actually has.
      // Deleting a recipe does not unpick the nights it was eaten.
      body: 'The recipe goes. Nights you have already eaten it stay in your '
          'history.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep them',
      isDestructive: true,
      icon: AppIcons.delete,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);

    int gone = 0;
    AppException? failure;

    for (final String id in _selected.toList()) {
      try {
        await ref.read(mealRepositoryProvider).delete(id);
        gone += 1;
      } on Object catch (error, stackTrace) {
        failure ??= ErrorMapper.map(error, stackTrace);
      }
    }

    // Both lists, and the feed is reloaded rather than patched: a deleted meal
    // has to leave whatever sort and filters are applied.
    ref.invalidate(myMealsProvider);
    await ref.read(mealsControllerProvider.notifier).refresh();

    if (!mounted) {
      return;
    }

    setState(() {
      _selected.clear();
      _isDeleting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch ((gone, failure)) {
            (0, final AppException e) => e.displayMessage ?? e.message,
            (0, _) => 'Nothing was deleted.',
            (1, null) => 'The meal is gone.',
            (final int n, null) => '$n meals are gone.',
            (final int n, _) => '$n deleted — the rest could not be.',
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selectedCount,
    required this.isBusy,
    required this.onCancel,
    required this.onDelete,
    required this.onEdit,
  });

  final int selectedCount;
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  /// Null unless exactly one meal is picked out.
  final VoidCallback? onEdit;

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
            child: Text(
              // The count replaces the title while selecting, rather than
              // appearing beside it. Two headlines competing is how a selection
              // mode ends up looking like a different screen.
              selectedCount == 0
                  ? 'Your meals'
                  : '$selectedCount selected',
              style: context.text.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (selectedCount == 0)
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
                onPressed: () =>
                    context.pushNamed(AppRoute.mealCreate.routeName),
              ),
            )
          else ...<Widget>[
            // Edit only at one, because "edit" has no meaning for three.
            if (onEdit case final VoidCallback edit) ...<Widget>[
              AppIconButton(
                icon: AppIcons.edit,
                semanticLabel: 'Edit this meal',
                iconSize: AppIconSize.sm,
                onPressed: isBusy ? null : edit,
              ),
              const SizedBox(width: AppSpacing.space1),
            ],
            AppIconButton(
              icon: AppIcons.delete,
              semanticLabel: selectedCount == 1
                  ? 'Delete this meal'
                  : 'Delete $selectedCount meals',
              iconSize: AppIconSize.sm,
              onPressed: isBusy ? null : onDelete,
            ),
            const SizedBox(width: AppSpacing.space1),
            AppIconButton(
              icon: AppIcons.clear,
              semanticLabel: 'Stop selecting',
              iconSize: AppIconSize.sm,
              onPressed: isBusy ? null : onCancel,
            ),
          ],
        ],
      ),
    );
  }
}

/// The count as the hero figure, then the table.
class _OwnList extends StatelessWidget {
  const _OwnList({
    required this.meals,
    required this.selected,
    required this.isBusy,
    required this.onToggle,
  });

  final List<Meal> meals;
  final Set<String> selected;
  final bool isBusy;
  final ValueChanged<String> onToggle;

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
                SelectableMealRow(
                  key: ValueKey<String>(meal.id),
                  meal: meal,
                  isSelected: selected.contains(meal.id),
                  isSelecting: selected.isNotEmpty,
                  isBusy: isBusy,
                  onToggle: () => onToggle(meal.id),
                ),
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
