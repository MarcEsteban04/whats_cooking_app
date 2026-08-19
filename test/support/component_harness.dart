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
