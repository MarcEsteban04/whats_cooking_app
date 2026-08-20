import 'dart:async';

import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/domain_signal.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// The wrapper every repository method puts around a backend call.
///
/// It exists so that three rules hold everywhere rather than wherever someone
/// remembered them:
///
/// * **Mapping happens exactly once** (docs/ARCHITECTURE.md §9). No Supabase
///   type escapes the data layer, because every failure leaves here as an
///   [AppException].
/// * **Transient failures are retried** with backoff, per [RetryPolicy].
/// * **Deliberate signals pass through.** A [DomainSignal] is an answer rather
///   than a failure, so it is rethrown unmapped and unretried.
/// * **The technical detail is logged** and the user-facing message is not
///   polluted with it (docs/design_ui.md §31).
///
/// The alternative — a try/catch in each of the several dozen repository methods
/// this project will grow — is several dozen chances to forget one of the three.
abstract final class RemoteCall {
  /// Runs [operation], mapping and retrying per [policy].
  ///
  /// [label] names the call in logs. It should describe the operation and carry
  /// no user data: "fetchMealDetail", never the meal name.
  static Future<T> guard<T>(
    Future<T> Function() operation, {
    required String label,
    RetryPolicy policy = RetryPolicy.standard,
    Duration? timeout,
    Future<void> Function()? onSessionExpired,
  }) async {
    int attempt = 0;

    while (true) {
      attempt++;

      try {
        final Future<T> future = operation();
        return timeout == null ? await future : await future.timeout(timeout);
      } on DomainSignal {
        // Passed through untouched. A signal is an answer, not a failure: it
        // carries meaning the caller acts on, and mapping it to an
        // `AppException` would replace "this address already has an account"
        // with "Something went wrong" — which is what happened before this
        // clause existed. Rethrowing before the retry logic also stops a
        // retrying policy re-sending a request whose answer was never in doubt.
        rethrow;
      } on Object catch (error, stackTrace) {
        final AppException mapped = ErrorMapper.map(error, stackTrace);

        // An expired session gets one silent refresh before the user sees
        // anything (docs/ARCHITECTURE.md §7). The refresh is attempted once per
        // call, not once per attempt, so a genuinely dead session cannot spin.
        if (mapped is AuthFailureException &&
            mapped.isSessionExpired &&
            onSessionExpired != null &&
            attempt == 1) {
          AppLog.debug('$label: refreshing an expired session', name: _name);
          await onSessionExpired();
          continue;
        }

        if (!policy.shouldRetry(attempt, mapped)) {
          AppLog.error(
            '$label failed after $attempt '
            '${attempt == 1 ? 'attempt' : 'attempts'}',
            error: mapped.cause ?? mapped,
            stackTrace: mapped.stackTrace ?? stackTrace,
            name: _name,
            data: <String, Object?>{
              'label': label,
              'code': mapped.code,
              'detail': mapped.detail,
            },
          );
          throw mapped;
        }

        final Duration delay = policy.delayFor(attempt);
        AppLog.warning(
          '$label failed, retrying in ${delay.inMilliseconds}ms',
          name: _name,
          data: <String, Object?>{'attempt': attempt, 'code': mapped.code},
        );

        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }
  }

  /// Like [guard], but returns null instead of throwing [NotFoundException].
  ///
  /// For the reads where absence is a normal answer — "does this user have a
  /// household?" — so the caller writes `if (household == null)` rather than a
  /// try/catch around an expected outcome.
  static Future<T?> guardNullable<T>(
    Future<T> Function() operation, {
    required String label,
    RetryPolicy policy = RetryPolicy.standard,
    Duration? timeout,
  }) async {
    try {
      return await guard<T>(
        operation,
        label: label,
        policy: policy,
        timeout: timeout,
      );
    } on NotFoundException {
      return null;
    }
  }

  static const String _name = 'RemoteCall';
}
