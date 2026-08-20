import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';

part 'current_user_provider.g.dart';

/// The signed-in user's id, or null.
///
/// Needed because reading and writing are scoped differently in several places:
/// `meals` is readable by the whole household but writable only by the author,
/// so a screen has to know who it is talking to before it offers an Edit button
/// (see `Meal.isWrittenBy`). Not a substitute for an auth check — the router's
/// redirect still owns that, from `sessionProvider` and nothing else
/// (docs/ARCHITECTURE.md §7).
///
/// Derived from the session rather than read straight off the client, so signing
/// out invalidates it instead of leaving a stale id behind a rebuild that never
/// comes.
@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    // The no-backend fallback signs nobody in, and returning null there would
    // hide the Edit button on meals the fallback itself just created. A fixed
    // id keeps a credential-less clone fully usable, and it is the same one
    // `InMemoryMealRepository` stamps on what it writes.
    return AppConstants.localAuthorId;
  }

  final AppSession session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return null;
  }

  return ref.read(supabaseClientProvider).auth.currentUser?.id;
}
