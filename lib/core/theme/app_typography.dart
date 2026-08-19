import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whats_cooking/core/theme/app_colors.dart';

/// The type scale from docs/DESIGN_SYSTEM.md §3.
///
/// Inter via `google_fonts`, which is metrically close enough to SF Pro that one
/// scale serves both platforms. Only four weights are used — 400, 500, 600, 700
/// — because §3 explicitly warns against weight sprawl.
///
/// Headlines carry negative tracking and small text zero or positive: that is
/// what makes large type read as *designed* rather than merely large.
///
/// The scale is defined once here and consumed twice — as a Material
/// [TextTheme] so framework widgets inherit it, and as an
/// [AppTextStyles] extension so feature code can use the token names from the
/// design system. Both come from the same source, so they cannot drift.
abstract final class AppTypography {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Text scaling is clamped to this range (§3). Every layout must survive the
  /// upper bound without truncating a price, a time or a button label.
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;

  /// [lineHeight] is the design system's line box in pixels; Flutter's `height`
  /// is a multiple of the font size, so the conversion happens here rather than
  /// in sixteen hand-computed ratios.
  static TextStyle _style({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double tracking = 0,
    Color? color,
    List<FontFeature>? features,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: tracking,
      color: color,
      fontFeatures: features,
    );
  }

  /// Result screen meal name, celebration.
  static TextStyle displayLarge({Color? color}) => _style(
    size: 40,
    lineHeight: 44,
    weight: bold,
    tracking: -0.5,
    color: color,
  );

  /// Roulette reveal.
  static TextStyle displayMedium({Color? color}) => _style(
    size: 34,
    lineHeight: 40,
    weight: bold,
    tracking: -0.4,
    color: color,
  );

  /// The greeting: "Good evening, Marc".
  static TextStyle headlineLarge({Color? color}) => _style(
    size: 28,
    lineHeight: 34,
    weight: bold,
    tracking: -0.3,
    color: color,
  );

  /// Screen titles.
  static TextStyle headlineMedium({Color? color}) => _style(
    size: 24,
    lineHeight: 30,
    weight: semiBold,
    tracking: -0.2,
    color: color,
  );

  /// "What are we eating tonight?"
  static TextStyle headlineSmall({Color? color}) => _style(
    size: 20,
    lineHeight: 26,
    weight: semiBold,
    tracking: -0.2,
    color: color,
  );

  /// Card titles, section headers.
  static TextStyle titleLarge({Color? color}) => _style(
    size: 18,
    lineHeight: 24,
    weight: semiBold,
    tracking: -0.1,
    color: color,
  );

  /// Meal card name, list row title.
  static TextStyle titleMedium({Color? color}) =>
      _style(size: 16, lineHeight: 22, weight: semiBold, color: color);

  /// Dense titles.
  static TextStyle titleSmall({Color? color}) =>
      _style(size: 15, lineHeight: 20, weight: semiBold, color: color);

  /// Primary reading text, recipe instructions.
  static TextStyle bodyLarge({Color? color}) =>
      _style(size: 16, lineHeight: 24, weight: regular, color: color);

  /// Default body.
  static TextStyle bodyMedium({Color? color}) =>
      _style(size: 15, lineHeight: 22, weight: regular, color: color);

  /// Supporting text. The floor for body text — nothing drops below 13 px.
  static TextStyle bodySmall({Color? color}) =>
      _style(size: 13, lineHeight: 18, weight: regular, color: color);

  /// Button text.
  static TextStyle label({Color? color}) =>
      _style(size: 15, lineHeight: 20, weight: semiBold, color: color);

  /// Chips, pills, tabs.
  static TextStyle labelSmall({Color? color}) => _style(
    size: 13,
    lineHeight: 16,
    weight: semiBold,
    tracking: 0.1,
    color: color,
  );

  /// "30 min · ₱220 · 2 servings" — sits on `textTertiary`, the tightest text
  /// pairing in the system at 5.01:1. Nothing may go below it.
  static TextStyle metadata({Color? color}) =>
      _style(size: 13, lineHeight: 18, weight: medium, color: color);

  /// UPPERCASE micro-labels. Used sparingly.
  static TextStyle overline({Color? color}) => _style(
    size: 11,
    lineHeight: 14,
    weight: semiBold,
    tracking: 0.8,
    color: color,
  );

  /// Costs and quantities.
  ///
  /// Tabular figures are not a nicety here: without them, digits of differing
  /// widths make a price jitter as it changes during the roulette animation.
  static TextStyle numeric({Color? color}) => _style(
    size: 15,
    lineHeight: 20,
    weight: semiBold,
    color: color,
    features: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The Material [TextTheme], so framework widgets inherit the scale.
  ///
  /// Material has fifteen slots and the design system has sixteen tokens, so
  /// three slots carry tokens under Material's names: `labelLarge` is `label`,
  /// `labelMedium` is `labelSmall`, and `labelSmall` is `overline`. Feature code
  /// should read `context.text` instead and avoid the translation entirely.
  /// `displaySmall` has no token — it is filled from `headlineLarge` so a
  /// framework widget reaching for it still gets Inter at a sane size.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: displayLarge(color: primary),
      displayMedium: displayMedium(color: primary),
      displaySmall: headlineLarge(color: primary),
      headlineLarge: headlineLarge(color: primary),
      headlineMedium: headlineMedium(color: primary),
      headlineSmall: headlineSmall(color: primary),
      titleLarge: titleLarge(color: primary),
      titleMedium: titleMedium(color: primary),
      titleSmall: titleSmall(color: primary),
      bodyLarge: bodyLarge(color: primary),
      bodyMedium: bodyMedium(color: primary),
      bodySmall: bodySmall(color: secondary),
      labelLarge: label(color: primary),
      labelMedium: labelSmall(color: primary),
      labelSmall: overline(color: secondary),
    );
  }
}

/// The design system's type tokens, by their documented names.
///
/// Read through `context.text` so a screen never has to know that the design
/// system's `label` is Material's `labelLarge`.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.displayLarge,
    required this.displayMedium,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.label,
    required this.labelSmall,
    required this.metadata,
    required this.overline,
    required this.numeric,
  });

  /// Builds the set for a brightness, with colours already applied.
  ///
  /// Baking the colour in is what lets a screen write `context.text.metadata`
  /// and get the correct `textTertiary` without also having to remember which
  /// role that token pairs with.
  factory AppTextStyles.of({
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    return AppTextStyles(
      displayLarge: AppTypography.displayLarge(color: textPrimary),
      displayMedium: AppTypography.displayMedium(color: textPrimary),
      headlineLarge: AppTypography.headlineLarge(color: textPrimary),
      headlineMedium: AppTypography.headlineMedium(color: textPrimary),
      headlineSmall: AppTypography.headlineSmall(color: textPrimary),
      titleLarge: AppTypography.titleLarge(color: textPrimary),
      titleMedium: AppTypography.titleMedium(color: textPrimary),
      titleSmall: AppTypography.titleSmall(color: textPrimary),
      bodyLarge: AppTypography.bodyLarge(color: textPrimary),
      bodyMedium: AppTypography.bodyMedium(color: textPrimary),
      bodySmall: AppTypography.bodySmall(color: textSecondary),
      label: AppTypography.label(color: textPrimary),
      labelSmall: AppTypography.labelSmall(color: textPrimary),
      metadata: AppTypography.metadata(color: textTertiary),
      overline: AppTypography.overline(color: textTertiary),
      numeric: AppTypography.numeric(color: textPrimary),
    );
  }

  /// The light set.
  factory AppTextStyles.light() => AppTextStyles.of(
    textPrimary: AppColors.neutral900,
    textSecondary: AppColors.neutral700,
    textTertiary: AppColors.neutral600,
  );

  /// The dark set.
  factory AppTextStyles.dark() => AppTextStyles.of(
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
  );

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle labelSmall;
  final TextStyle metadata;
  final TextStyle overline;
  final TextStyle numeric;

  @override
  AppTextStyles copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? labelSmall,
    TextStyle? metadata,
    TextStyle? overline,
    TextStyle? numeric,
  }) {
    return AppTextStyles(
      displayLarge: displayLarge ?? this.displayLarge,
      displayMedium: displayMedium ?? this.displayMedium,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      titleSmall: titleSmall ?? this.titleSmall,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
      labelSmall: labelSmall ?? this.labelSmall,
      metadata: metadata ?? this.metadata,
      overline: overline ?? this.overline,
      numeric: numeric ?? this.numeric,
    );
  }

  @override
  AppTextStyles lerp(covariant AppTextStyles? other, double t) {
    if (other == null) {
      return this;
    }
    return AppTextStyles(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      headlineLarge: TextStyle.lerp(headlineLarge, other.headlineLarge, t)!,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      headlineSmall: TextStyle.lerp(headlineSmall, other.headlineSmall, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      metadata: TextStyle.lerp(metadata, other.metadata, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
      numeric: TextStyle.lerp(numeric, other.numeric, t)!,
    );
  }
}
