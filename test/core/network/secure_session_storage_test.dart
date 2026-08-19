import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/network/secure_session_storage.dart';

/// A [FlutterSecureStorage] backed by a map, optionally failing.
///
/// The real one needs a platform channel, so the adapter's behaviour — and
/// specifically what it does when the keystore misbehaves — is exercised against
/// this instead.
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage({this.throwOnRead = false, this.throwOnWrite = false});

  final Map<String, String> values = <String, String>{};
  final bool throwOnRead;
  final bool throwOnWrite;

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnRead) {
      throw PlatformException(code: 'keystore-unavailable');
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnWrite) {
      throw PlatformException(code: 'keystore-unavailable');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

/// Stands in for the platform exception the keystore actually throws.
class PlatformException implements Exception {
  PlatformException({required this.code});

  final String code;
}

/// docs/ARCHITECTURE.md §7: session and refresh tokens live in platform secure
/// storage, "**Never** in plain `SharedPreferences`".
void main() {
  group('round trip', () {
    test('persists and reads back a session', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final SecureSessionStorage storage = SecureSessionStorage(storage: fake);

      await storage.persistSession('session-json');

      expect(await storage.accessToken(), 'session-json');
      expect(await storage.hasAccessToken(), isTrue);
    });

    test('reports no token before anything is stored', () async {
      final SecureSessionStorage storage = SecureSessionStorage(
        storage: _FakeSecureStorage(),
      );

      expect(await storage.accessToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('removes the session on sign-out', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final SecureSessionStorage storage = SecureSessionStorage(storage: fake);

      await storage.persistSession('session-json');
      await storage.removePersistedSession();

      expect(await storage.accessToken(), isNull);
      expect(
        fake.values,
        isEmpty,
        reason: 'a sign-out that leaves the token behind is a security problem',
      );
    });

    test('stores under a namespaced key', () async {
      // So it cannot collide with anything else the app keeps in secure storage.
      final _FakeSecureStorage fake = _FakeSecureStorage();
      await SecureSessionStorage(storage: fake).persistSession('x');

      expect(fake.values.keys.single, SecureSessionStorage.sessionKey);
      expect(SecureSessionStorage.sessionKey, startsWith('whats_cooking.'));
    });
  });

  group('keystore failures do not break the app', () {
    test('an unreadable session is treated as absent', () async {
      // Real and recoverable: a restored Android backup can leave an entry the
      // current keystore cannot decrypt. The right answer is to sign in again,
      // not to crash on launch.
      final SecureSessionStorage storage = SecureSessionStorage(
        storage: _FakeSecureStorage(throwOnRead: true),
      );

      expect(await storage.accessToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    });

    test(
      'a failed write does not break the sign-in that just succeeded',
      () async {
        // The cost is a re-login next launch; throwing would cost the user the
        // sign-in they just completed.
        final SecureSessionStorage storage = SecureSessionStorage(
          storage: _FakeSecureStorage(throwOnWrite: true),
        );

        await expectLater(storage.persistSession('session-json'), completes);
      },
    );
  });

  group('initialize', () {
    test('is a no-op, because secure storage needs no warm-up', () async {
      final SecureSessionStorage storage = SecureSessionStorage(
        storage: _FakeSecureStorage(),
      );

      await expectLater(storage.initialize(), completes);
    });
  });
}
