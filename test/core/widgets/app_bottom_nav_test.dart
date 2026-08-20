import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/navigation/app_bottom_nav.dart';

import '../../support/component_harness.dart';

void main() {
  const List<AppBottomNavItem> items = <AppBottomNavItem>[
    AppBottomNavItem(
      label: 'Home',
      icon: AppIcons.home,
      activeIcon: AppIcons.homeActive,
    ),
    AppBottomNavItem(
      label: 'Meals',
      icon: AppIcons.meals,
      activeIcon: AppIcons.mealsActive,
    ),
    AppBottomNavItem(
      label: 'Profile',
      icon: AppIcons.profile,
      activeIcon: AppIcons.profileActive,
    ),
  ];

  group('AppBottomNav', () {
    testInBothThemes('renders every destination', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
        brightness: brightness,
      );

      // Every destination is present as an icon; only the active one is
      // labelled, which is the reference's behaviour.
      expect(find.byIcon(AppIcons.homeActive), findsOneWidget);
      expect(find.byIcon(AppIcons.meals), findsOneWidget);
      expect(find.byIcon(AppIcons.profile), findsOneWidget);
    });

    testWidgets('only the active destination is labelled', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 1,
          onDestinationSelected: (_) {},
        ),
      );

      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('every destination is still named to a screen reader', (
      WidgetTester tester,
    ) async {
      // The visible label moved to the active item only; the *accessible* name
      // did not. An unlabelled icon would leave four of five tabs anonymous
      // (docs/DESIGN_SYSTEM.md §11).
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 1,
          onDestinationSelected: (_) {},
        ),
      );

      for (final AppBottomNavItem item in items) {
        expect(find.bySemanticsLabel(item.label), findsOneWidget);
      }

      handle.dispose();
    });

    testWidgets('the active item is filled and the rest are outlined', (
      WidgetTester tester,
    ) async {
      // docs/DESIGN_SYSTEM.md §8: outlined-to-filled "is how bottom-nav
      // selection reads without a colour change carrying the whole load".
      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 1,
          onDestinationSelected: (_) {},
        ),
      );

      expect(find.byIcon(AppIcons.mealsActive), findsOneWidget);
      expect(find.byIcon(AppIcons.home), findsOneWidget);
      expect(find.byIcon(AppIcons.homeActive), findsNothing);
    });

    testWidgets('the active pill carries near-black content on a tint', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
      );

      final AppColorScheme colors = tester.element(find.text('Home')).colors;

      expect(
        tester.widget<Text>(find.text('Home')).style?.color,
        colors.textPrimary,
      );
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.homeActive)).color,
        colors.textPrimary,
      );
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.meals)).color,
        colors.textTertiary,
      );
    });

    testWidgets('reports the tapped index', (WidgetTester tester) async {
      int? selected;

      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (int index) => selected = index,
        ),
      );

      await tester.tap(find.byIcon(AppIcons.profile));
      expect(selected, 2);
    });

    testWidgets('reports a tap on the already-active tab', (
      WidgetTester tester,
    ) async {
      // The shell needs this to pop that tab to its root
      // (docs/NAVIGATION_MAP.md §8), so it must not be swallowed here.
      int? selected;

      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (int index) => selected = index,
        ),
      );

      await tester.tap(find.text('Home'));
      expect(selected, 0);
    });

    testWidgets('announces the selected destination', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
      );

      // Selection must not rest on colour and fill alone (§11).
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')).hint,
        'Selected',
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Meals')).hint, isEmpty);

      handle.dispose();
    });

    testWidgets('is the documented height and survives a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppBottomNav(
          items: const <AppBottomNavItem>[...items, ...items],
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
        surfaceSize: kSmallPhone,
      );

      // Six items on the narrowest supported device: more than the five the app
      // ships, as a margin.
      expectNoOverflow(tester);
    });

    testWidgets('survives 1.3x text scale', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppBottomNav(
          items: items,
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}
