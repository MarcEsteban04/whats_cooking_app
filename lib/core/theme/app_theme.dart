import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/app_colors.dart';
import 'package:whats_cooking/core/theme/app_icons.dart';
import 'package:whats_cooking/core/theme/app_radius.dart';
import 'package:whats_cooking/core/theme/app_shadows.dart';
import 'package:whats_cooking/core/theme/app_spacing.dart';
import 'package:whats_cooking/core/theme/app_typography.dart';

/// A pastel accent and the foreground that reaches AA on it
/// (docs/DESIGN_SYSTEM.md §2.3).
///
/// The two travel together because they are only ever correct together: a pastel
/// with the wrong foreground is the easiest accessibility failure in this palette
/// to introduce by hand.
@immutable
class AppAccent {
  const AppAccent({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  static AppAccent lerp(AppAccent a, AppAccent b, double t) {
    return AppAccent(
      background: Color.lerp(a.background, b.background, t)!,
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
    );
  }
}

/// A semantic role and its three companions (docs/DESIGN_SYSTEM.md §2.4).
///
/// [color] is the strong fill with [onColor] on top; [surface] is the tinted
/// container with [onSurface] on top. Error and warning are always paired with an
/// icon and words — colour alone never carries meaning (§11).
@immutable
class AppSemanticColor {
  const AppSemanticColor({
    required this.color,
    required this.onColor,
    required this.surface,
    required this.onSurface,
  });

  final Color color;
  final Color onColor;
  final Color surface;
  final Color onSurface;

  static AppSemanticColor lerp(
    AppSemanticColor a,
    AppSemanticColor b,
    double t,
  ) {
    return AppSemanticColor(
      color: Color.lerp(a.color, b.color, t)!,
      onColor: Color.lerp(a.onColor, b.onColor, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      onSurface: Color.lerp(a.onSurface, b.onSurface, t)!,
    );
  }
}

/// The semantic colour roles from docs/DESIGN_SYSTEM.md §2.5 and §2.6.
///
/// This is the only colour surface feature code may touch. It exists so a screen
/// asks for the *role* it needs — `context.colors.textTertiary` — rather than
/// naming a palette entry, which is what lets the palette change without a
/// find-and-replace across the app.
///
/// Roles are stored as resolved colours rather than computed from a brightness
/// flag so that [lerp] can interpolate properly: a light/dark switch cross-fades
/// with the rest of the theme instead of snapping halfway through.
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceHigh,
    required this.surfaceInverse,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.textOnInverse,
    required this.primary,
    required this.primaryPressed,
    required this.primaryBrand,
    required this.onPrimaryBrand,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.series1,
    required this.series2,
    required this.seriesTrack,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.peach,
    required this.butter,
    required this.mint,
    required this.lavender,
    required this.coral,
    required this.sky,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  /// The light roles (docs/DESIGN_SYSTEM.md §2.5).
  factory AppColorScheme.light() {
    return const AppColorScheme(
      background: AppColors.neutral50,
      surface: AppColors.neutral0,
      surfaceMuted: AppColors.neutral100,
      surfaceHigh: AppColors.neutral0,
      surfaceInverse: AppColors.neutral900,
      outline: AppColors.neutral200,
      outlineStrong: AppColors.neutral300,
      textPrimary: AppColors.neutral900,
      textSecondary: AppColors.neutral700,
      textTertiary: AppColors.neutral600,
      textDisabled: AppColors.neutral400,
      textOnPrimary: AppColors.neutral0,
      textOnInverse: AppColors.neutral50,
      primary: AppColors.primary600,
      primaryPressed: AppColors.primary700,
      primaryBrand: AppColors.primary500,
      onPrimaryBrand: AppColors.onPrimaryBrand,
      primaryContainer: AppColors.primary50,
      onPrimaryContainer: AppColors.primary800,
      series1: AppColors.series1,
      series2: AppColors.series2,
      seriesTrack: AppColors.seriesTrack,
      skeletonBase: AppColors.neutral100,
      skeletonHighlight: AppColors.neutral200,
      peach: AppAccent(
        background: AppColors.accentPeach,
        foreground: AppColors.onAccentPeach,
      ),
      butter: AppAccent(
        background: AppColors.accentButter,
        foreground: AppColors.onAccentButter,
      ),
      mint: AppAccent(
        background: AppColors.accentMint,
        foreground: AppColors.onAccentMint,
      ),
      lavender: AppAccent(
        background: AppColors.accentLavender,
        foreground: AppColors.onAccentLavender,
      ),
      coral: AppAccent(
        background: AppColors.accentCoral,
        foreground: AppColors.onAccentCoral,
      ),
      sky: AppAccent(
        background: AppColors.accentSky,
        foreground: AppColors.onAccentSky,
      ),
      success: AppSemanticColor(
        color: AppColors.success,
        onColor: AppColors.onSuccess,
        surface: AppColors.successSurface,
        onSurface: AppColors.onSuccessSurface,
      ),
      warning: AppSemanticColor(
        color: AppColors.warning,
        onColor: AppColors.onWarning,
        surface: AppColors.warningSurface,
        onSurface: AppColors.onWarningSurface,
      ),
      error: AppSemanticColor(
        color: AppColors.error,
        onColor: AppColors.onError,
        surface: AppColors.errorSurface,
        onSurface: AppColors.onErrorSurface,
      ),
      info: AppSemanticColor(
        color: AppColors.info,
        onColor: AppColors.onInfo,
        surface: AppColors.infoSurface,
        onSurface: AppColors.onInfoSurface,
      ),
    );
  }

  /// The dark roles (docs/DESIGN_SYSTEM.md §2.6).
  ///
  /// Pastels composite at [AppColors.darkAccentOpacity] over the dark surface
  /// and take a light foreground — at full saturation they would read as a
  /// completely different, much louder palette.
  factory AppColorScheme.dark() {
    return AppColorScheme(
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      surfaceMuted: AppColors.darkSurfaceMuted,
      surfaceHigh: AppColors.darkSurfaceHigh,
      surfaceInverse: AppColors.neutral50,
      outline: AppColors.darkOutline,
      outlineStrong: AppColors.darkOutlineStrong,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textTertiary: AppColors.darkTextTertiary,
      textDisabled: AppColors.darkTextDisabled,
      textOnPrimary: AppColors.onPrimaryDark,
      textOnInverse: AppColors.neutral900,
      primary: AppColors.primary500,
      primaryPressed: AppColors.primary600,
      primaryBrand: AppColors.primary400,
      onPrimaryBrand: AppColors.onPrimaryDark,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.primary200,
      series1: AppColors.series1Dark,
      series2: AppColors.series2Dark,
      seriesTrack: AppColors.seriesTrackDark,
      skeletonBase: AppColors.darkSurfaceMuted,
      skeletonHighlight: AppColors.darkSurfaceHigh,
      peach: _darkAccent(AppColors.accentPeach, AppColors.onAccentPeachDark),
      butter: _darkAccent(AppColors.accentButter, AppColors.onAccentButterDark),
      mint: _darkAccent(AppColors.accentMint, AppColors.onAccentMintDark),
      lavender: _darkAccent(
        AppColors.accentLavender,
        AppColors.onAccentLavenderDark,
      ),
      coral: _darkAccent(AppColors.accentCoral, AppColors.onAccentCoralDark),
      sky: _darkAccent(AppColors.accentSky, AppColors.onAccentSkyDark),
      success: const AppSemanticColor(
        color: AppColors.darkSuccess,
        onColor: AppColors.onPrimaryDark,
        surface: AppColors.darkPrimaryContainer,
        onSurface: AppColors.primary200,
      ),
      warning: AppSemanticColor(
        color: AppColors.darkWarning,
        onColor: AppColors.neutral900,
        surface: _compositeOnDarkSurface(AppColors.darkWarning),
        onSurface: AppColors.darkWarning,
      ),
      error: AppSemanticColor(
        color: AppColors.darkError,
        onColor: AppColors.onDarkError,
        surface: _compositeOnDarkSurface(AppColors.darkError),
        onSurface: AppColors.onDarkErrorSurface,
      ),
      info: AppSemanticColor(
        color: AppColors.darkInfo,
        onColor: AppColors.neutral900,
        surface: _compositeOnDarkSurface(AppColors.darkInfo),
        onSurface: AppColors.darkInfo,
      ),
    );
  }

  // Surfaces.
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceHigh;
  final Color surfaceInverse;
  final Color outline;
  final Color outlineStrong;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnPrimary;
  final Color textOnInverse;

  // Brand.
  final Color primary;
  final Color primaryPressed;
  final Color primaryBrand;
  final Color onPrimaryBrand;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // Loading (docs/COMPONENTS.md §11).
  /// The strong accent a dashboard figure is drawn in.
  ///
  /// A series colour, not a brand colour: it names one line on a chart or one
  /// segment of a bar, and it must never be mistaken for the primary action.
  final Color series1;

  /// The second series — near-black, so two segments read apart without a
  /// second hue competing with [series1].
  final Color series2;

  /// The unfilled remainder of a bar or an arc.
  final Color seriesTrack;

  final Color skeletonBase;
  final Color skeletonHighlight;

  // Pastel accents.
  final AppAccent peach;
  final AppAccent butter;
  final AppAccent mint;
  final AppAccent lavender;
  final AppAccent coral;
  final AppAccent sky;

  // Semantic.
  final AppSemanticColor success;
  final AppSemanticColor warning;
  final AppSemanticColor error;
  final AppSemanticColor info;

  /// Every pastel, in the order they should be handed out to categories.
  List<AppAccent> get accents => <AppAccent>[
    peach,
    butter,
    mint,
    lavender,
    coral,
    sky,
  ];

  /// A deterministic accent for [seed].
  ///
  /// Deterministic so a meal without a photo shows the *same* pastel block on
  /// every launch (docs/DESIGN_SYSTEM.md §9) — a fallback that reshuffles looks
  /// broken rather than composed.
  AppAccent accentFor(String seed) {
    if (seed.isEmpty) {
      return accents.first;
    }
    final int hash = seed.codeUnits.fold<int>(
      0,
      (int acc, int unit) => (acc * 31 + unit) & 0x7FFFFFFF,
    );
    return accents[hash % accents.length];
  }

  static AppAccent _darkAccent(Color pastel, Color foreground) {
    return AppAccent(
      background: _compositeOnDarkSurface(pastel),
      foreground: foreground,
    );
  }

  /// [tint] composited over the dark surface at [AppColors.darkAccentOpacity].
  ///
  /// Flattened at build time rather than left as a translucent colour so a
  /// contrast ratio can be computed against it, and so nesting one tinted
  /// surface inside another does not double the tint.
  static Color _compositeOnDarkSurface(Color tint) {
    return Color.alphaBlend(
      tint.withValues(alpha: AppColors.darkAccentOpacity),
      AppColors.darkSurface,
    );
  }

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceHigh,
    Color? surfaceInverse,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textOnPrimary,
    Color? textOnInverse,
    Color? primary,
    Color? primaryPressed,
    Color? primaryBrand,
    Color? onPrimaryBrand,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? series1,
    Color? series2,
    Color? seriesTrack,
    Color? skeletonBase,
    Color? skeletonHighlight,
    AppAccent? peach,
    AppAccent? butter,
    AppAccent? mint,
    AppAccent? lavender,
    AppAccent? coral,
    AppAccent? sky,
    AppSemanticColor? success,
    AppSemanticColor? warning,
    AppSemanticColor? error,
    AppSemanticColor? info,
  }) {
    return AppColorScheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      textOnInverse: textOnInverse ?? this.textOnInverse,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryBrand: primaryBrand ?? this.primaryBrand,
      onPrimaryBrand: onPrimaryBrand ?? this.onPrimaryBrand,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      seriesTrack: seriesTrack ?? this.seriesTrack,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      peach: peach ?? this.peach,
      butter: butter ?? this.butter,
      mint: mint ?? this.mint,
      lavender: lavender ?? this.lavender,
      coral: coral ?? this.coral,
      sky: sky ?? this.sky,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  AppColorScheme lerp(covariant AppColorScheme? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColorScheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      textOnInverse: Color.lerp(textOnInverse, other.textOnInverse, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primaryBrand: Color.lerp(primaryBrand, other.primaryBrand, t)!,
      onPrimaryBrand: Color.lerp(onPrimaryBrand, other.onPrimaryBrand, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      series1: Color.lerp(series1, other.series1, t)!,
      series2: Color.lerp(series2, other.series2, t)!,
      seriesTrack: Color.lerp(seriesTrack, other.seriesTrack, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      peach: AppAccent.lerp(peach, other.peach, t),
      butter: AppAccent.lerp(butter, other.butter, t),
      mint: AppAccent.lerp(mint, other.mint, t),
      lavender: AppAccent.lerp(lavender, other.lavender, t),
      coral: AppAccent.lerp(coral, other.coral, t),
      sky: AppAccent.lerp(sky, other.sky, t),
      success: AppSemanticColor.lerp(success, other.success, t),
      warning: AppSemanticColor.lerp(warning, other.warning, t),
      error: AppSemanticColor.lerp(error, other.error, t),
      info: AppSemanticColor.lerp(info, other.info, t),
    );
  }
}

/// Builds the application's two themes from the design system tokens.
///
/// Nothing here is a judgement call — every value traces to
/// docs/DESIGN_SYSTEM.md or docs/COMPONENTS.md.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final AppColorScheme colors = isDark
        ? AppColorScheme.dark()
        : AppColorScheme.light();
    final AppShadows shadows = isDark ? AppShadows.dark() : AppShadows.light();
    final AppTextStyles text = isDark
        ? AppTextStyles.dark()
        : AppTextStyles.light();
    final ColorScheme colorScheme = _colorScheme(brightness, colors, shadows);
    final TextTheme textTheme = AppTypography.textTheme(
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.outline,
      extensions: <ThemeExtension<dynamic>>[colors, shadows, text],

      // Press feedback in this system is a scale, not an ink ripple
      // (docs/DESIGN_SYSTEM.md §7). A ripple spreading across a 28 px-radius
      // card is the single most Material-looking thing the app could do.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(
          color: colors.textPrimary,
          size: AppIconSize.md,
        ),
      ),

      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: AppIconSize.md,
      ),

      // docs/COMPONENTS.md §3. Elevation is drawn by the card widget from the
      // shadow tokens, so Material's own elevation stays at zero rather than
      // painting a second, differently shaped shadow underneath.
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      ),

      // docs/COMPONENTS.md §1 — `primary`.
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(colors, text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(colors, text),
      ),

      // docs/COMPONENTS.md §1 — `secondary`.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _baseButtonStyle(text).copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
          foregroundColor: _foreground(colors.textPrimary, colors),
          side: WidgetStateProperty.resolveWith<BorderSide>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: colors.outline);
            }
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: colors.outlineStrong);
            }
            return BorderSide(color: colors.outline);
          }),
        ),
      ),

      // docs/COMPONENTS.md §1 — `tertiary`.
      textButtonTheme: TextButtonThemeData(
        style: _baseButtonStyle(text)
            .copyWith(foregroundColor: _foreground(colors.primary, colors)),
      ),

      // docs/COMPONENTS.md §2.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        isDense: false,
        constraints: const BoxConstraints(minHeight: _inputHeight),
        contentPadding: const EdgeInsets.all(AppSpacing.space4),
        hintStyle: text.bodyMedium.copyWith(color: colors.textDisabled),
        labelStyle: text.labelSmall.copyWith(color: colors.textSecondary),
        floatingLabelStyle: text.labelSmall.copyWith(color: colors.primary),
        helperStyle: text.bodySmall.copyWith(color: colors.textTertiary),
        errorStyle: text.bodySmall.copyWith(color: colors.error.color),
        // The error message replaces the helper in place; reserving both at two
        // lines is what stops the field shifting the layout when it appears.
        helperMaxLines: 2,
        errorMaxLines: 2,
        border: _inputBorder(colors.outline),
        enabledBorder: _inputBorder(colors.outline),
        disabledBorder: _inputBorder(colors.outline),
        focusedBorder: _inputBorder(colors.primary, width: 2),
        errorBorder: _inputBorder(colors.error.color, width: 2),
        focusedErrorBorder: _inputBorder(colors.error.color, width: 2),
      ),

      // docs/COMPONENTS.md §5 — FilterChip.
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.primary,
        disabledColor: colors.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        labelStyle: text.labelSmall.copyWith(color: colors.textSecondary),
        secondaryLabelStyle: text.labelSmall.copyWith(
          color: colors.textOnPrimary,
        ),
        side: BorderSide(color: colors.outline),
        shape: const StadiumBorder(),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      // docs/COMPONENTS.md §9.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: shadows.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: colors.outlineStrong,
        dragHandleSize: const Size(_dragHandleWidth, _dragHandleHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.top(AppRadius.xxl),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // docs/COMPONENTS.md §10.
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.space5),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium.copyWith(color: colors.textSecondary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXxl),
      ),

      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: colors.surface,
        iconColor: colors.textSecondary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.metadata,
        minVerticalPadding: AppSpacing.space3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceInverse,
        contentTextStyle: text.bodyMedium.copyWith(color: colors.textOnInverse),
        actionTextColor: colors.primaryBrand,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryBrand,
        linearTrackColor: colors.outline,
        circularTrackColor: colors.outline,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primaryContainer,
        selectionHandleColor: colors.primary,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceInverse,
          borderRadius: AppRadius.borderSm,
        ),
        textStyle: text.bodySmall.copyWith(color: colors.textOnInverse),
      ),
    );
  }

  static ColorScheme _colorScheme(
    Brightness brightness,
    AppColorScheme colors,
    AppShadows shadows,
  ) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.textOnPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,

      // Material's `secondary` carries the brand green: the identity colour that
      // never sits behind small white text (docs/DESIGN_SYSTEM.md §2.2).
      secondary: colors.primaryBrand,
      onSecondary: colors.onPrimaryBrand,
      secondaryContainer: colors.primaryContainer,
      onSecondaryContainer: colors.onPrimaryContainer,

      tertiary: colors.info.color,
      onTertiary: colors.info.onColor,
      tertiaryContainer: colors.info.surface,
      onTertiaryContainer: colors.info.onSurface,

      error: colors.error.color,
      onError: colors.error.onColor,
      errorContainer: colors.error.surface,
      onErrorContainer: colors.error.onSurface,

      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.background,
      surfaceContainer: colors.surfaceMuted,
      surfaceContainerHigh: colors.surfaceMuted,
      surfaceContainerHighest: colors.surfaceHigh,
      onSurfaceVariant: colors.textSecondary,

      outline: colors.outline,
      outlineVariant: colors.outlineStrong,
      inverseSurface: colors.surfaceInverse,
      onInverseSurface: colors.textOnInverse,
      inversePrimary: colors.primaryBrand,
      scrim: shadows.scrim,
      shadow: AppColors.neutral900,

      // Material 3 tints elevated surfaces with the primary colour by default.
      // This system expresses elevation with shadows on light and lighter
      // surfaces on dark, so the tint is switched off rather than fought
      // surface by surface.
      surfaceTint: Colors.transparent,
    );
  }

  static ButtonStyle _baseButtonStyle(AppTextStyles text) {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle>(text.label),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(_buttonMinWidth, _buttonHeightLarge),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: AppSpacing.space7),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      elevation: const WidgetStatePropertyAll<double>(0),
      // Feedback is the press scale from §7, applied by AppButton in Sprint 08.
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  static ButtonStyle _primaryButtonStyle(
    AppColorScheme colors,
    AppTextStyles text,
  ) {
    return _baseButtonStyle(text).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return colors.outline;
        }
        if (states.contains(WidgetState.pressed)) {
          return colors.primaryPressed;
        }
        return colors.primary;
      }),
      foregroundColor: _foreground(colors.textOnPrimary, colors),
      iconColor: _foreground(colors.textOnPrimary, colors),
    );
  }

  static WidgetStateProperty<Color> _foreground(
    Color enabled,
    AppColorScheme colors,
  ) {
    return WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
      return states.contains(WidgetState.disabled)
          ? colors.textDisabled
          : enabled;
    });
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.borderMd,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static const double _inputHeight = 56;
  static const double _buttonHeightLarge = 56;
  static const double _buttonMinWidth = 64;
  static const double _dragHandleWidth = 40;
  static const double _dragHandleHeight = 4;
}

/// Token access for feature code.
///
/// `context.colors`, `context.shadows` and `context.text` are the only routes
/// into the design system from a feature — a feature file that imports
/// `app_colors.dart` is a review failure (docs/DESIGN_SYSTEM.md §12).
extension AppThemeContext on BuildContext {
  /// Semantic colour roles.
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>()!;

  /// Elevation tokens, already resolved for the current brightness.
  AppShadows get shadows => Theme.of(this).extension<AppShadows>()!;

  /// Type tokens under their design-system names.
  AppTextStyles get text => Theme.of(this).extension<AppTextStyles>()!;

  /// Whether the dark theme is active.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
