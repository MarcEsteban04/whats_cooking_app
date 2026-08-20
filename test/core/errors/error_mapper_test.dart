import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';

/// docs/ARCHITECTURE.md §4: "**No Supabase type crosses the data boundary.** A
/// `PostgrestException` reaching a widget is a review failure."
///
/// The mapper is the only thing standing between a raw backend error and a
/// screen, so every branch is covered here.
void main() {
  group('Postgres failures', () {
    test('an RLS denial becomes a permission failure, not a server error', () {
      // The mapping that matters most. 42501 means the policy said no — telling
      // the user "something went wrong" and offering a retry is both wrong and
      // an invitation to hammer a button that cannot work.
      final AppException mapped = ErrorMapper.map(
        const supabase.PostgrestException(
          message: 'permission denied',
          code: '42501',
        ),
      );

      expect(mapped, isA<PermissionException>());
      expect(mapped.isRetryable, isFalse);
      expect(mapped.code, '42501');
    });

    test('no rows from .single() becomes not-found', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.PostgrestException(
          message: 'JSON object requested, multiple (or no) rows returned',
          code: 'PGRST116',
        ),
      );

      expect(mapped, isA<NotFoundException>());
    });

    test('a unique violation becomes a validation failure', () {
      // A duplicate is the client asking for something the schema forbids, so it
      // is the client's fault rather than the server's.
      final AppException mapped = ErrorMapper.map(
        const supabase.PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        ),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.message, 'That already exists');
    });

    test('check and foreign-key violations become validation failures', () {
      for (final String code in <String>['23514', '23503']) {
        expect(
          ErrorMapper.map(
            supabase.PostgrestException(message: 'violates', code: code),
          ),
          isA<ValidationException>(),
          reason: code,
        );
      }
    });

    test('anything else becomes a retryable server error', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.PostgrestException(
          message: 'internal error',
          code: '500',
        ),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.isRetryable, isTrue);
    });
  });

  group('auth failures', () {
    test('an expired session is retryable so it can be refreshed', () {
      // docs/ARCHITECTURE.md §7: a 401 triggers one silent refresh-and-retry
      // before the user sees anything.
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException('JWT expired', statusCode: '401'),
      );

      expect(mapped, isA<AuthFailureException>());
      expect((mapped as AuthFailureException).isSessionExpired, isTrue);
      expect(mapped.isRetryable, isTrue);
    });

    test('a rejected credential is not retryable', () {
      // Retrying a wrong password just locks the account faster.
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException('Invalid login credentials'),
      );

      expect(mapped, isA<AuthFailureException>());
      expect((mapped as AuthFailureException).isSessionExpired, isFalse);
      expect(mapped.isRetryable, isFalse);
      expect(mapped.message, 'Those details did not match');
    });

    test('an unconfirmed address says so instead of blaming the password', () {
      // Supabase returns its own distinct error here. Folding it into "those
      // details did not match" tells someone their password is wrong when it is
      // not, and they go and change a password that was already correct.
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      );

      expect(mapped, isA<AuthFailureException>());
      expect(mapped.message, contains('Confirm your email'));
      expect(
        (mapped as AuthFailureException).isSessionExpired,
        isFalse,
        reason: 'there is no session to refresh',
      );
    });

    test('the enumeration defence still holds for a wrong password', () {
      // docs/USER_FLOWS.md §3. The confirmation case above is a different axis:
      // it does not reveal which *field* was wrong, and the API response
      // already carries it either way.
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException('Invalid login credentials'),
      );

      for (final String leak in <String>['password', 'email', 'account']) {
        expect(
          mapped.message.toLowerCase(),
          isNot(contains(leak)),
          reason: leak,
        );
      }
    });
  });

  group('storage failures', () {
    test('404 becomes not-found and 403 becomes permission', () {
      expect(
        ErrorMapper.map(
          const supabase.StorageException('not found', statusCode: '404'),
        ),
        isA<NotFoundException>(),
      );
      expect(
        ErrorMapper.map(
          const supabase.StorageException('forbidden', statusCode: '403'),
        ),
        isA<PermissionException>(),
      );
    });

    test('anything else gets image-specific wording', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.StorageException('boom', statusCode: '500'),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.message, "We couldn't load that image");
    });
  });

  group('platform failures', () {
    test('a socket failure becomes a retryable network error', () {
      final AppException mapped = ErrorMapper.map(
        const SocketException('Failed host lookup'),
      );

      expect(mapped, isA<NetworkException>());
      expect(mapped.isRetryable, isTrue);
    });

    test('a timeout becomes a network error', () {
      final AppException mapped = ErrorMapper.map(
        TimeoutException('too slow', const Duration(seconds: 10)),
      );

      expect(mapped, isA<NetworkException>());
      expect(mapped.message, 'That took too long');
    });

    test('a malformed response becomes a server error', () {
      // The response arrived; it was the *shape* that was wrong, which is the
      // backend's problem and not the connection's.
      expect(
        ErrorMapper.map(const FormatException('unexpected token')),
        isA<ServerException>(),
      );
    });

    test('anything unrecognised becomes unknown', () {
      expect(ErrorMapper.map(ArgumentError('nope')), isA<UnknownException>());
    });
  });

  group('mapping is idempotent', () {
    test('an AppException passes through unchanged', () {
      // Mapping twice would replace a specific message written at a throw site
      // with a generic one — and RemoteCall maps on the way out of a call that
      // may already have mapped internally.
      const AppException original = ValidationException(
        message: 'Enter a budget above zero',
        field: 'budget',
      );

      expect(ErrorMapper.map(original), same(original));
    });
  });

  group('nothing technical is exposed for display', () {
    test('the message never carries the backend text', () {
      const String backendText =
          'PostgrestException(message: relation "meals" does not exist)';

      final AppException mapped = ErrorMapper.map(
        const supabase.PostgrestException(message: backendText, code: '42P01'),
      );

      expect(mapped.message, isNot(contains('Postgrest')));
      expect(mapped.message, isNot(contains('relation')));
      expect(
        mapped.detail,
        contains('relation'),
        reason: 'the technical text is kept for logging, just not for display',
      );
    });

    test('the cause is preserved for logs', () {
      const supabase.PostgrestException original = supabase.PostgrestException(
        message: 'boom',
        code: '500',
      );

      expect(ErrorMapper.map(original).cause, same(original));
    });
  });

  group('presentation', () {
    test('every failure kind maps to error-state copy', () {
      final Map<AppException, ErrorStateKind> expected =
          <AppException, ErrorStateKind>{
            const NetworkException(): ErrorStateKind.network,
            const ServerException(): ErrorStateKind.server,
            const NotFoundException(): ErrorStateKind.notFound,
            const PermissionException(): ErrorStateKind.permission,
            const UnknownException(): ErrorStateKind.unknown,
          };

      expected.forEach((AppException error, ErrorStateKind kind) {
        expect(error.errorStateKind, kind, reason: '$error');
      });
    });

    test('only a validation failure supplies its own wording', () {
      // Its message is written at the throw site and is more useful than
      // anything generic; everything else uses the copy tables.
      expect(
        const ValidationException(message: 'Enter a budget above zero')
            .displayMessage,
        'Enter a budget above zero',
      );
      expect(const ServerException().displayMessage, isNull);
      expect(const NetworkException().displayMessage, isNull);
    });

    test('a retry is offered only where retrying could work', () {
      expect(const NetworkException().shouldOfferRetry, isTrue);
      expect(const ServerException().shouldOfferRetry, isTrue);
      expect(const PermissionException().shouldOfferRetry, isFalse);
      expect(const NotFoundException().shouldOfferRetry, isFalse);
    });

    test('a support code is available but separate from the message', () {
      // docs/COMPONENTS.md §13: a code may appear beneath the action, never in
      // the primary message.
      const AppException mapped = ServerException(
        detail: 'internal',
        code: 'PGRST500',
      );

      expect(mapped.supportCode, 'PGRST500');
      expect(mapped.message, isNot(contains('PGRST500')));
    });
  });
}
