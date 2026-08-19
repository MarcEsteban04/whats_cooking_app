import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// Holds the Supabase session in platform secure storage.
///
/// docs/ARCHITECTURE.md §7: "Session and refresh tokens are held by
/// `supabase_flutter` in platform secure storage — Keychain on iOS,
/// EncryptedSharedPreferences on Android. **Never** in plain
/// `SharedPreferences`."
///
/// **`supabase_flutter` does not do this by default.** Version 2.17.2 falls back
/// to `SharedPreferencesLocalStorage` when no storage is supplied, which is
/// exactly the plain-preferences case §7 forbids: a refresh token sitting in a
/// world-readable XML file on a rooted device, or in an unencrypted iOS
/// preferences plist. Nothing would look wrong — sign-in would work perfectly —
/// so this has to be passed in explicitly at initialisation.
///
/// A refresh token is long-lived and exchangeable for access tokens, so it is the
/// single most valuable string the app ever holds.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android's defaults in flutter_secure_storage 11 are already the
            // strong ones — AES-GCM data encryption under an RSA-OAEP wrapped,
            // KeyStore-backed key — so they are taken as they come rather than
            // restated. Biometrics are deliberately *not* required: a session
            // token that needs a fingerprint to read would prompt on every cold
            // start, and the app is a meal picker, not a bank.
            iOptions: IOSOptions(
              // Readable after the device's first unlock, and scoped to this
              // device: `ThisDevice` keeps the token out of iCloud Keychain and
              // out of an unencrypted backup, so a session cannot follow someone
              // onto a different phone.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  /// The key the session is stored under.
  ///
  /// Namespaced so it cannot collide with anything else this app keeps in secure
  /// storage later.
  static const String sessionKey = 'whats_cooking.supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: sessionKey);
    } on Object catch (error, stackTrace) {
      // A read failure must not be fatal. The keystore can genuinely fail — a
      // restored backup on Android can leave an undecryptable entry — and the
      // correct response is to treat the session as absent and let the user sign
      // in again, not to crash on launch.
      AppLog.warning(
        'Could not read the stored session; treating it as absent',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
      AppLog.debug('Session read failed', name: _name, data: stackTrace);
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: sessionKey, value: persistSessionString);
    } on Object catch (error) {
      // Logged rather than thrown: failing to persist costs the user a re-login
      // next launch, while throwing would break the sign-in that just succeeded.
      AppLog.warning(
        'Could not persist the session; sign-in will not survive a restart',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: sessionKey);
    } on Object catch (error) {
      // This one is worth an error: a sign-out that leaves the token behind is a
      // security problem, not an inconvenience.
      AppLog.error(
        'Could not remove the persisted session on sign-out',
        error: error,
        name: _name,
      );
    }
  }

  static const String _name = 'SecureSessionStorage';
}
