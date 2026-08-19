import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';

/// A [math.Random] that always returns [value], so jitter is deterministic.
class _FixedRandom implements math.Random {
  const _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  group('shouldRetry', () {
    test('retries a transient failure until the attempt limit', () {
      const RetryPolicy policy = RetryPolicy();

      expect(policy.shouldRetry(1, const NetworkException()), isTrue);
      expect(policy.shouldRetry(2, const NetworkException()), isTrue);
      expect(
        policy.shouldRetry(3, const NetworkException()),
        isFalse,
        reason: 'the third attempt is the last of three',
      );
    });

    test('never retries a failure that reports itself non-transient', () {
      // Whether a failure is worth retrying is a fact about the failure, which
      // is why it lives on the exception rather than being decided here.
      const RetryPolicy policy = RetryPolicy();

      expect(policy.shouldRetry(1, const PermissionException()), isFalse);
      expect(policy.shouldRetry(1, const NotFoundException()), isFalse);
      expect(
        policy.shouldRetry(1, const ValidationException(message: 'nope')),
        isFalse,
      );
    });

    test('the none policy retries nothing', () {
      // For non-idempotent writes: retrying "create household" after a timeout
      // risks creating two.
      expect(
        RetryPolicy.none.shouldRetry(1, const NetworkException()),
        isFalse,
      );
    });

    test('the single policy allows exactly one retry', () {
      expect(
        RetryPolicy.single.shouldRetry(1, const NetworkException()),
        isTrue,
      );
      expect(
        RetryPolicy.single.shouldRetry(2, const NetworkException()),
        isFalse,
      );
    });
  });

  group('delayFor', () {
    test('grows exponentially', () {
      const RetryPolicy policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
      );
      const math.Random noJitter = _FixedRandom(1);

      expect(
        policy.delayFor(1, random: noJitter),
        const Duration(milliseconds: 100),
      );
      expect(
        policy.delayFor(2, random: noJitter),
        const Duration(milliseconds: 200),
      );
      expect(
        policy.delayFor(3, random: noJitter),
        const Duration(milliseconds: 400),
      );
    });

    test('is capped', () {
      // A spin has a 2 s P95 latency budget (docs/ARCHITECTURE.md §12), so
      // backoff cannot grow without bound.
      const RetryPolicy policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(milliseconds: 250),
      );

      expect(
        policy.delayFor(9, random: const _FixedRandom(1)),
        const Duration(milliseconds: 250),
      );
    });

    test('applies full jitter', () {
      // Without jitter, every client that failed on the same dropped connection
      // retries in lockstep and arrives as a synchronised spike — the retry
      // becomes the second outage.
      const RetryPolicy policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 400),
      );

      expect(
        policy.delayFor(1, random: const _FixedRandom(0)),
        Duration.zero,
        reason: 'full jitter draws from [0, capped], so zero is reachable',
      );
      expect(
        policy.delayFor(1, random: const _FixedRandom(0.5)),
        const Duration(milliseconds: 200),
      );
    });

    test('a zero initial delay stays zero', () {
      // The session-refresh policy retries immediately: the refresh itself is
      // the wait.
      expect(RetryPolicy.single.delayFor(1), Duration.zero);
    });
  });

  group('RemoteCall.guard', () {
    test('returns a successful result', () async {
      final int result = await RemoteCall.guard(
        () async => 42,
        label: 'test',
        policy: RetryPolicy.none,
      );

      expect(result, 42);
    });

    test('maps a raw failure into an AppException', () async {
      // The rule this enforces: no Supabase or platform type escapes the data
      // layer (docs/ARCHITECTURE.md §4).
      await expectLater(
        RemoteCall.guard<void>(
          () async => throw ArgumentError('raw'),
          label: 'test',
          policy: RetryPolicy.none,
        ),
        throwsA(isA<UnknownException>()),
      );
    });

    test('retries a transient failure and can succeed', () async {
      int attempts = 0;

      final String result = await RemoteCall.guard(
        () async {
          attempts++;
          if (attempts < 3) {
            throw const NetworkException();
          }
          return 'ok';
        },
        label: 'test',
        policy: const RetryPolicy(initialDelay: Duration.zero),
      );

      expect(result, 'ok');
      expect(attempts, 3);
    });

    test(
      'gives up after the attempt limit and throws the mapped error',
      () async {
        int attempts = 0;

        await expectLater(
          RemoteCall.guard<void>(
            () async {
              attempts++;
              throw const NetworkException();
            },
            label: 'test',
            policy: const RetryPolicy(
              maxAttempts: 2,
              initialDelay: Duration.zero,
            ),
          ),
          throwsA(isA<NetworkException>()),
        );

        expect(attempts, 2);
      },
    );

    test('does not retry a non-transient failure', () async {
      int attempts = 0;

      await expectLater(
        RemoteCall.guard<void>(() async {
          attempts++;
          throw const PermissionException();
        }, label: 'test'),
        throwsA(isA<PermissionException>()),
      );

      expect(attempts, 1, reason: 'an RLS denial will not un-deny itself');
    });

    test('refreshes once on an expired session, then retries', () async {
      // docs/ARCHITECTURE.md §7: "A 401 triggers one refresh-and-retry before
      // the user sees anything."
      int attempts = 0;
      int refreshes = 0;

      final String result = await RemoteCall.guard(
        () async {
          attempts++;
          if (attempts == 1) {
            throw const AuthFailureException(isSessionExpired: true);
          }
          return 'ok';
        },
        label: 'test',
        onSessionExpired: () async => refreshes++,
      );

      expect(result, 'ok');
      expect(refreshes, 1);
      expect(attempts, 2);
    });

    test('a dead session does not spin on refresh', () async {
      // The refresh is attempted once per call, not once per attempt, so a
      // session that cannot be refreshed fails instead of looping.
      int refreshes = 0;

      await expectLater(
        RemoteCall.guard<void>(
          () async => throw const AuthFailureException(isSessionExpired: true),
          label: 'test',
          policy: const RetryPolicy(
            maxAttempts: 2,
            initialDelay: Duration.zero,
          ),
          onSessionExpired: () async => refreshes++,
        ),
        throwsA(isA<AuthFailureException>()),
      );

      expect(refreshes, 1);
    });

    test('a timeout is mapped as a network failure', () async {
      await expectLater(
        RemoteCall.guard<void>(
          () => Future<void>.delayed(const Duration(seconds: 5)),
          label: 'test',
          policy: RetryPolicy.none,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('guardNullable turns not-found into null', () async {
      // For reads where absence is a normal answer, so the caller writes an
      // `if (x == null)` rather than a try/catch around an expected outcome.
      final String? result = await RemoteCall.guardNullable(
        () async => throw const NotFoundException(),
        label: 'test',
      );

      expect(result, isNull);
    });

    test('guardNullable still throws anything else', () async {
      await expectLater(
        RemoteCall.guardNullable<void>(
          () async => throw const PermissionException(),
          label: 'test',
        ),
        throwsA(isA<PermissionException>()),
      );
    });
  });
}
