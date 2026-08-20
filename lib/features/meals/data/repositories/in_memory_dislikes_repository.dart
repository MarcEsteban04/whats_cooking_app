import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/meals/domain/repositories/dislikes_repository.dart';

/// [DislikesRepository] held in memory.
///
/// The no-backend fallback and the tests' backend. Both writes are idempotent
/// here for the same reason the PostgREST version upserts: a double tap must not
/// become an error.
class InMemoryDislikesRepository implements DislikesRepository {
  InMemoryDislikesRepository({
    Set<String>? initial,
    this.latency = _defaultLatency,
  }) : _ids = <String>{...?initial};

  final Set<String> _ids;

  /// Simulated round trip. Exposed so a widget test can advance the fake clock
  /// past it rather than awaiting a real delay, which deadlocks the binding.
  final Duration latency;

  /// Set to make every write fail, for exercising the rollback.
  bool failWrites = false;

  /// Set to make the read fail.
  bool failReads = false;

  @override
  Future<Set<String>> mealIds() async {
    await Future<void>.delayed(latency);
    if (failReads) {
      throw const ServerException();
    }
    // A copy, so a caller mutating the result cannot silently change the store.
    return <String>{..._ids};
  }

  @override
  Future<void> add(String mealId) async {
    await Future<void>.delayed(latency);
    if (failWrites) {
      throw const ServerException();
    }
    _ids.add(mealId);
  }

  @override
  Future<void> remove(String mealId) async {
    await Future<void>.delayed(latency);
    if (failWrites) {
      throw const ServerException();
    }
    _ids.remove(mealId);
  }

  static const Duration _defaultLatency = Duration(milliseconds: 150);
}
