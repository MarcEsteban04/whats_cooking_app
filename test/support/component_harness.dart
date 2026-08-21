import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// Test support for the shared components.
///
/// Every component in docs/COMPONENTS.md has the same definition of done: it
/// renders in light and dark, survives 1.3x text scale, and fits a 320 px
/// screen. Those are three variations of the same setup, so they live here
/// rather than being re-typed in nine test files.

/// The narrowest device the design supports (docs/DESIGN_SYSTEM.md §10).
const Size kSmallPhone = Size(320, 640);

/// Pumps [child] inside the real application theme.
///
/// The real theme, not a stub: a component that reads `context.colors` is
/// testing its own token wiring as much as its layout, and a fake theme would
/// let a missing extension pass.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size? surfaceSize,
  bool reduceMotion = false,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          size: surfaceSize ?? const Size(400, 800),
        ),
        // Scaffold so anything relying on Material ancestors — ink, dialogs,
        // text fields — behaves as it does in the app.
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

/// Runs [body] once per brightness, so "renders in light and dark" is a fact
/// about the test rather than a comment in the spec.
void testInBothThemes(
  String description,
  Future<void> Function(WidgetTester tester, Brightness brightness) body,
) {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('$description (${brightness.name})', (WidgetTester tester) {
      return body(tester, brightness);
    });
  }
}

/// Asserts nothing overflowed its constraints.
///
/// Flutter reports a `RenderFlex` overflow by handing an exception to the test
/// binding rather than by failing an assertion, so without checking for it a
/// truncating layout passes a widget test in silence — which is exactly the
/// failure mode the 1.3x and 320 px requirements exist to catch.
void expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'the layout overflowed its constraints',
  );
}

/// Pumps [child] inside a scrolling list, which is where it actually lives.
///
/// **This is the harness that would have caught the bug three times.**
/// [pumpComponent] wraps its child in a `Center`, which hands down a *bounded*
/// height — and every dashboard component passed under it. The real screens put
/// the same components inside a `ListView` or a `SliverList`, which hands down
/// `maxHeight: infinity`, and three separate widgets shipped a
/// `CrossAxisAlignment.stretch` inside a `Row` that only fails there:
///
/// * the meal card's cuisine rail, which took the whole feed down;
/// * `StatTrio`'s dividers;
/// * `DashboardActionRow`'s dividers.
///
/// "BoxConstraints forces an infinite height" is not a subtle failure — it is a
/// red screen — and it reached a device every time because no test ever gave a
/// component an unbounded parent. Any new component that draws a full-height
/// divider, a rail or a stretched child belongs in this harness.
Future<void> pumpInList(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: surfaceSize ?? const Size(400, 800),
        ),
        child: Scaffold(
          body: ListView(
            // Padding rather than a bare child, so a component that assumes it
            // has the screen margins around it lays out as it does in the app.
            padding: const EdgeInsets.all(16),
            children: <Widget>[child],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Asserts what [build] returns survives an unbounded parent, both themes, 1.3x
/// and 320 px.
///
/// The whole definition of done for a dashboard component in one call, because a
/// component that only gets one of the four checked is a component that will fail
/// on one of the other three.
void testInList(String description, Widget Function() build) {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('$description under a ListView (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await pumpInList(tester, build(), brightness: brightness);
      expectNoOverflow(tester);
    });
  }

  testWidgets('$description under a ListView at 1.3x on a 320 px screen', (
    WidgetTester tester,
  ) async {
    await pumpInList(
      tester,
      build(),
      textScale: AppTypography.maxTextScale,
      surfaceSize: kSmallPhone,
    );
    expectNoOverflow(tester);
  });
}
