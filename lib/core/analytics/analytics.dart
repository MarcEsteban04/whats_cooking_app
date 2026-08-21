import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/analytics/analytics_event.dart';
import 'package:whats_cooking/core/analytics/analytics_sink.dart';
import 'package:whats_cooking/core/analytics/session_clock.dart';
import 'package:whats_cooking/core/analytics/supabase_analytics_sink.dart';
import 'package:whats_cooking/core/config/app_env.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';

export 'package:whats_cooking/core/analytics/analytics_event.dart';
export 'package:whats_cooking/core/analytics/session_clock.dart';

part 'analytics.g.dart';

/// The one way anything in the app records an event.
///
/// A facade over the sinks and the session clock, for one reason worth the extra
/// type: **Time to Decision must not be assembled at the call site.** If the
/// screen that accepts a meal has to reach for a clock, subtract two times and
/// pass the result, then the north-star metric is one arithmetic slip away from
/// being wrong in a way no test would catch and no reader would notice. Here the
/// caller says `accepted(mealId, spinCount)` and the duration is not its business.
class Analytics {
  Analytics(this._sink, this._clock);

  final AnalyticsSink _sink;
  final SessionClock _clock;

  /// Records anything in the vocabulary.
  ///
  /// Use the named methods below where one exists — they are the events whose
  /// properties this class knows better than the caller does.
  void record(AnalyticsEvent event) => _sink.record(RecordedEvent(event));

  /// A cold start. Called once, from `main`.
  void appLaunched() {
    _clock.restart();
    record(const AppOpened(isCold: true));
  }

  /// The app left the foreground. Flushes, because there may not be another
  /// chance: the OS is free to kill a backgrounded app without warning.
  void appBackgrounded() {
    _clock.pause();
    unawaited(_sink.flush());
  }

  /// The app came back. Emits an open only if enough time passed to count as a
  /// new session — see [SessionClock].
  void appResumed() {
    if (_clock.resume()) {
      record(const AppOpened(isCold: false));
    }
  }

  /// The reader accepted a meal. **The north-star event.**
  ///
  /// The duration comes from the clock rather than the caller, which is the whole
  /// reason this method exists.
  void mealAccepted({
    required String mealId,
    required int spinCount,
    SpinSurface surface = SpinSurface.cooking,
  }) {
    record(
      MealAccepted(
        mealId: mealId,
        sinceAppOpen: _clock.sinceOpen,
        spinCount: spinCount,
        surface: surface,
      ),
    );
  }

  /// Pushes anything buffered.
  Future<void> flush() => _sink.flush();
}

/// The session clock, one per launch.
@Riverpod(keepAlive: true)
SessionClock sessionClock(Ref ref) => SessionClock();

/// Where events go.
///
/// **Kept alive, and it has to be.** The buffer inside the Supabase sink is the
/// pending batch; a provider that could be disposed between screens would throw
/// events away at exactly the transitions worth measuring.
///
/// The console sink is always present. Persistence is added only when there is a
/// backend to persist to, so a clone with no credentials still emits every event
/// to the log rather than failing — the same rule the rest of the app follows
/// (supabase/README.md).
@Riverpod(keepAlive: true)
Analytics analytics(Ref ref) {
  final List<AnalyticsSink> sinks = <AnalyticsSink>[
    const LoggingAnalyticsSink(),
    if (AppEnv.isBackendConfigured && SupabaseBootstrap.isInitialized)
      SupabaseAnalyticsSink(ref.read(supabaseClientProvider)),
  ];

  return Analytics(FanOutAnalyticsSink(sinks), ref.read(sessionClockProvider));
}
