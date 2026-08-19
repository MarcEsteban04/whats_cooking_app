import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/backend_health.dart';

/// The classification half of the health probe.
///
/// Split out from the query precisely so this can be tested: turning a failure
/// into a *diagnosis* is the part with judgement in it, and the part that saves
/// an afternoon when a fresh checkout does not work.
void main() {
  Future<BackendStatus> classify({
    required Future<void> Function() probe,
    bool isConfigured = true,
  }) {
    return BackendHealth.classify(probe: probe, isConfigured: isConfigured);
  }

  group('classification', () {
    test('no credentials reads as not configured, not as broken', () async {
      // Expected on a fresh clone, so it must not look like a failure.
      expect(
        await classify(probe: () async {}, isConfigured: false),
        BackendStatus.notConfigured,
      );
    });

    test('a query that returns is healthy', () async {
      expect(await classify(probe: () async {}), BackendStatus.healthy);
    });

    test('a network failure is unreachable', () async {
      expect(
        await classify(probe: () async => throw const NetworkException()),
        BackendStatus.unreachable,
      );
    });

    test('a refused query means the schema is missing', () async {
      // The case worth separating. Reached but refused, on a table the anon key
      // is granted by design, means schema.sql was never applied to this
      // project — which otherwise looks exactly like a broken app.
      expect(
        await classify(probe: () async => throw const ServerException()),
        BackendStatus.schemaUnavailable,
      );
      expect(
        await classify(probe: () async => throw const PermissionException()),
        BackendStatus.schemaUnavailable,
      );
      expect(
        await classify(probe: () async => throw const NotFoundException()),
        BackendStatus.schemaUnavailable,
      );
    });

    test('the configured check runs before the probe', () async {
      // An unconfigured build must not attempt a request at all.
      bool probed = false;

      await classify(probe: () async => probed = true, isConfigured: false);

      expect(probed, isFalse);
    });
  });

  group('status', () {
    test('only healthy is usable', () {
      expect(BackendStatus.healthy.isUsable, isTrue);

      for (final BackendStatus status in <BackendStatus>[
        BackendStatus.notConfigured,
        BackendStatus.unreachable,
        BackendStatus.schemaUnavailable,
      ]) {
        expect(status.isUsable, isFalse, reason: status.name);
      }
    });

    test('every state says what to do about it', () {
      // The point of four states rather than a bool: each failure has a
      // different fix, and the log line should name it.
      expect(
        BackendStatus.notConfigured.description,
        contains('config/development.json'),
      );
      expect(BackendStatus.unreachable.description, contains('SUPABASE_URL'));
      expect(
        BackendStatus.schemaUnavailable.description,
        contains('schema.sql'),
      );

      for (final BackendStatus status in BackendStatus.values) {
        expect(status.description, isNotEmpty, reason: status.name);
      }
    });

    test('no description leaks a credential', () {
      // These are logged at launch, and a log line ends up in bug reports.
      for (final BackendStatus status in BackendStatus.values) {
        expect(status.description.toLowerCase(), isNot(contains('sb_')));
        expect(status.description.toLowerCase(), isNot(contains('eyj')));
      }
    });
  });
}
