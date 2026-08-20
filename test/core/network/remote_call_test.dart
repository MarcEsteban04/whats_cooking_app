import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/domain_signal.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';

/// A deliberate outcome a repository reports by throwing.
class _Signal implements DomainSignal {
  const _Signal(this.detail);

  final String detail;
}

void main() {
  group('a domain signal is an answer, not a failure', () {
    // This is a regression test for a shipped bug. `signUp` threw
    // `EmailAlreadyRegistered` from inside a guarded call; the guard caught it
    // like anything else, `ErrorMapper` did not recognise it, and the user got
    // "Something went wrong" instead of the one-tap offer to sign in with the
    // address pre-filled. Two separate signals were being swallowed this way.
    test('passes through untouched instead of being mapped', () async {
      await expectLater(
        RemoteCall.guard<void>(
          () async => throw const _Signal('already registered'),
          label: 'test',
          policy: RetryPolicy.none,
        ),
        throwsA(isA<_Signal>()),
      );
    });

    test('is not retried, however permissive the policy', () async {
      // The answer was never in doubt, so re-sending the request cannot change
      // it — and for a sign-up, re-sending is how a duplicate account is made.
      int attempts = 0;

      await expectLater(
        RemoteCall.guard<void>(
          () async {
            attempts++;
            throw const _Signal('already registered');
          },
          label: 'test',
          policy: const RetryPolicy(initialDelay: Duration.zero),
        ),
        throwsA(isA<_Signal>()),
      );

      expect(attempts, 1);
    });

    test('a real failure is still mapped and still retried', () async {
      // The passthrough must not have opened a hole in the mapping rule:
      // docs/ARCHITECTURE.md §9 requires that no Supabase type escapes the data
      // layer.
      int attempts = 0;

      await expectLater(
        RemoteCall.guard<void>(
          () async {
            attempts++;
            throw const supabase.PostgrestException(message: 'boom');
          },
          label: 'test',
          policy: const RetryPolicy(initialDelay: Duration.zero),
        ),
        throwsA(isA<AppException>()),
      );

      expect(attempts, greaterThan(1), reason: 'a server failure is retryable');
    });
  });
}
