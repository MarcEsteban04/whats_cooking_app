import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';

part 'session_provider.g.dart';

/// The app's single source of auth truth (docs/ARCHITECTURE.md §7).
///
/// The router's redirect reads this and nothing else, so every guard decision in
/// the app comes from one value.
///
/// **Sprint 17 replaces the body of this notifier**, not its interface. It
/// currently starts signed out and exposes the transitions the router needs to
/// be tested against; Sprint 17 wires [build] to `supabase.auth.onAuthStateChange`
/// and the profile row that carries `is_onboarded` and `active_household_id`.
/// Keeping the shape fixed now is what let Sprint 09 build and verify the guards
/// before authentication exists.
@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  AppSession build() {
    // Signed out rather than restoring: with no Supabase client yet there is
    // nothing to restore, and starting in `restoring` would pin the app to the
    // splash screen forever. Sprint 17 starts from `restoring` and resolves it
    // when the SDK reports a session, which is what the splash screen exists
    // for.
    return const AppSession.signedOut();
  }

  /// Signs a user in.
  void signIn({required bool isOnboarded, required bool hasHousehold}) {
    state = AppSession.signedIn(
      isOnboarded: isOnboarded,
      hasHousehold: hasHousehold,
    );
  }

  /// Signs the current user out.
  void signOut() => state = const AppSession.signedOut();

  /// Marks onboarding complete, which releases the onboarding-zone guard.
  void completeOnboarding() => state = state.copyWith(isOnboarded: true);

  /// Records that an active household exists.
  void setHasHousehold(bool value) =>
      state = state.copyWith(hasHousehold: value);
}
