import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_visits.dart';

/// Where we have been (Sprint 55).
///
/// **The eat-out half of the app has been keeping a diary it never showed
/// anybody.** `restaurant_history` has been written on every accepted night out
/// since Sprint 46, and read by exactly one thing: the scorer, which uses it to
/// push down places visited recently. So the app knew where the household had
/// been, quietly used it against them, and had no screen that said so — while the
/// cooked side got a whole "What we ate" from the same shape of table.
///
/// This is that screen, in the same shape deliberately. The two halves of one
/// decision deserve the same vocabulary: a hero count, three figures, then panels
/// grouped by day.
///
/// **Grouped by day, newest first**, for the reason the meal history gives: a
/// history is read to spot a pattern — "that is the third Friday in a row" — and
/// a flat list of forty rows with a timestamp on each hides exactly that.
class RestaurantHistoryScreen extends ConsumerWidget {
  const RestaurantHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RestaurantVisit>> visits = ref.watch(
      restaurantVisitsProvider,
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
              onRefresh: () async => ref.invalidate(restaurantVisitsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.screenMargin,
                  0,
                  AppLayout.screenMargin,
                  AppLayout.scrollBottomPadding,
                ),
                children: <Widget>[
                  const _TopBar(),
                  const SizedBox(height: AppSpacing.space4),
                  switch (visits) {
                    AsyncData<List<RestaurantVisit>>(
                      :final List<RestaurantVisit> value,
                    ) =>
                      value.isEmpty
                          ? const _NeverBeenOut()
                          : _Visits(visits: value),
                    AsyncError<List<RestaurantVisit>>(:final Object error) =>
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.space6),
                        child: ErrorState(
                          kind: error is AppException
                              ? error.errorStateKind
                              : ErrorStateKind.unknown,
                          body: error is AppException
                              ? error.displayMessage
                              : null,
                          onRetry: () =>
                              ref.invalidate(restaurantVisitsProvider),
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
            child: Text(
              'Where we have been',
              style: context.text.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The count, three figures worth having, then the days.
class _Visits extends StatelessWidget {
  const _Visits({required this.visits});

  final List<RestaurantVisit> visits;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // What it really came to when anybody said, and what the place claimed when
    // nobody did. `actualCost` first, deliberately: this screen is the closest
    // thing the app has to a record of what eating out costs, and preferring the
    // estimate would make it a record of what the household *guessed*.
    final List<double> spends = <double>[
      for (final RestaurantVisit visit in visits)
        if (visit.actualCost ?? visit.estimatedCost case final double cost)
          cost,
    ];

    final double? typical = spends.isEmpty
        ? null
        : spends.reduce((double a, double b) => a + b) / spends.length;

    final Map<DateTime, List<RestaurantVisit>> byDay = _groupByDay(visits);

    // How many different places, and the one they keep going back to. Both
    // answer the question this screen exists for — whether eating out is a
    // habit with variety in it or the same table every fortnight.
    final Map<String, int> byPlace = <String, int>{};
    for (final RestaurantVisit visit in visits) {
      byPlace[visit.restaurantName] = (byPlace[visit.restaurantName] ?? 0) + 1;
    }

    final String? favourite = byPlace.isEmpty
        ? null
        : byPlace.entries
              .reduce(
                (MapEntry<String, int> a, MapEntry<String, int> b) =>
                    b.value > a.value ? b : a,
              )
              .key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Nights out',
                value: '${visits.length}',
                unit: visits.length == 1 ? 'night' : 'nights',
              ),
              if (favourite case final String name) ...<Widget>[
                const SizedBox(height: AppSpacing.space2),
                Text(
                  byPlace[name] == 1
                      // Everywhere once is not a favourite, and calling one of
                      // them "the usual" would be the screen inventing a habit
                      // out of a tie.
                      ? 'Somewhere different every time'
                      : 'Mostly ${AppFormat.sentenceCase(name)} — '
                            '${byPlace[name]} times',
                  style: context.text.metadata,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.space5),
              StatTrio(
                columns: <StatColumnData>[
                  StatColumnData(
                    label: 'Typical night',
                    value: typical == null ? '—' : AppFormat.peso(typical),
                    unit: typical == null ? null : 'a head',
                    color: colors.series1,
                  ),
                  StatColumnData(
                    label: 'Places tried',
                    value: '${byPlace.length}',
                    color: colors.series2,
                  ),
                  StatColumnData(
                    label: 'Last one',
                    value: AppFormat.dayLabel(visits.first.eatenAt),
                    color: colors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space4),
              DashboardActionRow(
                actions: <DashboardAction>[
                  DashboardAction(
                    label: 'Pick one',
                    icon: AppIcons.spin,
                    onTap: () =>
                        context.goNamed(AppRoute.restaurantSpin.routeName),
                  ),
                  DashboardAction(
                    label: 'Cook instead',
                    icon: AppIcons.meals,
                    onTap: () => context.goNamed(AppRoute.home.routeName),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        for (final DateTime day in byDay.keys) ...<Widget>[
          _DayPanel(day: day, visits: byDay[day]!),
          const SizedBox(height: AppSpacing.space4),
        ],
      ],
    );
  }

  /// Newest day first, and within a day newest first, matching the query.
  ///
  /// Insertion order carries the sort, exactly as the meal history's grouping
  /// does: the rows arrive sorted, so grouping needs no second sort and cannot
  /// disagree with the server about the order.
  static Map<DateTime, List<RestaurantVisit>> _groupByDay(
    List<RestaurantVisit> visits,
  ) {
    final Map<DateTime, List<RestaurantVisit>> grouped =
        <DateTime, List<RestaurantVisit>>{};

    for (final RestaurantVisit visit in visits) {
      final DateTime day = DateTime(
        visit.eatenAt.year,
        visit.eatenAt.month,
        visit.eatenAt.day,
      );
      grouped.putIfAbsent(day, () => <RestaurantVisit>[]).add(visit);
    }

    return grouped;
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.day, required this.visits});

  final DateTime day;
  final List<RestaurantVisit> visits;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: AppFormat.dayLabel(day),
      icon: AppIcons.plannerActive,
      trailing: Text(
        visits.length == 1 ? '1 NIGHT' : '${visits.length} TIMES',
        style: context.text.overline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, RestaurantVisit visit)
              in visits.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            _VisitRow(visit: visit),
          ],
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final RestaurantVisit visit;

  @override
  Widget build(BuildContext context) {
    final double? cost = visit.actualCost ?? visit.estimatedCost;

    return DashboardRow(
      title: visit.restaurantName.isEmpty
          // The place was deleted from the library after this night out. The
          // night still happened, so the row stays — a history that erases
          // itself when somebody tidies their list is not a history.
          ? 'A place we no longer have saved'
          : AppFormat.sentenceCase(visit.restaurantName),
      subtitle: AppFormat.metadata(<String?>[
        if (visit.cuisine != Cuisine.other) visit.cuisine.label,
        AppFormat.timeOfDay(visit.eatenAt),
        // Only when it is the real figure. Every row saying "estimated" is a
        // column of noise; the distinction only matters where it exists.
        if (visit.actualCost != null) 'What it came to',
      ]),
      value: cost == null ? null : AppFormat.peso(cost),
      unit: cost == null ? null : 'a head',
      // The place, so the commonest reason to look — "where was that, and what
      // did it cost" — lands somewhere it can be corrected. The library has no
      // read-only detail screen, and sending somebody to a dead end would be
      // worse than sending them somewhere editable.
      onTap: visit.restaurantName.isEmpty
          ? null
          : () => context.pushNamed(
              AppRoute.restaurantEdit.routeName,
              pathParameters: <String, String>{'id': visit.restaurantId},
            ),
    );
  }
}

class _NeverBeenOut extends StatelessWidget {
  const _NeverBeenOut();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState(
        title: 'No nights out yet',
        body: 'Pick a place and it will show up here.',
        icon: AppIcons.plannerActive,
        actionLabel: 'Pick one',
        onAction: () => context.goNamed(AppRoute.restaurantSpin.routeName),
      ),
    );
  }
}
