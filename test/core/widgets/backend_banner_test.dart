import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/feedback/backend_banner.dart';

/// The banner exists because of a bug that was not a crash.
///
/// Run without `--dart-define-from-file=config/development.json` and the app
/// falls back to in-memory auth: you can sign up, reach onboarding, and lose the
/// account on the next launch, with nothing on screen having said so. Keeping
/// the app runnable without credentials is right; letting someone invest in an
/// account that cannot survive a restart is not.
void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    BackendStatus status, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendStatusProvider.overrideWith((Ref ref) => status)],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              size: size,
            ),
            child: const Scaffold(body: BackendBanner()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BackendBanner', () {
    testWidgets('says accounts will not survive a restart', (
      WidgetTester tester,
    ) async {
      // The sentence that would have saved the afternoon.
      await pumpBanner(tester, BackendStatus.notConfigured);

      expect(
        find.text('No backend — accounts will not survive a restart'),
        findsOneWidget,
      );
      // And the diagnosis of why, which names the fix.
      expect(find.textContaining('development.json'), findsOneWidget);
    });

    testWidgets('is invisible when the backend is healthy', (
      WidgetTester tester,
    ) async {
      // The normal case, and it must cost nothing — no banner, and no gap where
      // one would have been.
      await pumpBanner(tester, BackendStatus.healthy);

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSize(find.byType(BackendBanner)),
        Size.zero,
        reason: 'a healthy backend should not reserve layout space',
      );
    });

    // Four states rather than a bool, because "it did not work" has different
    // fixes and telling them apart is the whole value of the probe. One test
    // each: re-pumping a second override into the same tree leaves the first
    // one resolved, so a loop here would silently assert the same status twice.
    testWidgets('names an unreachable host', (WidgetTester tester) async {
      await pumpBanner(tester, BackendStatus.unreachable);

      expect(find.text('Cannot reach the backend'), findsOneWidget);
      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    });

    testWidgets('names a missing schema', (WidgetTester tester) async {
      // The reachable-but-empty case, which otherwise looks identical to a
      // broken app.
      await pumpBanner(tester, BackendStatus.schemaUnavailable);

      expect(find.text('Backend reached, schema missing'), findsOneWidget);
      expect(find.textContaining('schema.sql'), findsOneWidget);
    });

    testWidgets('is announced, not only drawn', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpBanner(tester, BackendStatus.notConfigured);

      expect(
        find.bySemanticsLabel(
          RegExp('accounts will not survive', caseSensitive: false),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        BackendStatus.notConfigured,
        textScale: AppTypography.maxTextScale,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light', (WidgetTester tester) async {
      await pumpBanner(tester, BackendStatus.notConfigured);

      expect(find.byType(BackendBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark', (WidgetTester tester) async {
      await pumpBanner(
        tester,
        BackendStatus.notConfigured,
        brightness: Brightness.dark,
      );

      expect(find.byType(BackendBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
