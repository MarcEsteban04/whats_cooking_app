import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  String? notEmpty(String value) => value.isEmpty ? 'Enter a name' : null;

  group('AppTextField', () {
    testInBothThemes('renders its label, hint and helper', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const AppTextField(
          label: 'Meal name',
          hint: 'Chicken Adobo',
          helperText: 'What you call it at home',
        ),
        brightness: brightness,
      );

      expect(find.text('Meal name'), findsOneWidget);
      expect(find.text('Chicken Adobo'), findsOneWidget);
      expect(find.text('What you call it at home'), findsOneWidget);
    });

    testWidgets('does not validate while typing', (WidgetTester tester) async {
      // docs/COMPONENTS.md §2: "Validation fires on blur, not on every
      // keystroke. Errors while typing are hostile."
      await pumpComponent(
        tester,
        AppTextField(label: 'Meal name', validator: notEmpty),
      );

      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(
        find.text('Enter a name'),
        findsNothing,
        reason: 'an empty field mid-edit must not be scolded yet',
      );
    });

    testWidgets('validates on blur', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        Column(
          children: <Widget>[
            AppTextField(label: 'Meal name', validator: notEmpty),
            const AppTextField(label: 'Cuisine'),
          ],
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      // Moving focus to the second field blurs the first.
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('an error replaces the helper text rather than joining it', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppTextField(
          label: 'Meal name',
          helperText: 'What you call it at home',
          errorText: 'That name is taken',
        ),
      );

      expect(find.text('That name is taken'), findsOneWidget);
      expect(
        find.text('What you call it at home'),
        findsNothing,
        reason: 'the error takes the helper line, it does not add a line',
      );
    });

    testWidgets('gaining an error does not move the field', (
      WidgetTester tester,
    ) async {
      // §2: "the field must not shift the layout when an error appears.
      // Reserve the line height."
      await pumpComponent(
        tester,
        Column(
          children: <Widget>[
            AppTextField(label: 'Meal name', validator: notEmpty),
            const AppTextField(label: 'Cuisine'),
            const Text('below'),
          ],
        ),
      );
      final Offset before = tester.getTopLeft(find.text('below'));

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      // Focus has to land on something focusable to blur the first field —
      // tapping inert text leaves it focused.
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('below')),
        before,
        reason: 'the reserved helper line should absorb the error',
      );
    });

    testWidgets('a password field starts obscured and can be revealed', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppTextField(label: 'Password', isObscured: true),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('Show password'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    });

    testWidgets('reports every keystroke through onChanged', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];

      await pumpComponent(
        tester,
        AppTextField(label: 'Search', onChanged: changes.add),
      );

      await tester.enterText(find.byType(TextField), 'adobo');
      expect(changes, <String>['adobo']);
    });

    testWidgets('survives 1.3x text scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppTextField(
          label: 'Maximum cooking time in minutes',
          helperText: 'We will only suggest meals you have time for',
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('SearchField', () {
    testWidgets('debounces before reporting a search', (
      WidgetTester tester,
    ) async {
      final List<String> searches = <String>[];

      await pumpComponent(
        tester,
        SearchField(
          onSearch: searches.add,
          debounce: const Duration(milliseconds: 300),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ado');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'adobo');
      await tester.pump(const Duration(milliseconds: 100));

      expect(searches, isEmpty, reason: 'still typing');

      await tester.pump(const Duration(milliseconds: 300));

      expect(searches, <String>[
        'adobo',
      ], reason: 'one query for five keystrokes');
    });

    testWidgets('the clear button appears with text and searches at once', (
      WidgetTester tester,
    ) async {
      final List<String> searches = <String>[];

      await pumpComponent(tester, SearchField(onSearch: searches.add));

      expect(find.bySemanticsLabel('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'adobo');
      await tester.pump();
      expect(find.bySemanticsLabel('Clear search'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pump();

      expect(searches, <String>[
        '',
      ], reason: 'clearing is explicit, so it does not wait for the debounce');
      expect(find.bySemanticsLabel('Clear search'), findsNothing);
    });

    testWidgets('submitting skips the debounce', (WidgetTester tester) async {
      final List<String> searches = <String>[];

      await pumpComponent(tester, SearchField(onSearch: searches.add));

      await tester.enterText(find.byType(TextField), 'katsu');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(searches, <String>['katsu']);
    });

    testWidgets('a pending debounce does not fire after disposal', (
      WidgetTester tester,
    ) async {
      // The classic debounce leak: a timer that outlives its State and calls
      // setState on a dead widget.
      final List<String> searches = <String>[];

      await pumpComponent(tester, SearchField(onSearch: searches.add));
      await tester.enterText(find.byType(TextField), 'sinigang');

      await pumpComponent(tester, const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      expect(searches, isEmpty);
      expectNoOverflow(tester);
    });
  });
}
