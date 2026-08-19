import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  group('EmptyState', () {
    testInBothThemes('renders its copy and fires its action', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      int actions = 0;

      await pumpComponent(
        tester,
        EmptyState.favorites(onSpin: () => actions++),
        brightness: brightness,
      );

      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(
        find.text('Spin the wheel and find something you love.'),
        findsOneWidget,
      );

      await tester.tap(find.text("What's Cooking?"));
      expect(actions, 1);
    });

    testWidgets('every named state points back at the core loop', (
      WidgetTester tester,
    ) async {
      // docs/COMPONENTS.md §12: "the action always points back toward the core
      // loop". An empty screen with no way forward is a dead end.
      final List<(Widget, String)> states = <(Widget, String)>[
        (EmptyState.favorites(onSpin: () {}), "What's Cooking?"),
        (EmptyState.history(onSpin: () {}), 'Spin'),
        (EmptyState.pantry(onAddIngredient: () {}), 'Add ingredient'),
        (EmptyState.grocery(onSpin: () {}), 'Spin'),
        (EmptyState.search(onClearFilters: () {}), 'Clear filters'),
        (EmptyState.myMeals(onAddMeal: () {}), 'Add a meal'),
      ];

      for (final (Widget state, String action) in states) {
        await pumpComponent(tester, state);
        expect(
          find.widgetWithText(AppButton, action),
          findsOneWidget,
          reason: 'the $action state should offer its action',
        );
      }
    });

    testWidgets('the illustration is decorative, not announced', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(tester, EmptyState.favorites(onSpin: () {}));

      expect(find.bySemanticsLabel('🍽️'), findsNothing);
      handle.dispose();
    });

    testWidgets('renders without an action', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const EmptyState(title: 'All done', body: 'Nothing left to buy.'),
      );

      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        EmptyState.pantry(onAddIngredient: () {}),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('ErrorState', () {
    testInBothThemes('renders the copy for its cause', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const ErrorState(kind: ErrorStateKind.network),
        brightness: brightness,
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Check your internet and try again.'), findsOneWidget);
    });

    test('every cause carries copy written for a person', () {
      for (final ErrorStateKind kind in ErrorStateKind.values) {
        expect(kind.title, isNotEmpty);
        expect(kind.body, isNotEmpty);
        // docs/design_ui.md §31: never `Exception: PostgrestException`.
        expect(kind.title, isNot(contains('Exception')));
        expect(kind.body, isNot(contains('Exception')));
      }
    });

    testWidgets('retry fires', (WidgetTester tester) async {
      int retries = 0;

      await pumpComponent(
        tester,
        ErrorState(kind: ErrorStateKind.server, onRetry: () => retries++),
      );

      await tester.tap(find.text('Try Again'));
      expect(retries, 1);
    });

    testWidgets('go back only appears where a back path exists', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        ErrorState(kind: ErrorStateKind.server, onRetry: () {}),
      );
      expect(find.text('Go back'), findsNothing);

      await pumpComponent(
        tester,
        ErrorState(
          kind: ErrorStateKind.server,
          onRetry: () {},
          onGoBack: () {},
        ),
      );
      expect(find.text('Go back'), findsOneWidget);
    });

    testWidgets('an error code sits beneath the action, not in the message', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        ErrorState(
          kind: ErrorStateKind.server,
          onRetry: () {},
          errorCode: 'PGRST116',
        ),
      );

      final AppColorScheme colors = tester
          .element(find.text('PGRST116'))
          .colors;

      expect(
        tester.widget<Text>(find.text('PGRST116')).style?.color,
        colors.textDisabled,
        reason: 'a support code must not compete with the message',
      );
      expect(
        tester.getTopLeft(find.text('PGRST116')).dy,
        greaterThan(tester.getTopLeft(find.text('Try Again')).dy),
      );
    });

    testWidgets('a screen can override the copy with something specific', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const ErrorState(
          kind: ErrorStateKind.server,
          title: "We couldn't load your pantry",
        ),
      );

      expect(find.text("We couldn't load your pantry"), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('InlineErrorBanner', () {
    testInBothThemes('renders its message on the error surface', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 320,
          child: InlineErrorBanner(message: "Couldn't save your favourite"),
        ),
        brightness: brightness,
      );

      final AppColorScheme colors = tester
          .element(find.text("Couldn't save your favourite"))
          .colors;

      expect(
        tester
            .widget<Text>(find.text("Couldn't save your favourite"))
            .style
            ?.color,
        colors.error.onSurface,
      );
    });

    testWidgets('offers retry when given one', (WidgetTester tester) async {
      int retries = 0;

      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: InlineErrorBanner(
            message: 'Failed to sync',
            onRetry: () => retries++,
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('AppSkeleton', () {
    testInBothThemes('renders and animates', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(width: 200, height: 100, child: AppSkeleton()),
        brightness: brightness,
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppSkeleton), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('drops the shimmer but keeps the placeholder when motion is '
        'reduced', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const SizedBox(width: 200, height: 100, child: AppSkeleton()),
        reduceMotion: true,
      );

      // The shimmer is decoration; the placeholder is information.
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(AppSkeleton), findsOneWidget);
    });

    testWidgets('a text line takes the documented height', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(width: 200, child: AppSkeleton.textLine()),
      );

      expect(tester.getSize(find.byType(AppSkeleton)).height, 12);
    });

    testWidgets('a narrowed line takes a fraction of the width', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 200,
          child: AppSkeleton.textLine(widthFactor: 0.6),
        ),
      );

      // The painted bar is what narrows; the widget still occupies the full
      // line so a column of them stays left-aligned.
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(AppSkeleton),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .width,
        closeTo(120, 0.5),
      );
    });
  });

  group('LoadingIndicator', () {
    testWidgets('is 20 px and announces itself', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(tester, const LoadingIndicator());

      expect(tester.getSize(find.byType(LoadingIndicator)).width, 20);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);

      handle.dispose();
    });
  });
}
