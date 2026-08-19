import 'dart:convert';

/// Which backend the build points at (docs/project_dev.md, Release Strategy).
///
/// "Development data must never be mixed with production data", so the flavour
/// is a compile-time value rather than a runtime setting — a build cannot be
/// talked into changing which database it is pointed at.
enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor parse(String value) {
    return AppFlavor.values.firstWhere(
      (AppFlavor flavor) => flavor.name == value.toLowerCase(),
      // An unrecognised flavour reads as development rather than throwing: the
      // safe default is the one that cannot touch production data.
      orElse: () => AppFlavor.development,
    );
  }
}

/// Compile-time environment values (docs/ARCHITECTURE.md §2.4).
///
/// Supplied by `--dart-define-from-file=config/development.json`
/// (docs/LOCAL_SETUP.md §2). Compile-time rather than read from a bundled file
/// because a `.env` asset shipped inside an APK is readable by anyone who
/// unzips it, and because `String.fromEnvironment` is const — the values are
/// baked in and there is no startup I/O to fail.
///
/// **The client holds the anon/publishable key and nothing else**
/// (docs/ARCHITECTURE.md §1). [assertNoPrivilegedKey] enforces that.
abstract final class AppEnv {
  static const String _url = String.fromEnvironment('SUPABASE_URL');

  /// The current dashboard's name for the client key.
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// What older dashboards called the same thing (supabase/README.md).
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String _flavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'development',
  );

  static const bool _verboseLogging = bool.fromEnvironment('VERBOSE_LOGGING');

  static AppFlavor get flavor => AppFlavor.parse(_flavor);

  static bool get isProduction => flavor == AppFlavor.production;
  static bool get isDevelopment => flavor == AppFlavor.development;

  static String get supabaseUrl => _url;

  /// The client key, accepting either name so a value copied from an older
  /// dashboard works unchanged.
  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Whether there are credentials to connect with.
  ///
  /// supabase/README.md: "Without credentials it logs a warning and runs without
  /// a backend rather than crashing — a fresh clone still starts." Someone who
  /// has just cloned the repo should be able to run the app and see the UI
  /// before they have a Supabase project.
  static bool get isBackendConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Whether to log at debug level.
  ///
  /// Forced off in production regardless of what the build passed in: verbose
  /// logs in a release build are an information leak, and
  /// docs/project_dev.md's security checklist requires sensitive logs removed.
  static bool get isVerboseLogging => _verboseLogging && !isProduction;

  /// Fails the build's first frame if a privileged key was supplied.
  ///
  /// The `service_role` key bypasses every RLS policy
  /// (docs/CODING_STANDARDS.md §10), and it sits two lines below the
  /// publishable key on the Supabase dashboard — one careless copy-paste away.
  /// Nothing else in the stack would notice: the app would work perfectly and
  /// ship with every row in the database readable by anyone who extracted the
  /// key from the bundle.
  ///
  /// Throws a [StateError] rather than logging, because there is no safe way to
  /// continue: the whole security model is RLS, and this key ignores it.
  static void assertNoPrivilegedKey() {
    if (isPrivilegedKey(supabaseKey)) {
      throw StateError(_privilegedKeyMessage);
    }
  }

  /// Whether [key] grants more than the client is allowed to hold.
  ///
  /// Two forms are refused, because Supabase has issued both:
  ///
  /// * `sb_secret_…` — the current dashboard's secret key.
  /// * A JWT whose payload claims `"role": "service_role"` — the legacy form.
  ///
  /// An empty key is *not* privileged: running without credentials is a
  /// supported state, and confusing it with a dangerous one would break the
  /// fresh-clone path. Neither is a malformed key — undecodable is not evidence
  /// of privilege, and throwing on one would turn a merely wrong value into a
  /// failure to start.
  static bool isPrivilegedKey(String key) {
    if (key.isEmpty) {
      return false;
    }
    return key.startsWith(_secretKeyPrefix) || _isServiceRoleJwt(key);
  }

  /// Whether [key] is a JWT whose payload claims the `service_role` role.
  ///
  /// Legacy Supabase keys are JWTs carrying `{"role": "anon"}` or
  /// `{"role": "service_role"}`. Only the payload is inspected — no verification
  /// is attempted or needed, since the question is what the key claims to be,
  /// not whether the claim is genuine.
  static bool _isServiceRoleJwt(String key) {
    final List<String> segments = key.split('.');
    if (segments.length != 3) {
      return false;
    }

    try {
      final String payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      final Object? decoded = jsonDecode(payload);

      return decoded is Map<String, dynamic> &&
          decoded['role'] == 'service_role';
    } on Object {
      // Undecodable means it is not a JWT this check understands, which is not
      // itself evidence of a privileged key.
      return false;
    }
  }

  /// A description of the environment safe to log.
  ///
  /// Names the flavour and whether a backend is configured, and **never the key
  /// or the URL** — the URL identifies the project and belongs in a dashboard,
  /// not in a log file that might be attached to a bug report.
  static String describe() {
    return 'flavor: ${flavor.name}, '
        'backend: ${isBackendConfigured ? 'configured' : 'not configured'}, '
        'verbose: $isVerboseLogging';
  }

  static const String _secretKeyPrefix = 'sb_secret_';

  static const String _privilegedKeyMessage =
      'A privileged Supabase key was supplied to the Flutter client. The client '
      'must carry only the publishable (anon) key: the service_role key '
      'bypasses every Row Level Security policy and is readable by anyone who '
      'unpacks the build. Use the publishable key in '
      'config/development.json, and keep the service_role key in Edge Function '
      'secrets only.';
}
