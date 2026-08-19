import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/config/app_env.dart';

/// [AppEnv]'s values are compile-time, so a test cannot vary them — a
/// `--dart-define` is baked in before this file runs. What *is* testable, and
/// what actually matters, is the logic around them: the flavour parser and the
/// privileged-key detector.
void main() {
  /// Builds an unsigned JWT with [role] in its payload, in the shape Supabase's
  /// legacy keys use.
  String jwtWithRole(String role) {
    String encode(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

    final String header = encode(<String, Object?>{
      'alg': 'HS256',
      'typ': 'JWT',
    });
    final String payload = encode(<String, Object?>{
      'iss': 'supabase',
      'role': role,
    });

    return '$header.$payload.signature-not-verified';
  }

  group('AppFlavor.parse', () {
    test('reads each documented flavour', () {
      expect(AppFlavor.parse('development'), AppFlavor.development);
      expect(AppFlavor.parse('staging'), AppFlavor.staging);
      expect(AppFlavor.parse('production'), AppFlavor.production);
    });

    test('is case insensitive', () {
      expect(AppFlavor.parse('Production'), AppFlavor.production);
      expect(AppFlavor.parse('STAGING'), AppFlavor.staging);
    });

    test('an unknown value falls back to development', () {
      // The safe default is the one that cannot touch production data. A typo in
      // a build script must not silently point a build at production.
      expect(AppFlavor.parse('prod'), AppFlavor.development);
      expect(AppFlavor.parse(''), AppFlavor.development);
      expect(AppFlavor.parse('live'), AppFlavor.development);
    });
  });

  group('the privileged-key guard', () {
    // The failure this prevents: the service_role key sits directly beneath the
    // publishable key on the Supabase dashboard. Paste the wrong one and the app
    // works perfectly, while every Row Level Security policy is bypassed and the
    // key is readable by anyone who unzips the build. Nothing else in the stack
    // would notice.
    test('the current build is not carrying a privileged key', () {
      expect(AppEnv.assertNoPrivilegedKey, returnsNormally);
    });

    test('an anon JWT is recognised as safe', () {
      expect(AppEnv.isPrivilegedKey(jwtWithRole('anon')), isFalse);
    });

    test('an authenticated JWT is recognised as safe', () {
      expect(AppEnv.isPrivilegedKey(jwtWithRole('authenticated')), isFalse);
    });

    test('a service_role JWT is refused', () {
      expect(AppEnv.isPrivilegedKey(jwtWithRole('service_role')), isTrue);
    });

    test('a new-style secret key is refused by its prefix', () {
      expect(
        AppEnv.isPrivilegedKey('sb_secret_abc123'),
        isTrue,
        reason: 'the current dashboard names it sb_secret_ rather than a JWT',
      );
    });

    test('a new-style publishable key is allowed', () {
      expect(AppEnv.isPrivilegedKey('sb_publishable_abc123'), isFalse);
    });

    test('an empty key is not treated as privileged', () {
      // No credentials is a supported state — a fresh clone runs without a
      // backend. It must not be confused with a dangerous one.
      expect(AppEnv.isPrivilegedKey(''), isFalse);
    });

    test('a malformed key is not treated as privileged', () {
      // Undecodable is not evidence of privilege, and throwing here would break
      // startup for a merely wrong value.
      expect(AppEnv.isPrivilegedKey('not-a-jwt'), isFalse);
      expect(AppEnv.isPrivilegedKey('a.b.c'), isFalse);
      expect(AppEnv.isPrivilegedKey('...'), isFalse);
    });
  });

  group('describe', () {
    test('never includes the key or the URL', () {
      // A log line ends up in bug reports. The URL identifies the project and
      // the key is a credential; neither belongs in one.
      final String description = AppEnv.describe();

      expect(description, contains('flavor'));
      expect(description, contains('backend'));

      if (AppEnv.supabaseKey.isNotEmpty) {
        expect(description, isNot(contains(AppEnv.supabaseKey)));
      }
      if (AppEnv.supabaseUrl.isNotEmpty) {
        expect(description, isNot(contains(AppEnv.supabaseUrl)));
      }
    });
  });

  group('verbose logging', () {
    test('is never on in production', () {
      // Enforced by the getter rather than by build discipline, because a
      // release build with debug logging is an information leak.
      if (AppEnv.isProduction) {
        expect(AppEnv.isVerboseLogging, isFalse);
      }
    });
  });
}
