import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/home/presentation/providers/home_dashboard.dart';
import 'package:whats_cooking/features/home/presentation/widgets/dashboard_charts.dart';

import '../../support/component_harness.dart';

/// The dashboard components, in the parent they actually have (Sprint 51).
///
/// **This file exists because the same bug shipped three times.** A `Row` with
/// `CrossAxisAlignment.stretch` needs a bounded height, and a widget inside a
/// `ListView` or a `SliverList` is given `maxHeight: infinity` — so
/// "BoxConstraints forces an infinite height" took down the meal feed, then
/// `StatTrio`, then `DashboardActionRow`. Each one passed its own widget test,
/// because every widget test in this suite pumped its subject inside a `Center`.
///
/// So the assertion here is not about pixels. It is: *put every dashboard
/// component under an unbounded parent and see whether it renders at all* —
/// which is the one thing the old harness could not ask. `testInList` does it in
/// both themes and at 1.3x on a 320 px screen, because a component that only gets
/// one of the four checked is a component that will fail on one of the others.
void main() {
  group('under an unbounded parent', () {
    // The divider-bearing three. All of them use full-height hairlines between
    // columns, which is the exact construct that needs a bounded height — and
    // two of the three have already broken this way.
    testInList(
      'StatTrio',
      () => const StatTrio(
        columns: <StatColumnData>[
          StatColumnData(label: 'Under 30 min', value: '9'),
          StatColumnData(label: 'Under ₱100', value: '12', fraction: 0.4),
          StatColumnData(label: 'Yours', value: '0'),
        ],
      ),
    );

    testInList(
      'DashboardActionRow',
      () => DashboardActionRow(
        actions: <DashboardAction>[
          DashboardAction(label: 'Saved', icon: AppIcons.favorite, onTap: () {}),
          DashboardAction(label: 'Hidden', icon: AppIcons.dislike, onTap: () {}),
          DashboardAction(label: 'Yours', icon: AppIcons.meals, onTap: () {}),
          DashboardAction(label: 'Invent', icon: AppIcons.invent, onTap: () {}),
        ],
      ),
    );

    testInList(
      'AppSegmentedControl',
      () => AppSegmentedControl<int>(
        options: const <(int, String)>[(0, 'Cook'), (1, 'Eat out')],
        selected: 0,
        onSelected: (int _) {},
      ),
    );

    testInList(
      'DashboardPanel with a header and a trailing control',
      () => const DashboardPanel(
        title: 'All meals',
        icon: AppIcons.meals,
        trailing: Text('Newest'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DashboardRow(
              title: 'Arroz Caldo',
              subtitle: 'FILIPINO',
              value: '₱84',
            ),
            DashboardRule(),
            DashboardRow(
              title: 'Beef and Broccoli',
              value: '₱113',
              unit: 'a head',
            ),
          ],
        ),
      ),
    );

    testInList(
      'BigFigure',
      () => const BigFigure(label: 'On the menu', value: '20+', unit: 'meals'),
    );

    testInList(
      'MiniBar',
      () => const MiniBar(fraction: 0.6),
    );

    testInList(
      'DeltaBadge',
      () => const DeltaBadge(label: '+12%', isPositive: true),
    );

    // The charts. Both draw a bar per bucket with a `Column` of stacked segments
    // inside, which is the same shape as the constructs that broke — and a chart
    // is the one component nobody notices is missing until the panel is empty.
    testInList('SpendChart', () => const SpendChart(weeks: _sixWeeks));

    testInList(
      'SpendChart with a flat week',
      // Every bucket zero. The 4% floor exists so a bar is still visible, and a
      // divide-by-peak with no peak is the arithmetic that would throw here.
      () => const SpendChart(
        weeks: <WeekSpend>[
          WeekSpend(weeksAgo: 1),
          WeekSpend(weeksAgo: 0),
        ],
      ),
    );

    testInList(
      'CuisineMix',
      () => const CuisineMix(
        counts: <Cuisine, int>{
          Cuisine.filipino: 8,
          Cuisine.chinese: 5,
          Cuisine.japanese: 3,
          Cuisine.korean: 2,
          Cuisine.italian: 1,
        },
      ),
    );

    testInList(
      'CuisineMix with one cuisine',
      () => const CuisineMix(counts: <Cuisine, int>{Cuisine.filipino: 1}),
    );
  });

  group('StatTrio', () {
    testWidgets('renders every column it is given', (
      WidgetTester tester,
    ) async {
      await pumpInList(
        tester,
        const StatTrio(
          columns: <StatColumnData>[
            StatColumnData(label: 'Cooked', value: '4'),
            StatColumnData(label: 'Out', value: '2'),
            StatColumnData(label: 'A head', value: '87', unit: 'pesos'),
          ],
        ),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
      // Labels are drawn in caps by the component, not by the caller — so a test
      // looking for 'Cooked' would find nothing.
      expect(find.text('COOKED'), findsOneWidget);
      expect(find.text('pesos'), findsOneWidget);
    });

    testWidgets('a tappable column reports the tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;

      await pumpInList(
        tester,
        StatTrio(
          columns: <StatColumnData>[
            const StatColumnData(label: 'Walk', value: '3'),
            StatColumnData(label: 'Short ride', value: '5', onTap: () => taps++),
          ],
        ),
      );

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('SpendChart', () {
    testWidgets('labels only the ends of the axis', (
      WidgetTester tester,
    ) async {
      // Six labels under six bars is a smear on a phone, so the chart names the
      // oldest bucket and the newest and nothing between.
      await pumpInList(tester, const SpendChart(weeks: _sixWeeks));

      // Lower case, both of them. The chart sets its axis in `metadata`, which is
      // not a caps style — the capitalised 'This week' appears only inside a bar's
      // `Semantics` label, which is a different string for a different reader.
      expect(find.text('6 weeks ago'), findsOneWidget);
      expect(find.text('this week'), findsOneWidget);
    });
  });
}

/// Six weeks with a shape to them: a quiet start, a spike, and a recovery.
const List<WeekSpend> _sixWeeks = <WeekSpend>[
  WeekSpend(weeksAgo: 5, cooked: 420, eatenOut: 0),
  WeekSpend(weeksAgo: 4, cooked: 510, eatenOut: 260),
  WeekSpend(weeksAgo: 3, cooked: 380, eatenOut: 0),
  WeekSpend(weeksAgo: 2, cooked: 640, eatenOut: 900),
  WeekSpend(weeksAgo: 1, cooked: 470, eatenOut: 180),
  WeekSpend(weeksAgo: 0, cooked: 300, eatenOut: 120),
];
