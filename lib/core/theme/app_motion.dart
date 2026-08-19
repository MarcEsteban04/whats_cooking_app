import 'package:flutter/widgets.dart';

/// Durations and curves from docs/DESIGN_SYSTEM.md §7.
///
/// Every consumer must route its duration through [resolve] so the
/// reduce-motion path is honoured. Haptics are deliberately *not* suppressed
/// when motion is reduced — they carry the satisfaction that animation cannot.
abstract final class AppMotion {
  /// Tab switches — no animation at all.
  static const Duration instant = Duration.zero;

  /// Press feedback, chip toggles, checkboxes.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions and fades.
  static const Duration normal = Duration(milliseconds: 250);

  /// Sheets, dialogs, page transitions.
  static const Duration slow = Duration(milliseconds: 400);

  /// Result reveal, confetti.
  static const Duration celebrate = Duration(milliseconds: 600);

  /// Roulette cycling.
  static const Duration spin = Duration(milliseconds: 2400);

  /// Hard cap on the spin: the 60-second time-to-decision budget has no room
  /// for more suspense than this.
  static const Duration spinMaximum = Duration(milliseconds: 3000);

  static const Curve curveFast = Curves.easeOut;
  static const Curve curveNormal = Curves.easeOutCubic;
  static const Curve curveSlow = Curves.easeOutCubic;
  static const Curve curveCelebrate = Curves.easeOutBack;

  /// Deceleration curve for the roulette's slow-down phase.
  static const Curve curveSpinDecelerate = Curves.easeOutQuart;

  /// Press feedback on every tappable surface (§7).
  static const double pressScale = 0.97;

  /// Press feedback on a button (docs/COMPONENTS.md §1).
  static const double pressScaleButton = 0.96;
  static const Duration pressIn = Duration(milliseconds: 100);
  static const Duration pressOut = Duration(milliseconds: 150);

  /// [duration], or [Duration.zero] when the platform asks for reduced motion.
  ///
  /// Reading the flag through [MediaQuery] rather than a settings provider means
  /// the OS toggle applies immediately, with no app state to keep in sync.
  static Duration resolve(BuildContext context, Duration duration) {
    return prefersReducedMotion(context) ? Duration.zero : duration;
  }

  /// Whether the platform has asked for reduced motion.
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }
}

/// The roulette's four phases (docs/DESIGN_SYSTEM.md §7).
///
/// The product's signature moment, so the timing is fixed here rather than left
/// to the widget: it has to feel identical every spin.
abstract final class AppRouletteMotion {
  /// Button press, scale to [AppMotion.pressScaleButton], light haptic.
  static const Duration windUp = Duration(milliseconds: 200);

  /// Fast cycling at roughly [cyclePerMeal] per meal, linear.
  static const Duration fastCycle = Duration(milliseconds: 1200);

  /// Cards visibly slow, on [AppMotion.curveSpinDecelerate].
  static const Duration decelerate = Duration(milliseconds: 800);

  /// Spring settle, medium-impact haptic, confetti.
  static const Duration reveal = Duration(milliseconds: 400);

  /// Time each meal is shown during [fastCycle].
  static const Duration cyclePerMeal = Duration(milliseconds: 80);

  /// The cross-fade that replaces cycling entirely when motion is reduced.
  static const Duration reducedMotionCrossFade = AppMotion.normal;

  /// Total spin time, which must not exceed [AppMotion.spinMaximum].
  static Duration get total => windUp + fastCycle + decelerate + reveal;
}
