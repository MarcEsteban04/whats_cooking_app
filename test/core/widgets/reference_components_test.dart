import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

/// The components added when the app was aligned to
/// `docs/reference_design/reference_img.webp`.
///
/// Same definition of done as the rest of the library: renders in both themes,
/// survives 1.3x text scale on a 320 px screen, and says something useful to a
/// screen reader.
void main() {
  group('StatCard', () {
    testInBothThemes('leads with the figure', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const StatCard(value: '32', label: 'Meals tried', icon: AppIcons.meals),
        brightness: brightness,
      );

      expect(find.text('32'), findsOneWidget);
      expect(find.text('Meals tried'), findsOneWidget);
    });

    testWidgets('announces the figure and its label as one phrase', (
      WidgetTester tester,
    ) async {
      // Two separate nodes would be read as "32" then "Meals tried", which is
      // two facts where there is one (docs/DESIGN_SYSTEM.md §11).
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        const StatCard(value: '32', label: 'Meals tried'),
      );

      expect(find.bySemanticsLabel('32 Meals tried'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a raised card sits in front of a flat one', (
      WidgetTester tester,
    ) async {
      // The stagger only reads as depth if the front card's shadow is deeper
      // (docs/design_ui.md §35).
      await pumpComponent(
        tester,
        const Row(
          children: <Widget>[
            StatCard(value: '1', label: 'Flat'),
            StatCard(value: '2', label: 'Raised', isRaised: true),
          ],
        ),
      );

      final AppShadows shadows = tester.element(find.text('1')).shadows;

      expect(_decorationAbove(tester, find.text('1')).boxShadow, shadows.sm);
      expect(_decorationAbove(tester, find.text('2')).boxShadow, shadows.md);
    });

    testWidgets('a row of three survives 1.3x on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const StatCardRow(
          cards: <StatCard>[
            StatCard(
              value: '6',
              label: 'Cuisines you like',
              icon: AppIcons.meals,
            ),
            StatCard(
              value: '3',
              label: 'Foods you avoid',
              icon: AppIcons.meals,
            ),
            StatCard(
              value: '2',
              label: 'Usually cooking for',
              icon: AppIcons.meals,
            ),
          ],
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppBadge', () {
    testInBothThemes('renders its label', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const AppBadge(label: 'Top', icon: Icons.star_rounded),
        brightness: brightness,
      );

      expect(find.text('Top'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('each tone pairs its own foreground with its background', (
      WidgetTester tester,
    ) async {
      // A hand-mixed gold would not reach AA against its pastel
      // (docs/DESIGN_SYSTEM.md §2.3), so the pairing comes from the tokens.
      await pumpComponent(
        tester,
        const Column(
          children: <Widget>[
            AppBadge(label: 'Top', tone: AppBadgeTone.highlight),
            AppBadge(label: 'Agreed', tone: AppBadgeTone.success),
            AppBadge(label: 'Draft'),
          ],
        ),
      );

      final AppColorScheme colors = tester.element(find.text('Top')).colors;

      expect(
        tester.widget<Text>(find.text('Top')).style?.color,
        colors.butter.foreground,
      );
      expect(
        _decorationAbove(tester, find.text('Top')).color,
        colors.butter.background,
      );
      expect(
        tester.widget<Text>(find.text('Agreed')).style?.color,
        colors.success.onSurface,
      );
      expect(
        tester.widget<Text>(find.text('Draft')).style?.color,
        colors.textSecondary,
      );
    });
  });

  group('IconListRow', () {
    testInBothThemes('shows its current value beside the label', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      // The whole point of the row: a settings list you have to open to read is
      // a settings list nobody reads.
      await pumpComponent(
        tester,
        IconListRow(title: 'Budget', value: '₱300 a meal', onTap: () {}),
        brightness: brightness,
      );

      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('₱300 a meal'), findsOneWidget);
    });

    testWidgets('announces title and value as one row', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        IconListRow(title: 'Budget', value: '₱300 a meal', onTap: () {}),
      );

      expect(find.bySemanticsLabel('Budget. ₱300 a meal'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a chevron appears only where there is somewhere to go', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const IconListRow(title: 'Signed in as', value: 'marc@example.com'),
      );

      expect(find.byIcon(AppIcons.forward), findsNothing);
    });

    testWidgets('trailing content replaces the chevron', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        IconListRow(
          title: 'Notifications',
          trailing: const AppBadge(label: '3'),
          onTap: () {},
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(AppIcons.forward), findsNothing);
    });

    testWidgets('the destructive tone colours the title, not just the tile', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        IconListRow(
          title: 'Delete account',
          icon: Icons.delete_outline_rounded,
          tone: IconListRowTone.destructive,
          onTap: () {},
        ),
      );

      final AppColorScheme colors = tester
          .element(find.text('Delete account'))
          .colors;

      expect(
        tester.widget<Text>(find.text('Delete account')).style?.color,
        colors.error.color,
      );
    });

    testWidgets('reports a tap', (WidgetTester tester) async {
      bool tapped = false;

      await pumpComponent(
        tester,
        IconListRow(title: 'Account', onTap: () => tapped = true),
      );

      await tester.tap(find.text('Account'));
      expect(tapped, isTrue);
    });

    testWidgets('a card of rows survives 1.3x on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        IconListCard(
          rows: <Widget>[
            IconListRow(
              title: 'Food preferences',
              value: 'Filipino, Japanese · 3 avoided',
              onTap: () {},
            ),
            IconListRow(title: 'Budget', value: '₱300 a meal', onTap: () {}),
          ],
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('CategoryCard', () {
    testInBothThemes('is a white card with a tinted glyph tile', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      // Not a pastel-filled card: six saturated blocks fight the white cards
      // around them. The colour moves to the tile instead.
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => CategoryCard(
            label: 'Comfort food',
            icon: AppIcons.meals,
            accent: context.colors.accentFor('Comfort food'),
            onTap: () {},
          ),
        ),
        brightness: brightness,
      );

      final AppColorScheme colors = tester
          .element(find.text('Comfort food'))
          .colors;

      expect(
        _decorationAbove(tester, find.text('Comfort food')).color,
        colors.surface,
      );
      expect(find.text('🍲'), findsOneWidget);
    });

    testWidgets('says that tapping spins rather than browses', (
      WidgetTester tester,
    ) async {
      // docs/COMPONENTS.md §6: otherwise a screen reader user is told this is a
      // category and discovers it was a button that changed their evening.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => CategoryCard(
            label: 'Comfort food',
            icon: AppIcons.meals,
            accent: context.colors.accentFor('Comfort food'),
            onTap: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Comfort food, spin'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the same category keeps the same colour', (
      WidgetTester tester,
    ) async {
      // Seeded rather than random, so a category is not a different colour on
      // every build (docs/DESIGN_SYSTEM.md §9).
      await pumpComponent(tester, const SizedBox.shrink());

      final AppColorScheme colors = tester
          .element(find.byType(SizedBox).first)
          .colors;

      expect(
        colors.accentFor('Comfort food'),
        colors.accentFor('Comfort food'),
      );
    });

    testWidgets('a grid of six survives 1.3x on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => CategoryGrid(
            cards: <CategoryCard>[
              for (final String label in <String>[
                'Comfort food',
                'Something quick',
                'Cheap and filling',
                'Healthy',
                'Sweet tooth',
                'Surprise me',
              ])
                CategoryCard(
                  label: label,
                  icon: AppIcons.meals,
                  accent: context.colors.accentFor(label),
                  onTap: () {},
                ),
            ],
          ),
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppHeader', () {
    testInBothThemes('greets, then names the context', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        AppHeader(
          greeting: 'Good evening, Marc',
          context_: 'Cooking with Princess',
          contextEmoji: '❤️',
          userName: 'Marc',
          onContextTap: () {},
          onNotificationsTap: () {},
          onAvatarTap: () {},
        ),
        brightness: brightness,
      );

      expect(find.text('Good evening, Marc'), findsOneWidget);
      expect(find.text('Cooking with Princess'), findsOneWidget);
    });

    testWidgets('the context line is the way into couple mode', (
      WidgetTester tester,
    ) async {
      // docs/NAVIGATION_MAP.md §3 keeps couple mode off the tab bar, so this is
      // its entry point and it has to be reachable and announced as one.
      final SemanticsHandle handle = tester.ensureSemantics();
      bool opened = false;

      await pumpComponent(
        tester,
        AppHeader(
          greeting: 'Good evening, Marc',
          context_: 'Cooking with Princess',
          contextEmoji: '❤️',
          userName: 'Marc',
          onContextTap: () => opened = true,
        ),
      );

      expect(
        find.bySemanticsLabel('Cooking with Princess. Open your kitchen'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cooking with Princess'));
      expect(opened, isTrue);

      handle.dispose();
    });

    testWidgets('the actions appear only when they do something', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppHeader(
          greeting: 'Good evening, Marc',
          context_: 'Just cooking for yourself',
          contextEmoji: '👤',
          userName: 'Marc',
        ),
      );

      expect(find.byIcon(AppIcons.notifications), findsNothing);
      expect(find.byType(Avatar), findsNothing);
    });

    testWidgets('the unread dot is announced, not only drawn', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppHeader(
          greeting: 'Good evening, Marc',
          context_: 'Just cooking for yourself',
          contextEmoji: '👤',
          userName: 'Marc',
          hasUnreadNotifications: true,
          onNotificationsTap: () {},
        ),
      );

      expect(
        find.bySemanticsLabel('Notifications, you have unread'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('survives 1.3x on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppHeader(
          greeting: 'Good evening, Bartholomew',
          context_: 'Cooking with Princess Consuela',
          contextEmoji: '❤️',
          userName: 'Bartholomew',
          onContextTap: () {},
          onNotificationsTap: () {},
          onAvatarTap: () {},
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}

/// The decoration of the nearest [DecoratedBox] above [finder].
///
/// Shadow and fill are the whole point of several of these components, and they
/// live on an ancestor of the text rather than on the text itself.
BoxDecoration _decorationAbove(WidgetTester tester, Finder finder) {
  final Finder boxes = find.ancestor(
    of: finder,
    matching: find.byType(DecoratedBox),
  );

  return tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
}
