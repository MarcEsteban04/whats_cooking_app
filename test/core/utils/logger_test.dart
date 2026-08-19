import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// docs/CODING_STANDARDS.md §10: "strip sensitive fields from logs."
///
/// A log line is the easiest route for a token to reach a crash report, and
/// redaction that lives at each call site is redaction that gets forgotten. These
/// tests cover the central stripper rather than any particular call.
void main() {
  group('redaction', () {
    test('strips a token', () {
      expect(
        AppLog.redact(<String, Object?>{'access_token': 'secret-value'}),
        <String, Object?>{'access_token': '<redacted>'},
      );
    });

    test('matches field names case-insensitively and as substrings', () {
      // Three entries in the deny list have to cover access_token, refreshToken
      // and Authorization, so matching is deliberately loose.
      final Object? redacted = AppLog.redact(<String, Object?>{
        'refreshToken': 'a',
        'Authorization': 'b',
        'API_KEY': 'c',
        'userPassword': 'd',
      });

      expect(redacted, <String, Object?>{
        'refreshToken': '<redacted>',
        'Authorization': '<redacted>',
        'API_KEY': '<redacted>',
        'userPassword': '<redacted>',
      });
    });

    test('strips an email address', () {
      // PII, and docs/ARCHITECTURE.md §10 requires analytics carry none.
      expect(
        AppLog.redact(<String, Object?>{'email': 'marc@example.com'}),
        <String, Object?>{'email': '<redacted>'},
      );
    });

    test('keeps everything else', () {
      expect(
        AppLog.redact(<String, Object?>{'mealId': 'abc', 'count': 3}),
        <String, Object?>{'mealId': 'abc', 'count': 3},
      );
    });

    test('recurses into nested maps', () {
      // The shape that actually turns up is a nested Supabase response, not a
      // flat map.
      expect(
        AppLog.redact(<String, Object?>{
          'session': <String, Object?>{
            'access_token': 'secret',
            'expires_in': 3600,
          },
        }),
        <String, Object?>{
          'session': <String, Object?>{
            'access_token': '<redacted>',
            'expires_in': 3600,
          },
        },
      );
    });

    test('recurses into lists of maps', () {
      expect(
        AppLog.redact(<Object?>[
          <String, Object?>{'token': 'a', 'id': 1},
          <String, Object?>{'token': 'b', 'id': 2},
        ]),
        <Object?>[
          <String, Object?>{'token': '<redacted>', 'id': 1},
          <String, Object?>{'token': '<redacted>', 'id': 2},
        ],
      );
    });

    test('passes scalars through untouched', () {
      expect(AppLog.redact('a string'), 'a string');
      expect(AppLog.redact(42), 42);
      expect(AppLog.redact(null), isNull);
    });

    test('handles a map with non-string keys', () {
      // Not hypothetical: a decoded JSON payload can carry integer keys, and
      // throwing while trying to log is the worst possible failure mode.
      expect(
        AppLog.redact(<Object?, Object?>{1: 'one', 'token': 'x'}),
        <String, Object?>{'1': 'one', 'token': '<redacted>'},
      );
    });
  });

  group('the deny list', () {
    test('covers the credentials this app actually handles', () {
      expect(
        AppLog.redactionKeys,
        containsAll(<String>[
          'password',
          'token',
          'secret',
          'key',
          'authorization',
          'email',
        ]),
      );
    });
  });

  group('logging does not throw', () {
    test('at any level, with or without data', () {
      // The logger is called from error paths, so a logger that can throw turns
      // a handled failure into a crash.
      expect(() => AppLog.debug('debug'), returnsNormally);
      expect(() => AppLog.info('info'), returnsNormally);
      expect(() => AppLog.warning('warning'), returnsNormally);
      expect(
        () => AppLog.error(
          'error',
          error: StateError('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
      expect(
        () => AppLog.info('with data', data: <String, Object?>{'token': 'x'}),
        returnsNormally,
      );
    });
  });
}
