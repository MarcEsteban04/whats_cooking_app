import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_filters_controller.dart';

/// What the spin is allowed to offer (Sprint 30, docs/COMPONENTS.md §7).
///
/// A sheet rather than a screen, because it is an adjustment to something the
/// reader is already doing. They came from Home with a question in mind and they
/// are going straight back to it — the SPIN button lives at the bottom of this
/// sheet so the round trip is one gesture.
///
/// **Six filters, and one of them is not editable here.** Budget, time, cuisine,
/// meal type and difficulty are all a per-spin choice. Dietary needs are shown
/// and locked: they come from the profile, they are applied to every spin, and
/// loosening them must not be one tap away from a hungry person
/// (docs/PRD.md principle 3). The row says where to change them instead.
///
/// Every filter is **additive and clearable**, and the clear-all is always
/// present when anything is set — docs/USER_FLOWS.md §7's rule for the feed
/// applies here for the same reason: a filter you cannot find is a filter you
/// cannot undo.
class SpinFiltersSheet extends ConsumerWidget {
  const SpinFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SpinFilters filters = ref.watch(spinFiltersProvider);
    final SpinFiltersController controller = ref.read(
      spinFiltersControllerProvider.notifier,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(
          count: filters.chosenCount,
          onClear: filters.hasChosen ? controller.clear : null,
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.screenMargin,
              AppSpacing.space4,
              AppLayout.screenMargin,
              AppSpacing.space5,
            ),
            children: <Widget>[
              _Section(
                title: 'Budget',
                subtitle: 'A head, not per pot.',
                child: _StepRow<int>(
                  steps: SpinFilters.budgetSteps,
                  selected: filters.maxCostPerServing,
                  label: (int pesos) => 'Under ${AppFormat.peso(pesos)}',
                  onSelected: controller.setBudget,
                ),
              ),
              _Section(
                title: 'Time',
                subtitle: 'How long you have got.',
                child: _StepRow<int>(
                  steps: SpinFilters.timeSteps,
                  selected: filters.maxCookingTimeMinutes,
                  label: (int minutes) =>
                      'Under ${AppFormat.cookingTime(minutes)}',
                  onSelected: controller.setMaxTime,
                ),
              ),
              _Section(
                title: 'Meal type',
                child: _ChipSet<MealCategory>(
                  values: MealCategory.values,
                  selected: filters.categories,
                  label: (MealCategory value) => value.label,
                  onToggled: controller.toggleCategory,
                ),
              ),
              _Section(
                title: 'Cuisine',
                child: _ChipSet<Cuisine>(
                  values: Cuisine.values,
                  selected: filters.cuisines,
                  label: (Cuisine value) => value.label,
                  onToggled: controller.toggleCuisine,
                ),
              ),
              _Section(
                title: 'Effort',
                subtitle: 'How much of a cook you feel like being.',
                child: _ChipSet<Difficulty>(
                  values: Difficulty.values,
                  selected: filters.difficulties,
                  label: (Difficulty value) => value.label,
                  onToggled: controller.toggleDifficulty,
                ),
              ),
              _Dietary(tags: filters.dietaryTags),
            ],
          ),
        ),
        const _SpinBar(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onClear});

  final int count;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.screenMargin,
          AppSpacing.space4,
          AppSpacing.space3,
          AppSpacing.space3,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                count == 0 ? 'Narrow it down' : '$count applied',
                style: context.text.titleLarge,
              ),
            ),
            // Only offered when there is something to clear, so the control is
            // never a dead button sitting beside a header.
            if (onClear != null)
              AppButton.tertiary(
                label: 'Clear',
                size: AppButtonSize.small,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled group, in the dashboard language the rest of the app uses.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: context.text.overline),
          if (subtitle case final String line) ...<Widget>[
            const SizedBox(height: 2),
            Text(line, style: context.text.metadata),
          ],
          const SizedBox(height: AppSpacing.space3),
          child,
        ],
      ),
    );
  }
}

/// One of a set of thresholds, or none.
///
/// Single-select with an explicit **Any**, rather than a slider. A slider implies
/// the number matters to the decimal when what the reader means is "cheap" or
/// "quick", and it cannot express "no limit" at all without a magic value at one
/// end. Tapping the selected step again also clears it, because that is what
/// people try.
class _StepRow<T extends Object> extends StatelessWidget {
  const _StepRow({
    required this.steps,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> steps;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        AppFilterChip(
          label: 'Any',
          isSelected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final T step in steps)
          AppFilterChip(
            label: label(step),
            isSelected: selected == step,
            onSelected: (_) => onSelected(selected == step ? null : step),
          ),
      ],
    );
  }
}

/// Multi-select. Empty means "all of them", never "none of them".
class _ChipSet<T extends Object> extends StatelessWidget {
  const _ChipSet({
    required this.values,
    required this.selected,
    required this.label,
    required this.onToggled,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T) label;
  final ValueChanged<T> onToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final T value in values)
          AppFilterChip(
            label: label(value),
            isSelected: selected.contains(value),
            onSelected: (_) => onToggled(value),
          ),
      ],
    );
  }
}

/// Dietary needs, shown and locked.
///
/// Read-only on purpose, and the one place in this sheet where the reader cannot
/// change what is applied. A per-spin control that loosens a dietary exclusion is
/// a control somebody taps by accident at the end of a long day, and the cost of
/// that mistake is not a meal they merely dislike.
class _Dietary extends StatelessWidget {
  const _Dietary({required this.tags});

  final Set<DietaryTag> tags;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  AppIcons.check,
                  size: AppIconSize.xs,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text('ALWAYS APPLIED', style: context.text.overline),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              tags.isEmpty
                  ? 'No dietary needs set. Add them in your preferences and '
                        'every spin will respect them.'
                  : '${AppFormat.metadata(tags.map((DietaryTag t) => t.label))}'
                        ' — never relaxed, on any spin.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.space2),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.tertiary(
                label: tags.isEmpty ? 'Set them' : 'Change in preferences',
                size: AppButtonSize.small,
                onPressed: () =>
                    context.goNamed(AppRoute.preferences.routeName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way out, which is also the way on.
///
/// SPIN rather than "Apply". The reader opened this to change what they get, not
/// to admire a form — and a sheet whose only exit is "Apply" makes them find the
/// button they actually wanted all over again on the screen behind it.
class _SpinBar extends StatelessWidget {
  const _SpinBar();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.screenMargin,
          AppSpacing.space3,
          AppLayout.screenMargin,
          AppSpacing.space5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppButton.brand(
              label: 'SPIN',
              // Closes the sheet first so the reel is not animating behind it,
              // then goes. `pop` before `goNamed` rather than after, because the
              // spin route replaces the stack and a queued pop would land on it.
              onPressed: () {
                context.pop();
                context.goNamed(AppRoute.roulette.routeName);
              },
            ),
            const SizedBox(height: AppSpacing.space2),
            Align(
              child: AppButton.tertiary(
                label: 'Back',
                size: AppButtonSize.small,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
