/// How long the app has been open, for Time to Decision.
///
/// docs/ARCHITECTURE.md §10 makes `meal_accepted.seconds_since_app_open` the
/// north-star metric, which means something has to hold the "app open" end of
/// that measurement. This is it, and it is the only thing that does — a second
/// clock somewhere else would produce a second, disagreeing number.
///
/// **A [Stopwatch], not a wall clock.** Two timestamps subtracted across a
/// daylight-saving change, a manual clock correction or an NTP step give a
/// duration that never happened, occasionally a negative one. `Stopwatch` is
/// monotonic, so the worst it can be is right.
///
/// **A resume restarts it.** Somebody who opened the app on the bus, put the
/// phone away, and took it out again in the kitchen has started a new attempt at
/// dinner; counting the intervening hour against Time to Decision would make the
/// metric meaningless and unimprovable. But a short trip out — reading the text
/// that just arrived, checking the recipe against a photo — is one session
/// interrupted, so it takes [_newSessionAfter] away from the app to count as a
/// new open.
class SessionClock {
  /// Started immediately: the first thing the app does with this is record the
  /// cold open, and a clock that has to be started separately is a clock that
  /// will one day be read before it was.
  final Stopwatch _stopwatch = Stopwatch()..start();

  /// When the app last went to the background, or null while it is foreground.
  DateTime? _backgroundedAt;

  /// How long the app has been open.
  Duration get sinceOpen => _stopwatch.elapsed;

  /// Restarts the measurement. Called on a cold start and on a resume that
  /// counts as a new one.
  void restart() {
    _stopwatch
      ..reset()
      ..start();
  }

  /// Records that the app left the foreground.
  void pause() => _backgroundedAt = DateTime.now();

  /// Whether coming back counts as a new open, restarting the clock if so.
  ///
  /// Returns what the caller needs to know — whether to emit an `app_open` — and
  /// does the restart itself, because the two must not drift apart: an event
  /// without the reset would measure from a session that had ended, and a reset
  /// without the event would lose the open entirely.
  bool resume() {
    final DateTime? left = _backgroundedAt;
    _backgroundedAt = null;

    if (left == null) {
      return false;
    }

    // A wall clock here, unlike the elapsed measurement above, because this asks
    // "how long was the phone in a pocket" — which no Stopwatch can answer,
    // since the OS may have suspended the isolate for the whole of it. Skew is
    // tolerable for a five-minute threshold in a way it is not for a metric.
    if (DateTime.now().difference(left).abs() < _newSessionAfter) {
      return false;
    }

    restart();
    return true;
  }

  /// How long away from the app makes the return a new session.
  ///
  /// Five minutes. Long enough to cover the reasons somebody leaves mid-decision
  /// — a message, a call, checking the fridge — and short enough that reopening
  /// the app hours later is not charged the whole gap.
  static const Duration _newSessionAfter = Duration(minutes: 5);
}
