import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// A JSON payload on disk, with the time it was written and a life span
/// (Sprint 27).
///
/// The bottom of the read-through cache described in docs/ARCHITECTURE.md §5.
/// Deliberately small: one key, one payload, one timestamp. It is not a
/// database, there are no queries, and nothing here knows what a meal is.
///
/// **Every failure is a miss.** Unreadable JSON, a payload written by an older
/// build, a platform channel that is not there in a unit test — all of it
/// returns null, because a cache that can throw is worse than no cache. The one
/// thing a caller must handle is null, and it already has to.
///
/// `SharedPreferences` rather than the secure store: this holds a public meal
/// catalogue. Nothing here is a secret, and encrypting it would buy latency
/// instead of safety. Anything that *is* a secret stays in
/// `SecureSessionStorage`.
class TimestampedStore {
  const TimestampedStore(this.key, {required this.ttl});

  /// The preferences key. Versioned by convention — see the constants below —
  /// so a build that changes the payload shape reads a miss rather than
  /// misreading the old shape.
  final String key;

  /// How long a written value stays usable. A read past it is a miss.
  final Duration ttl;

  /// Stores [payload], stamped with [now].
  ///
  /// The clock is passed in rather than read here so the expiry has one source,
  /// and so nothing in this file has to be mocked to exercise it.
  Future<void> write(Object payload, {required DateTime now}) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(
        key,
        jsonEncode(<String, Object?>{
          _storedAtField: now.toUtc().toIso8601String(),
          _payloadField: payload,
        }),
      );
    } on Object catch (error) {
      // A failed write costs a cache hit later. It is not worth telling anyone
      // about, and it must not fail the read that triggered it.
      AppLog.debug(
        'Could not write the cache',
        name: _name,
        data: <String, Object?>{
          'key': key,
          'error': error.runtimeType.toString(),
        },
      );
    }
  }

  /// Reads the payload, or null if there is nothing usable.
  Future<TimestampedValue?> read({required DateTime now}) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? raw = preferences.getString(key);
      if (raw == null) {
        return null;
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final Object? stamp = decoded[_storedAtField];
      final DateTime? storedAt = stamp is String
          ? DateTime.tryParse(stamp)
          : null;
      if (storedAt == null) {
        return null;
      }

      if (now.toUtc().difference(storedAt) > ttl) {
        // Expired. Left on disk rather than deleted: the next write replaces it,
        // and a delete here would turn a read into a write for no benefit.
        return null;
      }

      return TimestampedValue(
        payload: decoded[_payloadField],
        storedAt: storedAt,
      );
    } on Object catch (error) {
      AppLog.debug(
        'Could not read the cache',
        name: _name,
        data: <String, Object?>{
          'key': key,
          'error': error.runtimeType.toString(),
        },
      );
      return null;
    }
  }

  /// Forgets whatever is stored.
  ///
  /// For signing out: the next person on this device must not see the last
  /// one's meals, even though the catalogue itself is public.
  Future<void> clear() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.remove(key);
    } on Object catch (_) {
      // Nothing useful to do. The TTL will see to it.
    }
  }

  /// Drops every cache on the device.
  ///
  /// For signing out. Written as a prefix sweep rather than a list of keys so
  /// that the auth feature can clear the caches without knowing what is cached —
  /// a feature that adds one gets this for free, and cannot forget to.
  ///
  /// Every key belonging to a cache must therefore start with [keyPrefix]. That
  /// is the whole contract, and it is why the constructor takes the key rather
  /// than building it.
  static Future<void> clearAll() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      // Collected before removing: mutating the set while iterating it is the
      // kind of thing that works until it does not.
      final List<String> keys = preferences
          .getKeys()
          .where((String key) => key.startsWith(keyPrefix))
          .toList();

      for (final String key in keys) {
        await preferences.remove(key);
      }
    } on Object catch (error) {
      AppLog.debug(
        'Could not clear the caches',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  /// The prefix every cache key must carry, so [clearAll] can find it.
  static const String keyPrefix = 'cache.';

  static const String _storedAtField = 'stored_at';
  static const String _payloadField = 'payload';
  static const String _name = 'TimestampedStore';
}

/// What came out of a [TimestampedStore], and when it went in.
class TimestampedValue {
  const TimestampedValue({required this.payload, required this.storedAt});

  /// Whatever `jsonDecode` produced. The caller knows the shape; this does not.
  final Object? payload;

  /// When it was written, in UTC. Surfaced to the user as "showing what we had",
  /// so it is part of the value rather than an implementation detail.
  final DateTime storedAt;
}
