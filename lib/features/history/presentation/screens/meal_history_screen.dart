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
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';

/// What the household has eaten (Sprint 31).
///
/// Household-scoped, not personal: a meal a partner accepted appears here, which
/// is the whole point of a shared history and the reason the repository does not
/// filter by user.
///
/// Grouped by day rather than listed flat. A history is read to spot a pattern —
/// "we have had chicken three times this week" — and a flat list of forty rows
/// with a timestamp on each hides exactly that.
class MealHistoryScreen extends ConsumerWidget {
  const MealHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealHistoryEntry>> history = ref.watch(
      mealHistoryProvider,
    );

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
              onRefresh: () async => ref.invalidate(mealHistoryProvider),
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
                        switch (history) {
                          AsyncData<List<MealHistoryEntry>>(
                            :final List<MealHistoryEntry> value,
                          ) =>
                            value.isEmpty
                                ? const _NothingEaten()
                                : _Timeline(entries: value),
                          AsyncError<List<MealHistoryEntry>>(
                            :final Object error,
                          ) =>
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.space6,
                              ),
                              child: ErrorState(
                                kind: error is AppException
                                    ? error.errorStateKind
                                    : ErrorStateKind.unknown,
                                body: error is AppException
                                    ? error.displayMessage
                                    : null,
                                onRetry: () =>
                                    ref.invalidate(mealHistoryProvider),
                              ),
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
              semanticLabel: 'Back',
              iconSize: AppIconSize.sm,
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text('What we ate', style: context.text.headlineMedium),
          ),
        ],
      ),
    );
  }
}

/// The count as the hero figure, then a day-by-day table.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<MealHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final List<double> costs = <double>[
      for (final MealHistoryEntry entry in entries)
        if (entry.costPerServing case final double cost) cost,
    ];

    final double? typicalCost = costs.isEmpty
        ? null
        : costs.reduce((double a, double b) => a + b) / costs.length;

    // How many of these were the app's idea. The number that says whether the
    // roulette is being used or merely installed.
    final int spun = entries
        .where((MealHistoryEntry e) => e.source == HistorySource.roulette)
        .length;

    final Map<DateTime, List<MealHistoryEntry>> byDay = _groupByDay(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Decided',
                value: '${entries.length}',
                unit: entries.length == 1 ? 'meal' : 'meals',
              ),
              const SizedBox(height: AppSpacing.space5),
              StatTrio(
                columns: <StatColumnData>[
                  StatColumnData(
                    label: 'Typical cost',
                    value: typicalCost == null
                        ? '—'
                        : AppFormat.peso(typicalCost),
                    unit: typicalCost == null ? null : 'a head',
                  ),
                  StatColumnData(
                    label: 'From a spin',
                    value: '$spun',
                    unit: 'of ${entries.length}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        for (final DateTime day in byDay.keys) ...<Widget>[
          _DayPanel(day: day, entries: byDay[day]!),
          const SizedBox(height: AppSpacing.space4),
        ],
      ],
    );
  }

  /// Newest day first, and within a day newest first, matching the query.
  ///
  /// A `LinkedHashMap` by way of a plain map literal: insertion order is the
  /// order the rows arrived in, which is already sorted, so grouping does not
  /// need a second sort and cannot disagree with the server about the order.
  static Map<DateTime, List<MealHistoryEntry>> _groupByDay(
    List<MealHistoryEntry> entries,
  ) {
    final Map<DateTime, List<MealHistoryEntry>> grouped =
        <DateTime, List<MealHistoryEntry>>{};

    for (final MealHistoryEntry entry in entries) {
      final DateTime day = DateTime(
        entry.eatenAt.year,
        entry.eatenAt.month,
        entry.eatenAt.day,
      );
      grouped.putIfAbsent(day, () => <MealHistoryEntry>[]).add(entry);
    }

    return grouped;
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.day, required this.entries});

  final DateTime day;
  final List<MealHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: AppFormat.dayLabel(day),
      icon: AppIcons.plannerActive,
      trailing: Text(
        entries.length == 1 ? '1 MEAL' : '${entries.length} MEALS',
        style: context.text.overline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, MealHistoryEntry entry)
              in entries.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            _HistoryRow(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final MealHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return DashboardRow(
      title: entry.displayName,
      subtitle: AppFormat.metadata(<String?>[
        entry.mealType.label,
        AppFormat.timeOfDay(entry.eatenAt),
        // Only when it is not the obvious answer. Every row saying "roulette"
        // is a column of noise; a row saying "planner" is information.
        if (entry.source != HistorySource.roulette) entry.source.name,
        if (!entry.wasCooked) 'Ordered',
      ]),
      value: entry.costPerServing == null
          ? null
          : AppFormat.peso(entry.costPerServing!),
      unit: entry.costPerServing == null ? null : 'a head',
      // Straight to the meal rather than to the entry. Somebody tapping a past
      // dinner wants the recipe again, which is the commonest reason to look at
      // a history at all.
      onTap: () => context.pushNamed(
        AppRoute.mealDetail.routeName,
        pathParameters: <String, String>{'id': entry.mealId},
        extra: entry.meal,
      ),
    );
  }
}

class _NothingEaten extends StatelessWidget {
  const _NothingEaten();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState.history(
        onSpin: () => context.goNamed(AppRoute.home.routeName),
      ),
    );
  }
}
