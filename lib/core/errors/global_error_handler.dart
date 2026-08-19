import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// Catches everything that escapes a screen (docs/ARCHITECTURE.md §9).
///
/// "Global handlers catch anything that escapes so an unhandled exception cannot
/// reach a raw Flutter error screen." There are three separate escape routes in
/// Flutter and each needs its own hook — installing one and assuming the others
/// are covered is the usual mistake:
///
/// * [FlutterError.onError] — synchronous errors inside the framework, thrown
///   during build, layout or paint.
/// * `PlatformDispatcher.instance.onError` — asynchronous errors with no zone to
///   catch them, which is most unawaited futures.
/// * `ErrorWidget.builder` — what is *painted* where a widget failed to build.
///
/// Nothing here shows a message to the user: by the time an error is this far
/// out, the screen that could have explained it has already failed. Its job is
/// to make sure the failure is recorded and that a release build shows something
/// blank rather than a red-and-yellow diagnostic.
abstract final class GlobalErrorHandler {
  /// Installs every handler. Call before `runApp`.
  static void install() {
    final FlutterExceptionHandler? previous = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      _report(
        details.exception,
        details.stack ?? StackTrace.current,
        context: details.context?.toString(),
        library: details.library,
      );

      // Chained rather than replaced, so the default handler still prints the
      // full diagnostic in debug — losing that would make development worse in
      // exchange for nothing.
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _report(error, stack, context: 'PlatformDispatcher');
      // True means handled: without it the error is re-thrown and the process
      // may be killed by the platform.
      return true;
    };

    ErrorWidget.builder = _buildErrorWidget;
  }

  /// Runs [body] inside a guarded zone.
  ///
  /// The fourth escape route, and the only one that catches errors thrown in a
  /// callback that was scheduled before the handlers above were installed.
  static Future<void> runGuarded(FutureOr<void> Function() body) async {
    await runZonedGuarded<Future<void>>(
      () async {
        await body();
      },
      (Object error, StackTrace stack) =>
          _report(error, stack, context: 'zone'),
    );
  }

  static void _report(
    Object error,
    StackTrace stackTrace, {
    String? context,
    String? library,
  }) {
    // Mapped on the way out so the log line names the failure in the same
    // vocabulary the rest of the app uses, which makes a log searchable
    // alongside the handled failures.
    final Object mapped = ErrorMapper.map(error, stackTrace);

    AppLog.error(
      'Unhandled error',
      error: mapped,
      stackTrace: stackTrace,
      name: 'GlobalErrorHandler',
      data: <String, Object?>{'context': ?context, 'library': ?library},
    );
  }

  /// What is painted in place of a widget that failed to build.
  ///
  /// Debug keeps Flutter's diagnostic, because during development the red screen
  /// with the stack trace is the single most useful thing on the device. Release
  /// paints nothing: a user should never see a framework error, and a blank
  /// region beats an exception message they cannot act on.
  static Widget _buildErrorWidget(FlutterErrorDetails details) {
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }
    return _defaultErrorWidgetBuilder(details);
  }

  static final ErrorWidgetBuilder _defaultErrorWidgetBuilder =
      ErrorWidget.builder;
}
