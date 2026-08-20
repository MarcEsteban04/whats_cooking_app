import 'package:flutter/painting.dart';

/// The raw palette from docs/DESIGN_SYSTEM.md §2.
///
/// **Private to the theme layer.** Feature code reads semantic roles through
/// `context.colors` — a feature file importing this one is a review failure
/// (docs/DESIGN_SYSTEM.md §12), enforced by
/// `test/core/theme/palette_isolation_test.dart`.
///
/// Every contrast ratio quoted below is computed, not estimated, and asserted in
/// `test/core/theme/contrast_test.dart`.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // §2.1 Neutral scale — warm grey
  //
  // The slight yellow-green cast is what separates this from a generic Material
  // app. These are not Material's greys and must not be swapped for them.
  // ---------------------------------------------------------------------------

  /// Card and sheet surfaces.
  static const Color neutral0 = Color(0xFFFFFFFF);

  /// The app background.
  static const Color neutral50 = Color(0xFFF7F7F5);

  /// Muted surface, skeleton base, unselected chip.
  static const Color neutral100 = Color(0xFFF1F1EE);

  /// Dividers, borders, skeleton highlight.
  static const Color neutral200 = Color(0xFFE5E5E0);

  /// Disabled surfaces, inactive tracks.
  static const Color neutral300 = Color(0xFFD4D4CE);

  /// Disabled text, placeholder icons.
  static const Color neutral400 = Color(0xFFA8A8A1);

  /// Decorative only — never body text on light.
  static const Color neutral500 = Color(0xFF8A8A80);

  /// Tertiary text, metadata.
  static const Color neutral600 = Color(0xFF6B6B63);

  /// Secondary text.
  static const Color neutral700 = Color(0xFF5A5A52);

  /// Strong text on muted surfaces.
  static const Color neutral800 = Color(0xFF2A2A26);

  /// Primary text, and the source of every shadow colour.
  static const Color neutral900 = Color(0xFF1A1A17);

  // ---------------------------------------------------------------------------
  // §2.2 Ink and one accent
  //
  // **There is no brand green.** The palette is warm near-black on warm white,
  // and interaction is expressed by *weight* rather than by hue: a filled
  // near-black pill is the primary action, an outline is the secondary, and
  // nothing needs a colour to say which. That is the same decision the auth
  // screens already made, and the dashboards reference this app is built to
  // carries its structure in exactly this way.
  //
  // One accent survives, and it is the one the reference itself uses for the
  // figure it wants read first: a warm terracotta. It is spent on the SPIN
  // button and on data series, and nowhere else. An app about food that is
  // *entirely* monochrome reads as a spreadsheet — one warm colour, used
  // sparingly, is what stops it.
  //
  // The ramp keeps its numbering because the scheme is built from it, but the
  // roles are now weight rather than saturation: 600 is the interactive fill in
  // light mode, and the dark theme reaches for the light end of the same ramp
  // instead of a lighter tint of a hue.
  // ---------------------------------------------------------------------------

  /// Selected chip background, tinted container.
  static const Color ink50 = Color(0xFFF2F2EF);

  /// Tinted container, one step stronger.
  static const Color ink100 = Color(0xFFE4E4DF);

  /// Decorative, dark-theme dividers.
  static const Color ink200 = Color(0xFFC7C7C0);

  /// Dark-theme accents.
  static const Color ink300 = Color(0xFF9C9C94);

  /// Mid grey. Disabled fills, inactive tracks.
  static const Color ink400 = Color(0xFF6E6E66);

  /// Ink at reading weight.
  static const Color ink500 = Color(0xFF3A3A34);

  /// Interactive fill: buttons, active nav, selected states.
  /// White text on this is 15.76:1.
  static const Color ink600 = Color(0xFF232320);

  /// Pressed state — a shade deeper, so the press is felt rather than seen.
  static const Color ink700 = Color(0xFF141412);

  /// Text on a tinted container.
  static const Color ink800 = Color(0xFF1A1A17);

  /// The strongest ink there is. Still warm, never pure black — pure black on a
  /// warm white reads as a hole in the page.
  static const Color ink900 = Color(0xFF0D0D0B);

  // --- The one accent ---------------------------------------------------------

  /// The SPIN button, and the leading data series.
  ///
  /// Terracotta rather than green, and the same value the dashboards reference
  /// uses for the figure it wants read first — see [series1], which is this.
  static const Color brand = Color(0xFFE8622A);

  /// Lifted for a dark surface, where the light-mode terracotta goes muddy.
  static const Color brandDark = Color(0xFFFF8551);

  /// Text on a [brand] fill (5.16:1).
  ///
  /// Dark text, not white: white on terracotta reaches only 3.38:1, which is
  /// fine for a heading and not fine for a button label. The same trade the
  /// brand green made before it, at the same place in the scale.
  static const Color onPrimaryBrand = ink800;

  /// Text on a [brandDark] fill in dark mode (7.98:1).
  static const Color onPrimaryDark = Color(0xFF1A0B04);

  // ---------------------------------------------------------------------------
  // §2.3 Pastel accents — backgrounds only
  //
  // Each pairs with a fixed foreground that reaches AA. Never a pastel on a
  // pastel, and never a pastel as a button fill.
  // ---------------------------------------------------------------------------

  /// Comfort food, breakfast.
  static const Color accentPeach = Color(0xFFFFE8D6);
  static const Color onAccentPeach = Color(0xFF7A4322);

  /// Snacks, desserts.
  static const Color accentButter = Color(0xFFFFF3CC);
  static const Color onAccentButter = Color(0xFF6E5410);

  /// Healthy, vegetarian.
  ///
  /// Warm stone, not the mint it used to be: the pastels are the only place a
  /// hue survives, and a green one would put the colour this app just removed
  /// back on a third of the meal cards.
  static const Color accentStone = Color(0xFFEBE7DE);
  static const Color onAccentStone = Color(0xFF5A5346);

  /// Surprise me, AI.
  static const Color accentLavender = Color(0xFFE8E4F5);
  static const Color onAccentLavender = Color(0xFF413672);

  /// Spicy, meat.
  static const Color accentCoral = Color(0xFFFFDDD6);
  static const Color onAccentCoral = Color(0xFF8A3524);

  /// Seafood, light meals.
  static const Color accentSky = Color(0xFFDDEBF7);
  static const Color onAccentSky = Color(0xFF1F4E75);

  // ---------------------------------------------------------------------------
  // Dark-mode accent foregrounds
  //
  // §2.3 pastels drop to [darkAccentOpacity] over the dark surface, which leaves
  // the light foregrounds far too dark to read. §2.6 calls for "the
  // corresponding *200 tint" without fixing values, so these are derived: each
  // is a light tint of its own hue, verified against the composited background
  // in contrast_test.dart rather than against the pastel itself.
  // ---------------------------------------------------------------------------

  /// Opacity a pastel is composited at over a dark surface.
  static const double darkAccentOpacity = 0.14;

  static const Color onAccentPeachDark = Color(0xFFF5C9A3);
  static const Color onAccentButterDark = Color(0xFFF0DA9B);
  static const Color onAccentStoneDark = Color(0xFFD8D2C4);
  static const Color onAccentLavenderDark = Color(0xFFC9C0EC);
  static const Color onAccentCoralDark = Color(0xFFF2B3A3);
  static const Color onAccentSkyDark = Color(0xFFA8C8E8);

  // ---------------------------------------------------------------------------
  // §2.4 Semantic — light
  //
  // All four exceed 4.5:1 with white text. Error and warning are always paired
  // with an icon and words; colour alone never carries meaning (§11).
  // ---------------------------------------------------------------------------

  // Data-series colours (docs/reference_design/dashboards_ref.webp).
  //
  // A separate role from the brand. The reference dashboards carry their
  // figures in one saturated accent, one near-black and one grey track, and
  // nothing in the food palette does that job: the pastels are backgrounds
  // and primary green is the SPIN button. Adding three series colours keeps
  // the charts legible without repainting the brand.
  static const Color series1 = brand;
  static const Color series1Dark = brandDark;
  static const Color series2 = neutral900;
  static const Color series2Dark = Color(0xFFE8E8E3);
  static const Color seriesTrack = neutral200;
  static const Color seriesTrackDark = Color(0xFF3A3A34);

  // Success is ink, not a colour.
  //
  // Green was the obvious choice and it is gone. §2.4 already forbids colour
  // from carrying meaning alone — every success state pairs with a check icon
  // and words — so the icon does the work it was always supposed to do, and a
  // confirmation looks like the rest of the app instead of like a traffic light.
  static const Color success = ink600;
  static const Color onSuccess = neutral0;
  static const Color successSurface = ink50;
  static const Color onSuccessSurface = ink800;

  static const Color warning = Color(0xFFA66214);
  static const Color onWarning = neutral0;
  static const Color warningSurface = Color(0xFFFFF3CC);
  static const Color onWarningSurface = Color(0xFF6E5410);

  static const Color error = Color(0xFFC4362C);
  static const Color onError = neutral0;
  static const Color errorSurface = Color(0xFFFDECEA);
  static const Color onErrorSurface = Color(0xFF8A2119);

  static const Color info = Color(0xFF2F6FB0);
  static const Color onInfo = neutral0;
  static const Color infoSurface = Color(0xFFE8F1FA);
  static const Color onInfoSurface = Color(0xFF1F4E75);

  // ---------------------------------------------------------------------------
  // §2.6 Dark theme
  //
  // Warm-shifted to match the light palette's cast. Elevation is expressed as
  // lighter surfaces, not shadows — shadows are invisible on dark.
  // ---------------------------------------------------------------------------

  /// Warm near-black, never pure black.
  static const Color darkBackground = Color(0xFF141412);

  /// Cards.
  static const Color darkSurface = Color(0xFF1E1E1B);

  /// Elevated and muted surfaces.
  static const Color darkSurfaceMuted = Color(0xFF262622);

  /// Sheets and dialogs.
  static const Color darkSurfaceHigh = Color(0xFF2E2E29);

  static const Color darkOutline = Color(0xFF35352F);
  static const Color darkOutlineStrong = Color(0xFF45453E);

  static const Color darkTextPrimary = Color(0xFFF2F2EE);
  static const Color darkTextSecondary = Color(0xFFB0B0A6);
  static const Color darkTextTertiary = Color(0xFF8A8A80);
  static const Color darkTextDisabled = Color(0xFF5A5A52);

  static const Color darkPrimaryContainer = Color(0xFF2E2E29);

  static const Color darkError = Color(0xFFE5695E);
  static const Color darkSuccess = darkTextPrimary;
  static const Color darkWarning = Color(0xFFD99A3E);
  static const Color darkInfo = Color(0xFF6FA8D8);

  /// Text on the lightened dark-mode error fill.
  static const Color onDarkError = Color(0xFF3D0F0B);

  /// Text on the dark-mode error *surface* — the 14%-tinted container.
  ///
  /// The other three dark semantic colours are legible on their own tinted
  /// container, but [darkError] is the darkest of the four and reaches only
  /// 4.30:1 on its own tint. This is that colour lifted far enough to clear AA;
  /// `contrast_test.dart` holds the line.
  static const Color onDarkErrorSurface = Color(0xFFF0938A);

  // ---------------------------------------------------------------------------
  // Scrims (§6, §9)
  // ---------------------------------------------------------------------------

  /// Scrim behind sheets and dialogs — 32% light, 56% dark.
  static const double scrimOpacityLight = 0.32;
  static const double scrimOpacityDark = 0.56;

  /// Gradient scrim over imagery that carries text (§9).
  static const double imageScrimOpacity = 0.55;
}
