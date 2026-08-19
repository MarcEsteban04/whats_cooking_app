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

      for (final AppBottomNavItem item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
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

    testWidgets('the active item takes the primary colour', (
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
        colors.primary,
      );
      expect(
        tester.widget<Text>(find.text('Meals')).style?.color,
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

      await tester.tap(find.text('Profile'));
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
