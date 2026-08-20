import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  const MealCardData adobo = MealCardData(
    id: 'chicken-adobo',
    name: 'Chicken Adobo',
    cuisine: 'Filipino',
    cookingTimeMinutes: 35,
    estimatedCost: 180,
    servings: 2,
    description: 'Soy, vinegar, garlic and patience.',
    category: 'Dinner',
    difficulty: 'Easy',
  );

  group('MealCardData', () {
    test('builds its metadata line from what is present', () {
      expect(adobo.contextLabel, 'Filipino · Dinner');
      expect(adobo.formattedCost, '₱180');
      expect(adobo.formattedCostPerServing, '₱90 a head');
    });

    test('drops missing parts rather than leaving a dangling separator', () {
      const MealCardData sparse = MealCardData(id: 'x', name: 'Mystery');

      expect(sparse.contextLabel, isEmpty);
      expect(sparse.formattedCost, isNull);
    });

    test('a cuisine with no time still reads correctly', () {
      const MealCardData partial = MealCardData(
        id: 'x',
        name: 'Mystery',
        cuisine: 'Japanese',
      );

      expect(partial.contextLabel, 'Japanese');
    });
  });

  group('MealCard', () {
    testInBothThemes('the feed form shows name, metadata and cost', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(width: 320, child: MealCard(meal: adobo)),
        brightness: brightness,
      );

      expect(find.text('Chicken Adobo'), findsOneWidget);
      expect(find.text('Filipino'), findsOneWidget);
      expect(find.text('₱90 a head'), findsOneWidget);
      expect(find.text('35 min'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('the whole card navigates to detail', (
      WidgetTester tester,
    ) async {
      int taps = 0;

      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: MealCard(meal: adobo, onTap: () => taps++),
        ),
      );

      await tester.tap(find.text('Chicken Adobo'));
      expect(taps, 1);
    });

    testWidgets('the heart does not trigger navigation', (
      WidgetTester tester,
    ) async {
      // docs/COMPONENTS.md §4: "The heart is an independent target and must not
      // trigger navigation." Tapping it while the card is also tappable is the
      // exact case that regresses.
      int cardTaps = 0;
      bool? favorited;

      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: MealCard(
            meal: adobo,
            onTap: () => cardTaps++,
            onFavoriteToggled: (bool value) => favorited = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(RegExp('Save Chicken Adobo')));
      await tester.pumpAndSettle();

      expect(favorited, isTrue);
      expect(cardTaps, 0, reason: 'the heart must not also open the meal');
    });

    testWidgets('the heart is hidden when favouriting is not on offer', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(width: 320, child: MealCard(meal: adobo)),
      );

      expect(find.byType(FavoriteButton), findsNothing);
    });

    testWidgets('an already-favourited meal offers to remove', (
      WidgetTester tester,
    ) async {
      bool? favorited;

      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: MealCard(
            meal: const MealCardData(
              id: 'chicken-adobo',
              name: 'Chicken Adobo',
              isFavorite: true,
            ),
            onFavoriteToggled: (bool value) => favorited = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(RegExp('Remove Chicken Adobo')));
      await tester.pumpAndSettle();

      expect(favorited, isFalse);
    });

    testWidgets('the compact form fits a row', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 320,
          child: MealCard(meal: adobo, variant: MealCardVariant.compact),
        ),
      );

      expect(find.text('Chicken Adobo'), findsOneWidget);
      expect(find.text('Filipino · 35 min · ₱180'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('the result form leads with the name and metadata pills', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 340,
          child: MealCard(
            meal: MealCardData(
              id: 'chicken-katsu',
              name: 'Chicken Katsu',
              cookingTimeMinutes: 30,
              estimatedCost: 220,
              servings: 2,
              contextLine: 'Loved by both of you',
            ),
            variant: MealCardVariant.result,
          ),
        ),
      );

      expect(find.text('Chicken Katsu'), findsOneWidget);
      expect(find.text('Loved by both of you'), findsOneWidget);
      expect(find.text('₱220'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('2 servings'), findsOneWidget);
      expect(find.byType(MetadataPill), findsNWidgets(3));
    });

    testWidgets('the fallback colour is stable for a given meal', (
      WidgetTester tester,
    ) async {
      // docs/DESIGN_SYSTEM.md §9: the fallback is "keyed off the meal ID — so a
      // missing photo still looks composed, and looks the *same* on every
      // launch". A reshuffling fallback reads as a bug.
      await pumpComponent(tester, const SizedBox.shrink());
      final AppColorScheme colors = tester
          .element(find.byType(SizedBox).first)
          .colors;

      expect(
        colors.accentFor('chicken-adobo'),
        colors.accentFor('chicken-adobo'),
      );
      expect(
        colors.accentFor('chicken-adobo'),
        isNot(colors.accentFor('chicken-adobo-2')),
        reason: 'different meals should generally differ',
      );
    });

    testWidgets('the feed form survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const MealCard(
          meal: MealCardData(
            id: 'x',
            name: 'Slow-roasted lechon belly with liver sauce',
            cuisine: 'Filipino',
            cookingTimeMinutes: 240,
            estimatedCost: 1250,
          ),
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });

    testWidgets('the result form survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const MealCard(
          meal: MealCardData(
            id: 'x',
            name: 'Chicken Katsu',
            cookingTimeMinutes: 30,
            estimatedCost: 220,
            servings: 2,
          ),
          variant: MealCardVariant.result,
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}
