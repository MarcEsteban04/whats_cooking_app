import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  group('AppBottomSheet', () {
    testInBothThemes('renders its title, subtitle, body and action', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        AppBottomSheet(
          title: 'Tonight’s budget',
          subtitle: 'We will only suggest meals that fit',
          action: AppButton.primary(label: 'Apply', onPressed: () {}),
          child: const Text('body'),
        ),
        brightness: brightness,
      );

      expect(find.text('Tonight’s budget'), findsOneWidget);
      expect(find.text('We will only suggest meals that fit'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('never exceeds 90% of the screen', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppBottomSheet(
          title: 'Filters',
          child: Column(
            children: List<Widget>.generate(
              40,
              (int index) => ListTile(title: Text('Row $index')),
            ),
          ),
        ),
        surfaceSize: const Size(400, 800),
      );

      expect(
        tester.getSize(find.byType(AppBottomSheet)).height,
        lessThanOrEqualTo(800 * 0.9),
        reason: 'a sheet that fills the screen stops reading as a layer',
      );
      expectNoOverflow(tester);
    });

    testWidgets('renders without a title or action', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppBottomSheet(child: Text('just content')),
      );

      expect(find.text('just content'), findsOneWidget);
    });
  });

  group('ConfirmationDialog', () {
    testInBothThemes('renders its title, body and both actions', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const ConfirmationDialog(
          title: 'Delete this meal?',
          body: 'It will be removed from your history.',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
        brightness: brightness,
      );

      expect(find.text('Delete this meal?'), findsOneWidget);
      expect(
        find.text('It will be removed from your history.'),
        findsOneWidget,
      );
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirming completes true', (WidgetTester tester) async {
      bool? result;

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => AppButton.primary(
            label: 'Open',
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context,
                title: 'Leave household?',
                confirmLabel: 'Leave',
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancelling completes false', (WidgetTester tester) async {
      bool? result;

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => AppButton.primary(
            label: 'Open',
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context,
                title: 'Leave household?',
                confirmLabel: 'Leave',
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('dismissing by barrier completes false, never null', (
      WidgetTester tester,
    ) async {
      // So a caller never has to treat a dismissal as a third outcome.
      bool? result;

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) => AppButton.primary(
            label: 'Open',
            onPressed: () async {
              result = await ConfirmationDialog.show(
                context,
                title: 'Leave household?',
                confirmLabel: 'Leave',
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('the confirm action sits above cancel', (
      WidgetTester tester,
    ) async {
      // A row of two equal buttons makes the destructive one as easy to hit as
      // the safe one, so they are stacked with confirm on top.
      await pumpComponent(
        tester,
        const ConfirmationDialog(
          title: 'Delete this meal?',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
      );

      expect(
        tester.getTopLeft(find.text('Delete')).dy,
        lessThan(tester.getTopLeft(find.text('Cancel')).dy),
      );
    });

    testWidgets('a destructive confirm uses the error fill', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const ConfirmationDialog(
          title: 'Delete this meal?',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
      );

      final AppColorScheme colors = tester.element(find.text('Delete')).colors;
      final DecoratedBox surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.widgetWithText(AppButton, 'Delete'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      expect((surface.decoration as BoxDecoration).color, colors.error.color);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const ConfirmationDialog(
          title: 'Remove Princess from your household?',
          body: 'You will stop sharing meals, pantry and grocery lists.',
          confirmLabel: 'Remove',
          isDestructive: true,
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}
