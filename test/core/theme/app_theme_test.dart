import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/main.dart';

/// The Sprint 07 verification checklist from docs/DESIGN_SYSTEM.md §13, as
/// tests rather than as boxes someone ticked once.
void main() {
  setUpAll(() {
    // Inter would otherwise be fetched over the network on first use. Tests must
    // not depend on that; the metrics under test are ours, not the font's.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('both themes are built from tokens', () {
    for (final (String name, ThemeData theme) in <(String, ThemeData)>[
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      group(name, () {
        test('uses Material 3', () {
          expect(theme.useMaterial3, isTrue);
        });

        test('exposes all three token extensions', () {
          expect(theme.extension<AppColorScheme>(), isNotNull);
          expect(theme.extension<AppShadows>(), isNotNull);
          expect(theme.extension<AppTextStyles>(), isNotNull);
        });

        test('the scaffold background is the design system background', () {
          expect(
            theme.scaffoldBackgroundColor,
            theme.extension<AppColorScheme>()!.background,
          );
        });

        test('Material elevation tinting is switched off', () {
          // Elevation is expressed by shadows on light and by lighter surfaces
          // on dark. Material's own primary-coloured tint would add a third,
          // unwanted mechanism on top of both.
          expect(theme.colorScheme.surfaceTint, Colors.transparent);
          expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
          expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        });

        test('press feedback is a scale, not an ink ripple', () {
          expect(theme.splashFactory, NoSplash.splashFactory);
        });

        test('buttons are pills at the large size', () {
          final ButtonStyle? style = theme.filledButtonTheme.style;
          expect(style?.shape?.resolve(<WidgetState>{}), isA<StadiumBorder>());
          expect(
            style?.minimumSize?.resolve(<WidgetState>{})?.height,
            56,
            reason: 'docs/COMPONENTS.md §1 — large is the default',
          );
        });

        test('the pressed button fill is the pressed token', () {
          final AppColorScheme colors = theme.extension<AppColorScheme>()!;
          final ButtonStyle? style = theme.filledButtonTheme.style;

          expect(
            style?.backgroundColor?.resolve(<WidgetState>{WidgetState.pressed}),
            colors.primaryPressed,
          );
          expect(
            style?.backgroundColor?.resolve(<WidgetState>{}),
            colors.primary,
          );
        });

        test('inputs are less rounded than buttons', () {
          // docs/COMPONENTS.md §2 — radiusMd, deliberately not the button pill.
          final InputBorder? border = theme.inputDecorationTheme.border;
          expect(border, isA<OutlineInputBorder>());
          expect(
            (border! as OutlineInputBorder).borderRadius,
            AppRadius.borderMd,
          );
        });

        test('the focused input border is 2 px of primary', () {
          final OutlineInputBorder focused =
              theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
          expect(focused.borderSide.width, 2);
          expect(
            focused.borderSide.color,
            theme.extension<AppColorScheme>()!.primary,
          );
        });

        test('helper and error text reserve two lines so the field cannot '
            'shift', () {
          expect(theme.inputDecorationTheme.helperMaxLines, 2);
          expect(theme.inputDecorationTheme.errorMaxLines, 2);
        });

        test('cards are radiusXl with no Material elevation', () {
          expect(theme.cardTheme.elevation, 0);
          expect(
            theme.cardTheme.shape,
            const RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
          );
        });

        test('bottom sheets take radius2xl top corners', () {
          expect(
            theme.bottomSheetTheme.shape,
            RoundedRectangleBorder(borderRadius: AppRadius.top(AppRadius.xxl)),
          );
        });
      });
    }
  });

  group('shadows are brightness-aware (§6)', () {
    test('the light theme carries all five elevations', () {
      final AppShadows shadows = AppTheme.light().extension<AppShadows>()!;

      expect(shadows.xs, isNotEmpty);
      expect(shadows.sm, isNotEmpty);
      expect(shadows.md, isNotEmpty);
      expect(shadows.lg, isNotEmpty);
      expect(shadows.xl, isNotEmpty);
    });

    test('the dark theme resolves every elevation to none', () {
      // Not "the same shadows at a lower alpha" — none at all. A shadow on a
      // dark ground is invisible, so elevation is carried by surface steps.
      final AppShadows shadows = AppTheme.dark().extension<AppShadows>()!;

      expect(shadows.xs, isEmpty);
      expect(shadows.sm, isEmpty);
      expect(shadows.md, isEmpty);
      expect(shadows.lg, isEmpty);
      expect(shadows.xl, isEmpty);
    });

    test('dark surfaces step upward to express elevation instead', () {
      final AppColorScheme dark = AppTheme.dark().extension<AppColorScheme>()!;

      expect(
        dark.background.computeLuminance(),
        lessThan(dark.surface.computeLuminance()),
      );
      expect(
        dark.surface.computeLuminance(),
        lessThan(dark.surfaceMuted.computeLuminance()),
      );
      expect(
        dark.surfaceMuted.computeLuminance(),
        lessThan(dark.surfaceHigh.computeLuminance()),
      );
    });

    test('the scrim is heavier in dark than in light', () {
      expect(
        AppTheme.dark().extension<AppShadows>()!.scrim.a,
        greaterThan(AppTheme.light().extension<AppShadows>()!.scrim.a),
      );
    });
  });

  group('the type scale matches §3', () {
    final AppTextStyles text = AppTheme.light().extension<AppTextStyles>()!;

    test('displayLarge is 40 over 44 at weight 700 with negative tracking', () {
      expect(text.displayLarge.fontSize, 40);
      expect(text.displayLarge.height, closeTo(44 / 40, 0.001));
      expect(text.displayLarge.fontWeight, FontWeight.w700);
      expect(text.displayLarge.letterSpacing, -0.5);
    });

    test('bodyMedium is 15 over 22 at weight 400', () {
      expect(text.bodyMedium.fontSize, 15);
      expect(text.bodyMedium.height, closeTo(22 / 15, 0.001));
      expect(text.bodyMedium.fontWeight, FontWeight.w400);
    });

    test('label is the button style at 15 semibold', () {
      expect(text.label.fontSize, 15);
      expect(text.label.fontWeight, FontWeight.w600);
    });

    test('overline carries positive tracking', () {
      expect(text.overline.fontSize, 11);
      expect(text.overline.letterSpacing, 0.8);
    });

    test('numeric enables tabular figures so prices do not jitter', () {
      expect(
        text.numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('no body token drops below the 13 px floor', () {
      for (final TextStyle style in <TextStyle>[
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.metadata,
        text.labelSmall,
      ]) {
        expect(style.fontSize, greaterThanOrEqualTo(13));
      }
    });

    test('headlines use negative tracking and small text does not', () {
      expect(text.headlineLarge.letterSpacing, isNegative);
      expect(text.headlineMedium.letterSpacing, isNegative);
      expect(text.titleMedium.letterSpacing, isNot(isNegative));
      expect(text.labelSmall.letterSpacing, isNot(isNegative));
    });

    test('metadata sits on textTertiary, the tightest pairing in the '
        'system', () {
      final AppColorScheme colors = AppTheme.light()
          .extension<AppColorScheme>()!;
      expect(text.metadata.color, colors.textTertiary);
    });

    test('the Material text theme is populated for framework widgets', () {
      final TextTheme material = AppTheme.light().textTheme;

      expect(material.displayLarge?.fontSize, 40);
      expect(material.bodyMedium?.fontSize, 15);
      expect(
        material.labelLarge?.fontSize,
        15,
        reason: 'labelLarge is `label`',
      );
      expect(
        material.labelSmall?.fontSize,
        11,
        reason: 'labelSmall carries `overline`',
      );
    });
  });

  group('accents', () {
    test('a seed always resolves to the same accent', () {
      // A photo-less meal must fall back to the *same* pastel on every launch
      // (§9) — a fallback that reshuffles looks broken, not composed.
      final AppColorScheme colors = AppColorScheme.light();

      expect(
        colors.accentFor('chicken-adobo'),
        colors.accentFor('chicken-adobo'),
      );
      expect(colors.accents, hasLength(6));
    });

    test('an empty seed still resolves', () {
      expect(AppColorScheme.light().accentFor(''), isNotNull);
    });
  });

  group('text scaling is clamped to 0.85–1.3 (§3)', () {
    Future<double> effectiveScaleFor(
      WidgetTester tester,
      double osScale,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = osScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ProviderScope(child: WhatsCookingApp()));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text("What's Cooking?"));
      // Measured rather than read off the scaler so the assertion is about what
      // text actually does.
      return MediaQuery.textScalerOf(context).scale(10) / 10;
    }

    testWidgets('an OS scale above the ceiling is clamped down', (
      WidgetTester tester,
    ) async {
      expect(await effectiveScaleFor(tester, 2.5), closeTo(1.3, 0.001));
    });

    testWidgets('an OS scale below the floor is clamped up', (
      WidgetTester tester,
    ) async {
      expect(await effectiveScaleFor(tester, 0.5), closeTo(0.85, 0.001));
    });

    testWidgets('a scale inside the range passes through', (
      WidgetTester tester,
    ) async {
      expect(await effectiveScaleFor(tester, 1.15), closeTo(1.15, 0.001));
    });
  });

  group('motion honours reduce-motion (§7)', () {
    testWidgets('durations collapse to zero when animations are disabled', (
      WidgetTester tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(AppMotion.prefersReducedMotion(capturedContext), isTrue);
      expect(AppMotion.resolve(capturedContext, AppMotion.slow), Duration.zero);
    });

    testWidgets('durations pass through otherwise', (
      WidgetTester tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        AppMotion.resolve(capturedContext, AppMotion.slow),
        AppMotion.slow,
      );
    });

    test('the roulette stays inside its hard cap', () {
      expect(
        AppRouletteMotion.total,
        lessThanOrEqualTo(AppMotion.spinMaximum),
        reason: 'docs/DESIGN_SYSTEM.md §7 caps the spin at 3000 ms',
      );
    });
  });

  group('breakpoints (§10)', () {
    test('widths resolve to the documented classes', () {
      expect(AppBreakpoints.fromWidth(320), AppBreakpoint.compact);
      expect(AppBreakpoints.fromWidth(599), AppBreakpoint.compact);
      expect(AppBreakpoints.fromWidth(600), AppBreakpoint.medium);
      expect(AppBreakpoints.fromWidth(903), AppBreakpoint.medium);
      expect(AppBreakpoints.fromWidth(904), AppBreakpoint.expanded);
    });

    test('the category grid and meal feed widen with the class', () {
      expect(AppBreakpoint.compact.categoryGridColumns, 3);
      expect(AppBreakpoint.medium.categoryGridColumns, 4);
      expect(AppBreakpoint.compact.mealFeedColumns, 1);
      expect(AppBreakpoint.medium.mealFeedColumns, 2);
    });

    test('content is only capped above compact', () {
      expect(AppBreakpoint.compact.capsContentWidth, isFalse);
      expect(AppBreakpoint.medium.capsContentWidth, isTrue);
      expect(AppBreakpoint.expanded.capsContentWidth, isTrue);
    });
  });

  group('radius nesting (§5)', () {
    test('an inner radius steps down by its padding', () {
      expect(AppRadius.nested(outer: AppRadius.xxl, padding: 8), 20);
      expect(AppRadius.nested(outer: AppRadius.xl, padding: 4), 20);
    });

    test('nesting never squares off', () {
      expect(
        AppRadius.nested(outer: AppRadius.xl, padding: AppRadius.xl),
        AppRadius.sm,
      );
    });
  });
}
