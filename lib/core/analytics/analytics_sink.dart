import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/analytics/analytics_event.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// An event, stamped with when it happened.
///
/// The stamp is taken at the call site rather than at the write, because events
/// are buffered: a batch flushed five seconds later, or after twenty minutes
/// offline, would otherwise land with five seconds or twenty minutes of the
/// timing erased. Time to Decision is a duration between two of these.
@immutable
class RecordedEvent {
  RecordedEvent(this.event) : occurredAt = DateTime.now().toUtc();

  final AnalyticsEvent event;

  /// UTC, always. A household that flies somewhere is not an analytics problem
  /// until two rows disagree about which came first.
  final DateTime occurredAt;
}

/// Somewhere events go.
///
/// Deliberately narrow: one method, no return value, no future. **Analytics must
/// not be able to fail a user action.** The whole surface being `void` is what
/// makes that structural rather than a rule to remember — there is no result to
/// await, so no call site can accidentally block dinner on a write to a metrics
/// table.
abstract interface class AnalyticsSink {
  void record(RecordedEvent recorded);

  /// Pushes anything buffered. Called when the app backgrounds, and safe to call
  /// when there is nothing to push.
  ///
  /// Returns a future only so the caller *may* wait — nothing in the app does,
  /// and nothing should on the user's path.
  Future<void> flush();
}

/// Every sink, one call.
///
/// Composed rather than chosen so the log is not lost the moment persistence is
/// switched on: while a metric is being built, "what did the app actually send"
/// is a question the console answers and a database does not, and the two answers
/// are only comparable if both are recorded from the same call.
class FanOutAnalyticsSink implements AnalyticsSink {
  const FanOutAnalyticsSink(this.sinks);

  final List<AnalyticsSink> sinks;

  @override
  void record(RecordedEvent recorded) {
    assert(_isSafe(recorded.event), 'Analytics event carries a redacted field.');

    for (final AnalyticsSink sink in sinks) {
      // Guarded per sink. One sink throwing must not cost the others their
      // event, and none of them may cost the caller anything at all.
      try {
        sink.record(recorded);
      } on Object catch (error, stackTrace) {
        AppLog.error(
          'Sink refused an event.',
          name: _logName,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  Future<void> flush() async {
    for (final AnalyticsSink sink in sinks) {
      try {
        await sink.flush();
      } on Object catch (error, stackTrace) {
        AppLog.error(
          'Sink refused a flush.',
          name: _logName,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Whether [event] is free of anything §10 forbids.
  ///
  /// The event constructors already make a name or an email hard to pass — every
  /// parameter is an id, a count, a duration or a flag. This is the second line:
  /// a debug-only check that nobody has since added a property whose *key* is one
  /// [AppLog] would redact from a log line, or whose value looks like an address.
  /// An assert rather than a filter, because a leak here should be a failing
  /// build rather than a field that quietly stops arriving.
  static bool _isSafe(AnalyticsEvent event) {
    for (final MapEntry<String, Object?> property in event.properties.entries) {
      final String key = property.key.toLowerCase();
      for (final String forbidden in AppLog.redactionKeys) {
        if (key.contains(forbidden)) {
          return false;
        }
      }
      if (property.value is String && (property.value! as String).contains('@')) {
        return false;
      }
    }
    return true;
  }

  static const String _logName = 'analytics';
}

/// The console.
///
/// Every build has this one, and until a warehouse is chosen it is the only
/// destination — but it is not a placeholder. `Time to Decision` is a number
/// somebody has to be able to read while building the thing that moves it, and
/// waiting for a dashboard to exist before emitting the event is how risk 14
/// ("cannot be measured retroactively") actually happens.
class LoggingAnalyticsSink implements AnalyticsSink {
  const LoggingAnalyticsSink();

  @override
  void record(RecordedEvent recorded) {
    // `info`, not `debug`: these are the events §10 calls the product's
    // instrumentation, and a verbose-only flag would hide them in exactly the
    // build where they are being checked. `AppLog` is a no-op in release.
    AppLog.info(
      recorded.event.name,
      name: _logName,
      data: recorded.event.properties,
    );
  }

  @override
  Future<void> flush() async {}

  static const String _logName = 'analytics';
}
