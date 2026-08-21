import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/analytics/analytics_sink.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// Events, persisted.
///
/// **Buffered, because one insert per event is the wrong shape.** A spin emits
/// `spin_started` and `spin_completed` within a couple of seconds of each other,
/// at exactly the moment the reader is waiting for the reel — spending two round
/// trips of the device's radio there to write telemetry would be measuring the
/// spin by slowing it down. So events queue and go out together.
///
/// **Nothing here can fail a user action.** [record] is `void` and returns before
/// anything is sent; a flush that throws is logged and the batch is dropped.
/// There is no retry: a queue that keeps failed batches grows without bound on a
/// bad connection, and the events it is protecting are diagnostic. Time to
/// Decision is a distribution over thousands of dinners, and it does not change
/// shape because one of them was lost on a train.
///
/// **Signed-out events are dropped, deliberately.** Row Level Security keys these
/// rows to `auth.uid()`, so an insert without a session cannot succeed. Rather
/// than send it and log the rejection, this drops it — and it costs the north-star
/// metric nothing, because Time to Decision travels on `meal_accepted`, which by
/// definition has a session behind it. The console sink still has every event.
class SupabaseAnalyticsSink implements AnalyticsSink {
  SupabaseAnalyticsSink(this._client);

  final SupabaseClient _client;

  final List<RecordedEvent> _buffer = <RecordedEvent>[];

  Timer? _timer;

  /// True while a flush is in flight, so a timer and a full buffer cannot send
  /// the same rows twice.
  bool _isSending = false;

  @override
  void record(RecordedEvent recorded) {
    if (_client.auth.currentSession == null) {
      return;
    }

    if (_buffer.length >= _bufferLimit) {
      // The oldest goes, not the newest. A long offline stretch should leave the
      // most recent picture of what happened rather than the first few seconds of
      // it, and `meal_accepted` arriving after `spin_started` was dropped is
      // still the metric.
      _buffer.removeAt(0);
    }
    _buffer.add(recorded);

    if (_buffer.length >= _batchSize) {
      unawaited(flush());
      return;
    }

    // Started rather than reset, so a steady trickle of events still goes out on
    // schedule instead of the timer being pushed back by each new one and never
    // firing.
    _timer ??= Timer(_flushAfter, () => unawaited(flush()));
  }

  @override
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;

    if (_isSending || _buffer.isEmpty) {
      return;
    }

    // Taken out of the buffer before the await, so events recorded during the
    // insert queue for the next batch instead of being sent twice or lost.
    final List<RecordedEvent> batch = List<RecordedEvent>.of(_buffer);
    _buffer.clear();
    _isSending = true;

    try {
      await _client.from(_table).insert(<Map<String, Object?>>[
        for (final RecordedEvent recorded in batch)
          <String, Object?>{
            // `user_id` is left out: the column defaults to `auth.uid()`, and the
            // insert policy checks the same thing. Sending it would be a second
            // copy of a fact the database already has, and the only way the two
            // could differ is a bug.
            'name': recorded.event.name,
            'properties': recorded.event.properties,
            'occurred_at': recorded.occurredAt.toIso8601String(),
          },
      ]);
    } on Object catch (error) {
      // Dropped, not requeued — see the class comment. Logged at warning rather
      // than error because losing telemetry is not a fault the user can see, and
      // an error here would cry wolf on every flaky connection.
      //
      // The reason, and no stack trace. A dropped batch is an expected condition
      // — offline, or a migration not applied yet — and it recurs every flush for
      // as long as the cause lasts; fifteen frames of `dart:async` internals each
      // time buries the log that is being read to find something else.
      AppLog.warning(
        'Dropped ${batch.length} events.',
        name: _logName,
        data: <String, Object?>{'reason': error.toString()},
      );
    } finally {
      _isSending = false;
    }
  }

  /// How long a partial batch waits.
  ///
  /// Five seconds: long enough that a spin's two events leave together, short
  /// enough that closing the app right after deciding still gets the one event
  /// that matters out — and the background handler flushes anyway.
  static const Duration _flushAfter = Duration(seconds: 5);

  /// How many events send immediately.
  static const int _batchSize = 20;

  /// How many are held before the oldest are discarded.
  ///
  /// Two hundred. Roughly a hundred spins' worth, which is far more than a
  /// household produces between two connections, and small enough that the queue
  /// cannot become a memory problem on a phone that has been offline for a week.
  static const int _bufferLimit = 200;

  static const String _table = 'analytics_events';
  static const String _logName = 'analytics';
}
