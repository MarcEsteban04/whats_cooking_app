import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';

part 'backend_health.g.dart';

/// What the backend is doing, as far as the app can tell.
///
/// Four states rather than a bool, because "it did not work" has four different
/// fixes and telling them apart at launch is the difference between a five-minute
/// diagnosis and an afternoon of one.
enum BackendStatus {
  /// No credentials were supplied. Expected on a fresh clone.
  notConfigured,

  /// A query returned. The URL, the key, the schema and the grants all work.
  healthy,

  /// The host could not be reached: no connectivity, DNS failure, or a wrong URL.
  unreachable,

  /// Reached, but the query was rejected.
  ///
  /// Almost always means `schema.sql` has not been applied to this project, or
  /// the `anon` grants were not — the reachable-but-empty case that otherwise
  /// looks identical to a broken app.
  schemaUnavailable;

  bool get isUsable => this == BackendStatus.healthy;

  /// A line safe to log and to show a developer.
  String get description => switch (this) {
    BackendStatus.notConfigured =>
      'No backend configured. Copy config/development.example.json to '
          'config/development.json.',
    BackendStatus.healthy => 'Backend healthy.',
    BackendStatus.unreachable =>
      'Backend unreachable. Check connectivity and SUPABASE_URL.',
    BackendStatus.schemaUnavailable =>
      'Backend reached but the query was refused. Apply supabase/schema.sql, '
          'then run supabase/verify.sql.',
  };
}

/// Probes the backend (Sprint 11's "Test database connectivity").
///
/// The probe reads one row from the public meal catalogue. That table is chosen
/// deliberately: `supabase/migrations/…_grants.sql` grants `select on meals to
/// anon`, so this works **before anyone signs in** — a health check that needed a
/// session could not run at launch, which is the only moment it is useful.
abstract final class BackendHealth {
  /// Classifies the outcome of [probe].
  ///
  /// Separated from the query so the interesting half — turning a failure into a
  /// diagnosis — is unit tested without a network or a Supabase client.
  static Future<BackendStatus> classify({
    required Future<void> Function() probe,
    required bool isConfigured,
  }) async {
    if (!isConfigured) {
      return BackendStatus.notConfigured;
    }

    try {
      await probe();
      return BackendStatus.healthy;
    } on NetworkException {
      return BackendStatus.unreachable;
    } on AppException {
      // Anything the backend actively refused. The catalogue is readable by the
      // anon key by design, so a refusal means the schema or the grants are not
      // in place rather than that the caller lacks permission.
      return BackendStatus.schemaUnavailable;
    }
  }

  /// Runs the real probe against [client].
  static Future<BackendStatus> check(SupabaseClient client) {
    return classify(
      isConfigured: SupabaseBootstrap.isInitialized,
      probe: () => RemoteCall.guard(
        () => client.from(_probeTable).select(_probeColumn).limit(1),
        label: 'backendHealthCheck',
        // One attempt: this runs at launch and its answer is a diagnosis, not
        // data the app needs. Retrying would delay the first frame to improve a
        // log line.
        policy: RetryPolicy.none,
        timeout: _probeTimeout,
      ),
    );
  }

  static const String _probeTable = 'meals';
  static const String _probeColumn = 'id';

  /// Short on purpose: a slow answer is as useful as no answer here, and this
  /// must not hold up the app.
  static const Duration _probeTimeout = Duration(seconds: 5);
}

/// The Supabase client.
///
/// Throws when the SDK was never initialised, which is a programming error
/// rather than a runtime condition: a repository must not be reachable in a
/// build that has no backend. Screens ask [backendStatus] instead.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    throw StateError(
      'Supabase is not initialised. Either the app was built without '
      'credentials, or something reached a repository before the backend was '
      'available — check BackendStatus first.',
    );
  }
  return Supabase.instance.client;
}

/// The backend's state, resolved once per launch.
///
/// Kept alive: the answer does not change without a restart, and re-probing on
/// every screen that asks would spend a request on a question already answered.
@Riverpod(keepAlive: true)
Future<BackendStatus> backendStatus(Ref ref) async {
  if (!SupabaseBootstrap.isInitialized) {
    const BackendStatus status = BackendStatus.notConfigured;
    AppLog.info(status.description, name: _name);
    return status;
  }

  final BackendStatus status = await BackendHealth.check(
    ref.read(supabaseClientProvider),
  );

  // supabase/README.md: "The app reports backend health on launch."
  if (status.isUsable) {
    AppLog.info(status.description, name: _name);
  } else {
    AppLog.warning(status.description, name: _name);
  }

  return status;
}

const String _name = 'BackendHealth';
