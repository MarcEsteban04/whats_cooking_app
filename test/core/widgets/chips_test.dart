import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  Color? fillOf(WidgetTester tester, Type chipType) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(chipType),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as BoxDecoration).color;
  }

  group('AppFilterChip', () {
    testInBothThemes('reports the opposite of its current state', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      bool? reported;

      await pumpComponent(
        tester,
        AppFilterChip(
          label: 'Filipino',
          isSelected: false,
          onSelected: (bool value) => reported = value,
        ),
        brightness: brightness,
      );

      await tester.tap(find.text('Filipino'));
      expect(reported, isTrue);
    });

    testWidgets('selection is the interactive green, not a pastel', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppFilterChip(label: 'Filipino', isSelected: true, onSelected: (_) {}),
      );

      final AppColorScheme colors = tester
          .element(find.text('Filipino'))
          .colors;

      expect(fillOf(tester, AppFilterChip), colors.primary);
      expect(
        tester.widget<Text>(find.text('Filipino')).style?.color,
        colors.textOnPrimary,
      );
    });

    testWidgets('announces its selection state rather than relying on colour', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppFilterChip(label: 'Filipino', isSelected: true, onSelected: (_) {}),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Filipino')).hint,
        'Selected',
      );

      handle.dispose();
    });

    testWidgets('a disabled chip is not announced as tappable', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        const AppFilterChip(
          label: 'Filipino',
          isSelected: false,
          onSelected: null,
        ),
      );

      // Painting it grey is not enough — a screen reader must not offer it.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Filipino')),
        matchesSemantics(
          label: 'Filipino',
          hint: 'Not selected',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('renders an optional count', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppFilterChip(
          label: 'Filipino',
          isSelected: false,
          count: 12,
          onSelected: (_) {},
        ),
      );

      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('clears the 48 px target despite a 36 px visual', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppFilterChip(label: 'Filipino', isSelected: false, onSelected: (_) {}),
      );

      expect(
        tester.getSize(find.byType(AppFilterChip)).height,
        greaterThanOrEqualTo(AppLayout.minTouchTarget),
      );
    });
  });

  group('CuisineChip', () {
    testWidgets('selected carries that cuisine pastel and its foreground', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        CuisineChip(cuisine: 'Japanese', isSelected: true, onSelected: (_) {}),
      );

      final AppColorScheme colors = tester
          .element(find.text('Japanese'))
          .colors;
      final AppAccent accent = colors.accentFor('Japanese');

      expect(fillOf(tester, CuisineChip), accent.background);
      expect(
        tester.widget<Text>(find.text('Japanese')).style?.color,
        accent.foreground,
        reason: 'a pastel is only ever correct with its paired foreground',
      );
    });

    testWidgets('the same cuisine takes the same accent every time', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, const SizedBox.shrink());
      final AppColorScheme colors = tester
          .element(find.byType(SizedBox).first)
          .colors;

      expect(colors.accentFor('Japanese'), colors.accentFor('Japanese'));
    });

    testWidgets('the emoji is kept out of the semantics tree', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        CuisineChip(
          cuisine: 'Japanese',
          emoji: '🍣',
          isSelected: false,
          onSelected: (_) {},
        ),
      );

      // The label already says "Japanese"; reading the emoji too is noise.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Japanese')).label,
        'Japanese',
      );

      handle.dispose();
    });
  });

  group('MetadataPill', () {
    testInBothThemes('renders its label', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const MetadataPill(label: '30 min'),
        brightness: brightness,
      );

      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('the numeric variant uses tabular figures', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const MetadataPill(label: '₱220', isNumeric: true),
      );

      expect(
        tester.widget<Text>(find.text('₱220')).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('grows rather than clipping at 1.3x scale', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const MetadataPill(label: '2 servings'),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}
