import 'dart:math' as math;

import 'package:whats_cooking/core/errors/app_exception.dart';

/// When and how often to retry a failed request (docs/ARCHITECTURE.md §2.4).
///
/// Only failures that report themselves [AppException.isRetryable] are retried,
/// which is why that property lives on the exception rather than being decided
/// here: whether a failure is transient is a fact about the failure, not about
/// the caller.
///
/// Backoff is exponential with **full jitter**. Without jitter, a set of clients
/// that all failed on the same dropped connection retry in lockstep and arrive
/// as a synchronised spike — the retry becomes the second outage.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 4),
    this.multiplier = 2,
  }) : assert(maxAttempts >= 1, 'an operation must be attempted at least once');

  /// The policy for ordinary reads.
  static const RetryPolicy standard = RetryPolicy();

  /// One attempt, no retry.
  ///
  /// For writes that are not idempotent: retrying "create household" after a
  /// timeout risks creating two.
  static const RetryPolicy none = RetryPolicy(maxAttempts: 1);

  /// A single retry, used for the silent refresh-and-retry on an expired session
  /// (docs/ARCHITECTURE.md §7).
  static const RetryPolicy single = RetryPolicy(
    maxAttempts: 2,
    initialDelay: Duration.zero,
  );

  /// Total attempts, including the first.
  final int maxAttempts;

  final Duration initialDelay;

  /// Ceiling on a single wait. A spin has a 2-second P95 latency budget
  /// (docs/ARCHITECTURE.md §12), so backoff cannot grow without bound.
  final Duration maxDelay;

  final double multiplier;

  /// Whether an [attempt] that failed with [error] should be retried.
  ///
  /// [attempt] is 1-based.
  bool shouldRetry(int attempt, AppException error) =>
      attempt < maxAttempts && error.isRetryable;

  /// How long to wait before attempt number [attempt] + 1.
  ///
  /// [random] is injectable so the jitter is deterministic under test — the
  /// alternative is a test that either sleeps for real or asserts a range and
  /// tells you very little.
  Duration delayFor(int attempt, {math.Random? random}) {
    if (initialDelay == Duration.zero) {
      return Duration.zero;
    }

    final double exponential =
        initialDelay.inMilliseconds *
        math.pow(multiplier, attempt - 1).toDouble();
    final int capped = math.min(exponential.round(), maxDelay.inMilliseconds);

    // Full jitter: a uniform draw from [0, capped] rather than the capped value
    // itself. Equal-jitter would keep half the spike.
    final double factor = (random ?? _random).nextDouble();

    return Duration(milliseconds: (capped * factor).round());
  }

  static final math.Random _random = math.Random();
}
