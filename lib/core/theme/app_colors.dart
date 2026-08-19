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
  // §2.2 Brand green
  //
  // The scale separates identity from interactive: primary500 is the brand but
  // reaches only 3.05:1 with white text, so anything carrying text or an icon
  // uses primary600 instead.
  // ---------------------------------------------------------------------------

  /// Selected chip background, success surface.
  static const Color primary50 = Color(0xFFEDF7F1);

  /// Tinted container.
  static const Color primary100 = Color(0xFFD5EDE0);

  /// Decorative, dark-theme dividers.
  static const Color primary200 = Color(0xFFA8DCC0);

  /// Dark-theme accents.
  static const Color primary300 = Color(0xFF7BC9A0);

  /// Dark-theme primary text and icon colour.
  static const Color primary400 = Color(0xFF56B583);

  /// Brand identity: logo, decorative fills, progress arcs, icons.
  /// Never behind small white text.
  static const Color primary500 = Color(0xFF3FA66B);

  /// Interactive fill: buttons, active nav, selected states. White text = 5.04:1.
  static const Color primary600 = Color(0xFF2E7D50);

  /// Pressed state.
  static const Color primary700 = Color(0xFF276E46);

  /// Text on tinted green containers.
  static const Color primary800 = Color(0xFF1D5334);

  /// Highest-contrast green text.
  static const Color primary900 = Color(0xFF143A25);

  /// Text on a primary500 fill — the SPIN button (4.81:1, docs/COMPONENTS.md §1).
  static const Color onPrimaryBrand = Color(0xFF0F2E1D);

  /// Text on a primary500 fill in dark mode (6.14:1, §2.6).
  static const Color onPrimaryDark = Color(0xFF06150D);

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
  static const Color accentMint = Color(0xFFD9F2E4);
  static const Color onAccentMint = Color(0xFF1D5638);

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
  static const Color onAccentMintDark = primary200;
  static const Color onAccentLavenderDark = Color(0xFFC9C0EC);
  static const Color onAccentCoralDark = Color(0xFFF2B3A3);
  static const Color onAccentSkyDark = Color(0xFFA8C8E8);

  // ---------------------------------------------------------------------------
  // §2.4 Semantic — light
  //
  // All four exceed 4.5:1 with white text. Error and warning are always paired
  // with an icon and words; colour alone never carries meaning (§11).
  // ---------------------------------------------------------------------------

  static const Color success = primary600;
  static const Color onSuccess = neutral0;
  static const Color successSurface = Color(0xFFEDF7F1);
  static const Color onSuccessSurface = Color(0xFF1D5334);

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

  static const Color darkPrimaryContainer = Color(0xFF1B3A28);

  static const Color darkError = Color(0xFFE5695E);
  static const Color darkSuccess = primary400;
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
