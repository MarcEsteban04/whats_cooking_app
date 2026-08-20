import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/app_colors.dart';
import 'package:whats_cooking/core/theme/app_theme.dart';

/// docs/DESIGN_SYSTEM.md §11: "Every ratio in this document is computed, not
/// estimated. Re-verify after any palette change."
///
/// This is that verification. It asserts the *stated* ratio for every pair the
/// design system quotes a number for, so a palette edit that quietly drops a
/// pairing below AA fails here rather than in an accessibility audit after
/// launch. The tolerance is for the document's two-decimal rounding, not for
/// slack in the requirement.
void main() {
  const double tolerance = 0.02;

  /// WCAG 2.1 relative luminance.
  double luminance(Color color) {
    double channel(double value) {
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// WCAG 2.1 contrast ratio between two opaque colours.
  double ratio(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double lighter = math.max(la, lb);
    final double darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  void expectRatio(Color foreground, Color background, double stated) {
    expect(
      ratio(foreground, background),
      closeTo(stated, tolerance),
      reason:
          'contrast between $foreground and $background should be $stated '
          'as documented in docs/DESIGN_SYSTEM.md',
    );
  }

  /// AA for normal text.
  void expectPassesAA(Color foreground, Color background, String pair) {
    expect(
      ratio(foreground, background),
      greaterThanOrEqualTo(4.5),
      reason: '$pair must reach 4.5:1 for normal text',
    );
  }

  group('§2.2 ink carries interaction, the one accent carries the brand', () {
    test('the interactive fill takes white text with room to spare', () {
      expectRatio(AppColors.neutral0, AppColors.ink600, 15.76);
    });

    test('white on the terracotta brand falls below AA — the reason the SPIN '
        'label is dark', () {
      expect(ratio(AppColors.neutral0, AppColors.brand), lessThan(4.5));
    });

    test('the SPIN button pairs the brand accent with dark text', () {
      expectRatio(AppColors.onPrimaryBrand, AppColors.brand, 5.16);
    });
  });

  group('§2.3 every pastel reaches AA with its paired foreground', () {
    test('peach', () {
      expectRatio(AppColors.onAccentPeach, AppColors.accentPeach, 6.70);
    });

    test('butter', () {
      expectRatio(AppColors.onAccentButter, AppColors.accentButter, 6.45);
    });

    test('stone', () {
      expectRatio(AppColors.onAccentStone, AppColors.accentStone, 6.16);
    });

    test('lavender', () {
      expectRatio(AppColors.onAccentLavender, AppColors.accentLavender, 8.44);
    });

    test('coral', () {
      expectRatio(AppColors.onAccentCoral, AppColors.accentCoral, 6.33);
    });

    test('sky', () {
      expectRatio(AppColors.onAccentSky, AppColors.accentSky, 7.19);
    });
  });

  group('§2.4 semantic colours all exceed AA with white text', () {
    test('success', () {
      expectPassesAA(AppColors.onSuccess, AppColors.success, 'success');
    });

    test('warning', () {
      expectPassesAA(AppColors.onWarning, AppColors.warning, 'warning');
    });

    test('error', () {
      expectPassesAA(AppColors.onError, AppColors.error, 'error');
    });

    test('info', () {
      expectPassesAA(AppColors.onInfo, AppColors.info, 'info');
    });

    test('each tinted surface reaches AA with its on-surface colour', () {
      expectPassesAA(
        AppColors.onSuccessSurface,
        AppColors.successSurface,
        'success surface',
      );
      expectPassesAA(
        AppColors.onWarningSurface,
        AppColors.warningSurface,
        'warning surface',
      );
      expectPassesAA(
        AppColors.onErrorSurface,
        AppColors.errorSurface,
        'error surface',
      );
      expectPassesAA(
        AppColors.onInfoSurface,
        AppColors.infoSurface,
        'info surface',
      );
    });
  });

  group('§2.5 light text roles', () {
    test('textPrimary on background', () {
      expectRatio(AppColors.neutral900, AppColors.neutral50, 16.26);
    });

    test('textSecondary on background', () {
      expectRatio(AppColors.neutral700, AppColors.neutral50, 6.48);
    });

    test('textTertiary on background is the system floor', () {
      expectRatio(AppColors.neutral600, AppColors.neutral50, 5.01);
    });

    test('every text role also clears AA on a white card', () {
      expectPassesAA(
        AppColors.neutral900,
        AppColors.neutral0,
        'textPrimary on surface',
      );
      expectPassesAA(
        AppColors.neutral700,
        AppColors.neutral0,
        'textSecondary on surface',
      );
      expectPassesAA(
        AppColors.neutral600,
        AppColors.neutral0,
        'textTertiary on surface',
      );
    });

    test('metadata on surfaceMuted still clears AA', () {
      // MetadataPill fills with surfaceMuted (docs/COMPONENTS.md §5), so the
      // tightest pairing in the system has to hold on that surface too.
      expectPassesAA(
        AppColors.neutral600,
        AppColors.neutral100,
        'textTertiary on surfaceMuted',
      );
      expectPassesAA(
        AppColors.neutral700,
        AppColors.neutral100,
        'textSecondary on surfaceMuted',
      );
    });

    test('textDisabled is the one documented exception', () {
      // WCAG exempts disabled controls, so this pair intentionally fails. It is
      // asserted rather than ignored: if it ever *rises*, someone has started
      // using it for content that matters.
      expectRatio(AppColors.neutral400, AppColors.neutral50, 2.23);
    });
  });

  group('§2.6 dark text roles', () {
    test('textPrimary on background', () {
      expectRatio(AppColors.darkTextPrimary, AppColors.darkBackground, 16.43);
    });

    test('textSecondary on background', () {
      expectRatio(AppColors.darkTextSecondary, AppColors.darkBackground, 8.44);
    });

    test('textTertiary on background', () {
      expectRatio(AppColors.darkTextTertiary, AppColors.darkBackground, 5.29);
    });

    test('every text role also clears AA on a dark card', () {
      expectPassesAA(
        AppColors.darkTextPrimary,
        AppColors.darkSurface,
        'dark textPrimary on surface',
      );
      expectPassesAA(
        AppColors.darkTextSecondary,
        AppColors.darkSurface,
        'dark textSecondary on surface',
      );
      expectPassesAA(
        AppColors.darkTextTertiary,
        AppColors.darkSurface,
        'dark textTertiary on surface',
      );
    });

    test('the dark brand fill pairs with dark text', () {
      expectRatio(AppColors.onPrimaryDark, AppColors.brandDark, 7.98);
    });

    test('the brand accent is readable as dark-mode text', () {
      expectRatio(AppColors.brandDark, AppColors.darkBackground, 7.66);
    });
  });

  group('dark accents reach AA once composited', () {
    // The pastels are composited at 14% over the dark surface, so the ratio that
    // matters is against the *blend* — checking against the pastel itself would
    // pass while the real screen failed.
    final AppColorScheme dark = AppColorScheme.dark();

    for (final (String name, AppAccent accent) in <(String, AppAccent)>[
      ('peach', dark.peach),
      ('butter', dark.butter),
      ('stone', dark.stone),
      ('lavender', dark.lavender),
      ('coral', dark.coral),
      ('sky', dark.sky),
    ]) {
      test(name, () {
        expectPassesAA(
          accent.foreground,
          accent.background,
          'dark $name accent',
        );
      });
    }

    test('dark semantic surfaces reach AA', () {
      for (final (String name, AppSemanticColor semantic)
          in <(String, AppSemanticColor)>[
            ('success', dark.success),
            ('warning', dark.warning),
            ('error', dark.error),
            ('info', dark.info),
          ]) {
        expectPassesAA(
          semantic.onSurface,
          semantic.surface,
          'dark $name surface',
        );
        expectPassesAA(semantic.onColor, semantic.color, 'dark $name fill');
      }
    });
  });

  group('§11 focus and component contrast', () {
    test('the focus ring reaches the 3:1 UI-component bar', () {
      final AppColorScheme light = AppColorScheme.light();
      final AppColorScheme dark = AppColorScheme.dark();

      expect(
        ratio(light.primary, light.background),
        greaterThanOrEqualTo(3.0),
        reason: 'the light focus ring must be visible against the background',
      );
      expect(
        ratio(dark.primary, dark.background),
        greaterThanOrEqualTo(3.0),
        reason: 'the dark focus ring must be visible against the background',
      );
    });
  });
}
