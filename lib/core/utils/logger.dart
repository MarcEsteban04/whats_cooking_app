import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/config/app_env.dart';

/// Log severity.
enum LogLevel {
  debug(500, 'DEBUG'),
  info(800, 'INFO'),
  warning(900, 'WARN'),
  error(1000, 'ERROR');

  const LogLevel(this.value, this.label);

  /// `dart:developer` level, so DevTools filters by severity correctly.
  final int value;
  final String label;
}

/// The application's logger.
///
/// docs/CODING_STANDARDS.md §10: "No `print`. Use the logger in `core/utils/`,
/// and strip sensitive fields from logs." `avoid_print` is an analyzer *error*
/// in this project, so this is the only way anything gets logged.
///
/// Built on `dart:developer` rather than `print`: it carries a level, a name and
/// a stack trace as structured fields that DevTools can filter, and it is a
/// no-op in release builds on every platform.
///
/// **Redaction is not optional.** A log line is the easiest way for a token or
/// an email address to end up in a crash report, so [redactionKeys] are stripped
/// from every map that passes through here rather than at each call site.
abstract final class AppLog {
  /// Field names whose values are never logged.
  ///
  /// Matched case-insensitively as a substring, so `access_token`,
  /// `refreshToken` and `Authorization` are all covered by three entries.
  static const Set<String> redactionKeys = <String>{
    'password',
    'token',
    'secret',
    'key',
    'authorization',
    'email',
    'apikey',
  };

  static const String _redacted = '<redacted>';

  /// Detail useful while developing. Suppressed unless
  /// [AppEnv.isVerboseLogging].
  static void debug(String message, {String? name, Object? data}) {
    if (!AppEnv.isVerboseLogging) {
      return;
    }
    _log(LogLevel.debug, message, name: name, data: data);
  }

  /// A notable, expected event: a sign-in, a spin, a cache miss.
  static void info(String message, {String? name, Object? data}) =>
      _log(LogLevel.info, message, name: name, data: data);

  /// Something recoverable that a developer should know about.
  static void warning(String message, {String? name, Object? data}) =>
      _log(LogLevel.warning, message, name: name, data: data);

  /// A failure. [error] and [stackTrace] are recorded, never displayed
  /// (docs/design_ui.md §31).
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
    Object? data,
  }) {
    _log(
      LogLevel.error,
      message,
      name: name,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log(
    LogLevel level,
    String message, {
    String? name,
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Release builds log nothing at all: docs/project_dev.md's production
    // checklist requires sensitive logs removed and debug mode disabled, and the
    // cheapest way to honour both is to not emit in the first place. Crash
    // reporting is a separate channel, wired in Sprint 69.
    if (kReleaseMode) {
      return;
    }

    final String payload = data == null ? '' : ' ${redact(data)}';
    final String source = name ?? 'whats_cooking';
    final String line = '${level.label} $message$payload';

    developer.log(
      line,
      name: source,
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );

    // Mirrored to the console in debug builds, because `developer.log` goes to
    // the VM service's logging stream and **nothing prints it**: not
    // `flutter run`, not `flutter logs`, not `adb logcat`. Only DevTools.
    //
    // That was a real cost. The app diagnoses its own backend at startup and
    // names the fix, and the diagnosis was invisible to anyone running the app
    // from a terminal — which is how it is always run. A log nobody can read is
    // not a log.
    //
    // `debugPrint` rather than `print`: it rate-limits, so a burst cannot get
    // truncated by the Android log buffer. Release still emits nothing at all —
    // the early return above covers both sinks.
    if (kDebugMode) {
      debugPrint('[$source] $line');
      if (error != null) {
        debugPrint('[$source] cause: $error');
      }
    }
  }

  /// [data] with the values of any [redactionKeys] replaced.
  ///
  /// Recurses through maps and lists, because the shape that actually appears in
  /// practice is a nested Supabase response rather than a flat map.
  static Object? redact(Object? data) {
    if (data is Map) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in data.entries)
          '${entry.key}': _isSensitive('${entry.key}')
              ? _redacted
              : redact(entry.value),
      };
    }
    if (data is Iterable) {
      return data.map(redact).toList();
    }
    return data;
  }

  static bool _isSensitive(String key) {
    final String lowered = key.toLowerCase();
    return redactionKeys.any(lowered.contains);
  }
}
