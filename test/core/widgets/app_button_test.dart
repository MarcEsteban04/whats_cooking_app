import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/widgets.dart';

import '../../support/component_harness.dart';

void main() {
  group('AppButton', () {
    testInBothThemes('renders its label and fires onPressed', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      int taps = 0;

      await pumpComponent(
        tester,
        AppButton.primary(label: 'Spin', onPressed: () => taps++),
        brightness: brightness,
      );

      expect(find.text('Spin'), findsOneWidget);

      await tester.tap(find.text('Spin'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is not tappable', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const AppButton.primary(label: 'Spin', onPressed: null),
      );

      await tester.tap(find.text('Spin'));
      // Nothing to assert but the absence of a crash and of a callback; the
      // meaningful assertion is the semantics one below.
      expect(find.text('Spin'), findsOneWidget);
    });

    testWidgets('a disabled button is not announced as enabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        const AppButton.primary(label: 'Spin', onPressed: null),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Spin')),
        matchesSemantics(
          label: 'Spin',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('loading disables the button', (WidgetTester tester) async {
      int taps = 0;

      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Saving',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(taps, 0, reason: 'a button mid-write must not fire again');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading does not change the width', (
      WidgetTester tester,
    ) async {
      // docs/COMPONENTS.md §1: "Width must not change on entering the loading
      // state — a button that resizes under the thumb causes mis-taps."
      await pumpComponent(
        tester,
        AppButton.primary(label: 'Add to grocery list', onPressed: () {}),
      );
      final double idleWidth = tester.getSize(find.byType(AppButton)).width;

      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Add to grocery list',
          isLoading: true,
          onPressed: () {},
        ),
      );
      final double loadingWidth = tester.getSize(find.byType(AppButton)).width;

      expect(loadingWidth, idleWidth);
    });

    testWidgets('the loading label is hidden from the semantics tree', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppButton.primary(label: 'Saving', isLoading: true, onPressed: () {}),
      );

      // The hidden label holds the width but must not be read out twice, once
      // as the button's label and once as its content.
      expect(find.bySemanticsLabel('Saving'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('every size clears the 48 px touch target', (
      WidgetTester tester,
    ) async {
      for (final AppButtonSize size in AppButtonSize.values) {
        await pumpComponent(
          tester,
          AppButton.primary(label: 'Go', size: size, onPressed: () {}),
        );

        final Size rendered = tester.getSize(find.byType(AppButton));
        expect(
          rendered.height,
          greaterThanOrEqualTo(AppLayout.minTouchTarget),
          reason:
              '${size.name} is ${size.height} px tall and must still present a '
              '48 px target',
        );
      }
    });

    testWidgets('the visual height stays at the specified size', (
      WidgetTester tester,
    ) async {
      // The target grows, the visual does not: a `small` button must still look
      // 40 px tall even though it is 48 px tappable.
      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Go',
          size: AppButtonSize.small,
          onPressed: () {},
        ),
      );

      final Finder surface = find
          .descendant(
            of: find.byType(AppButton),
            matching: find.byType(SizedBox),
          )
          .first;

      expect(tester.getSize(surface).height, AppButtonSize.small.height);
    });

    testWidgets('full width fills its parent', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        SizedBox(
          width: 300,
          child: AppButton.primary(
            label: 'Accept',
            isFullWidth: true,
            onPressed: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppButton)).width, 300);
    });

    testWidgets('renders leading and trailing icons', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Spin',
          leadingIcon: AppIcons.spin,
          trailingIcon: AppIcons.forward,
          onPressed: () {},
        ),
      );

      expect(find.byIcon(AppIcons.spin), findsOneWidget);
      expect(find.byIcon(AppIcons.forward), findsOneWidget);
    });

    testWidgets('the brand variant pairs brand green with dark text', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppButton.brand(label: 'SPIN', onPressed: () {}),
      );

      final BuildContext context = tester.element(find.text('SPIN'));
      final AppColorScheme colors = context.colors;
      final DecoratedBox surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      expect(
        (surface.decoration as BoxDecoration).color,
        colors.primaryBrand,
        reason: 'SPIN is the one place the identity green is a fill',
      );
      expect(
        tester.widget<Text>(find.text('SPIN')).style?.color,
        colors.onPrimaryBrand,
      );
    });

    testWidgets('survives 1.3x text scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Add ingredients to grocery',
          isFullWidth: true,
          onPressed: () {},
        ),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('AppIconButton', () {
    testWidgets('presents a 48 px target around a small glyph', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppIconButton(
          icon: AppIcons.favorite,
          semanticLabel: 'Save to favourites',
          iconSize: AppIconSize.sm,
          onPressed: () {},
        ),
      );

      final Size size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(AppLayout.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppLayout.minTouchTarget));
    });

    testWidgets('carries its semantic label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppIconButton(
          icon: AppIcons.favorite,
          semanticLabel: 'Save to favourites',
          onPressed: () {},
        ),
      );

      expect(find.bySemanticsLabel('Save to favourites'), findsOneWidget);
      handle.dispose();
    });
  });
}
