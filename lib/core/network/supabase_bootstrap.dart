import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/config/app_env.dart';
import 'package:whats_cooking/core/network/secure_session_storage.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// Brings up the Supabase SDK.
///
/// Sprint 11's "Connect Flutter to Supabase". Two rules shape it:
///
/// * **Missing credentials are not an error.** supabase/README.md: "Without
///   credentials it logs a warning and runs without a backend rather than
///   crashing — a fresh clone still starts."
/// * **Tokens go to secure storage**, not the SDK's default plain
///   `SharedPreferences` (docs/ARCHITECTURE.md §7). See
///   [SecureSessionStorage].
abstract final class SupabaseBootstrap {
  static bool _isInitialized = false;

  /// Whether [initialize] has completed successfully.
  ///
  /// False both when there are no credentials and when initialisation failed;
  /// `BackendStatus` is what distinguishes those for the user.
  static bool get isInitialized => _isInitialized;

  /// Initialises the SDK, returning whether a client is now available.
  ///
  /// Safe to call more than once — the second call is a no-op, which matters
  /// because a hot restart re-runs `main` without tearing down the isolate.
  static Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    if (!AppEnv.isBackendConfigured) {
      AppLog.warning(
        'Starting without a backend. Copy config/development.example.json to '
        'config/development.json and run with '
        '--dart-define-from-file=config/development.json.',
        name: _name,
      );
      return false;
    }

    try {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl,
        publishableKey: AppEnv.supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
          // PKCE rather than the implicit flow: the authorisation code is
          // exchanged with a verifier the client never transmits, so a token
          // cannot be lifted from a redirect URL. It is also what magic links
          // and OAuth require to be safe on mobile.
          authFlowType: AuthFlowType.pkce,
        ),
        // Off in production: the SDK's debug logging includes request bodies,
        // and docs/project_dev.md's security checklist requires sensitive logs
        // removed.
        debug: AppEnv.isVerboseLogging,
      );

      _isInitialized = true;
      AppLog.info('Supabase initialised', name: _name);
      return true;
    } on Object catch (error, stackTrace) {
      // Deliberately not rethrown. A backend that will not initialise — a
      // malformed URL, a platform channel that is unavailable — should leave the
      // app running and reporting its state, not dead on a black screen before
      // the first frame.
      AppLog.error(
        'Supabase failed to initialise; continuing without a backend',
        error: error,
        stackTrace: stackTrace,
        name: _name,
      );
      return false;
    }
  }

  /// Resets the flag so a test can exercise [initialize] more than once.
  ///
  /// Visible for testing only.
  static void resetForTesting() => _isInitialized = false;

  static const String _name = 'SupabaseBootstrap';
}
