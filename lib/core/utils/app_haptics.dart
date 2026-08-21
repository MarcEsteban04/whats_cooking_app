import 'dart:async';

import 'package:flutter/services.dart';

/// The app's haptic vocabulary.
///
/// **Named by moment, not by intensity.** Before this, four call sites in the
/// roulette each chose their own `HapticFeedback` constant, and the result was a
/// spin whose escalation was accidental: the reveal and the acceptance both
/// buzzed at medium, so the biggest moment in the product felt exactly like the
/// moment before it. Naming the moment instead of the strength is what makes that
/// visible — the list below reads as a shape, and a wrong one is obvious.
///
/// The shape is deliberate. It rises exactly once:
///
/// | Moment | Feel |
/// | --- | --- |
/// | [spinBegun] | light — something started |
/// | [reelTick] | selection clicks — the reel being felt as it slows |
/// | [reveal] | medium — here is the meal |
/// | [decided] | heavy — **the loudest thing the app does** |
///
/// **Never suppressed for reduced motion.** docs/DESIGN_SYSTEM.md §7: "Haptics
/// are retained — they carry the satisfaction when animation cannot." A reader who
/// has turned animation off has *more* need of these, not less, which is why there
/// is no `resolve`-style gate here to match `AppMotion`'s.
///
/// Every call is fire-and-forget. `HapticFeedback` returns a future that resolves
/// once the platform channel has answered, and nothing in a user interaction
/// should wait on a vibration motor.
abstract final class AppHaptics {
  /// The spin screen opened and the reel is about to turn.
  ///
  /// docs/DESIGN_SYSTEM.md §7's wind-up phase: "Button press, scale to 0.96,
  /// light haptic."
  static void spinBegun() => unawaited(HapticFeedback.lightImpact());

  /// One card passed, during the deceleration only.
  ///
  /// A click per card through the fast phase would be a fifteen-tap buzz; five
  /// through the slow-down is the reel being felt as it settles.
  static void reelTick() => unawaited(HapticFeedback.selectionClick());

  /// The reel landed and the result is coming.
  static void reveal() => unawaited(HapticFeedback.mediumImpact());

  /// Dinner is decided.
  ///
  /// The heaviest impact the platform offers, and the only place the app uses it.
  /// This is the moment the whole product exists to reach, and it should not feel
  /// like the screen before it.
  static void decided() => unawaited(HapticFeedback.heavyImpact());

  /// A spin found nothing.
  ///
  /// Deliberately *not* an error buzz. Nothing went wrong — the filters were
  /// simply too tight — and a punishing rattle for a state the app is about to
  /// offer a one-tap fix for would read as blame. Light, the same as beginning:
  /// an acknowledgement that the reel stopped, no more.
  static void nothingFound() => unawaited(HapticFeedback.lightImpact());
}
