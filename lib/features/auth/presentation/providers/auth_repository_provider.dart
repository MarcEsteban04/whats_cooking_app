import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:whats_cooking/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:whats_cooking/features/auth/domain/repositories/auth_repository.dart';

part 'auth_repository_provider.g.dart';

/// The auth backend.
///
/// In its own file so both the session notifier and the form controller can read
/// it without importing each other.
///
/// Supabase when the build has credentials, and the in-memory stand-in when it
/// does not. supabase/README.md promises a fresh clone still runs; that promise
/// is worth more if the app is *usable* without a backend rather than merely
/// starting and then failing at the first sign-in.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: authentication is in-memory and will not persist.',
      name: 'authRepository',
    );
    return InMemoryAuthRepository();
  }

  return SupabaseAuthRepository(ref.read(supabaseClientProvider));
}
