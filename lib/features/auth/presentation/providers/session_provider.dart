import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_repository_provider.dart';

part 'session_provider.g.dart';

/// The app's single source of auth truth (docs/ARCHITECTURE.md §7).
///
/// The router's redirect reads this and nothing else, so every guard decision in
/// the app comes from one value. No screen performs its own auth check.
///
/// It listens to Supabase rather than being told about sign-ins. That matters
/// because sign-in is not the only way the session changes: a token refresh, a
/// sign-out on another tab, a recovery link, and the SDK giving up on an expired
/// refresh token all arrive here as events. A notifier that only heard from the
/// login screen would miss every one of them.
@Riverpod(keepAlive: true)
class Session extends _$Session {
  StreamSubscription<supabase.AuthState>? _subscription;

  @override
  AppSession build() {
    ref.onDispose(() => _subscription?.cancel());

    if (!SupabaseBootstrap.isInitialized) {
      // Nothing to restore without a backend, and starting in `restoring` would
      // pin the app to the splash screen forever.
      return const AppSession.signedOut();
    }

    _listen();
    unawaited(_restore());

    // Restoring, not signed out. The distinction is the whole reason the splash
    // route exists: reporting "signed out" here would flash the welcome screen
    // on every cold start before the stored session was read.
    return const AppSession.restoring();
  }

  /// Reads the session the SDK restored from secure storage.
  Future<void> _restore() async {
    try {
      final AppSession? restored = await ref
          .read(authRepositoryProvider)
          .restoreSession();

      // Only adopt it if nothing has happened since. An auth event that arrived
      // while the profile row was loading is newer than this answer, and
      // overwriting it would undo a sign-in or resurrect a sign-out.
      if (state.isRestoring) {
        state = restored ?? const AppSession.signedOut();
      }
    } on Object catch (error, stackTrace) {
      // A failed restore is a signed-out user, not a crash. The profile read can
      // fail offline, and the right outcome is the welcome screen rather than a
      // dead splash.
      AppLog.warning(
        'Could not restore the session; treating it as signed out',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
      AppLog.debug('Session restore failed', name: _name, data: stackTrace);

      if (state.isRestoring) {
        state = const AppSession.signedOut();
      }
    }
  }

  void _listen() {
    _subscription = supabase.Supabase.instance.client.auth.onAuthStateChange
        .listen(
          _onAuthState,
          onError: (Object error) => AppLog.error(
            'Auth state stream failed',
            error: error,
            name: _name,
          ),
        );
  }

  Future<void> _onAuthState(supabase.AuthState authState) async {
    final supabase.AuthChangeEvent event = authState.event;
    AppLog.debug('Auth event: ${event.name}', name: _name);

    switch (event) {
      case supabase.AuthChangeEvent.passwordRecovery:
        // Handled before the signed-in cases, and it must be: recovery *is* a
        // sign-in as far as Supabase is concerned, so falling through would send
        // the user to Home with a live session and no way to finish the reset.
        state = const AppSession.recoveringPassword();

      case supabase.AuthChangeEvent.signedOut:
        state = const AppSession.signedOut();

      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.initialSession:
      case supabase.AuthChangeEvent.userUpdated:
        if (authState.session == null) {
          state = const AppSession.signedOut();
          return;
        }
        // Mid-recovery, a userUpdated event is the password being changed. The
        // reset screen decides what happens next, so the recovery state is left
        // alone rather than being resolved out from under it.
        if (state.isRecoveringPassword &&
            event == supabase.AuthChangeEvent.userUpdated) {
          return;
        }
        await _loadProfile();

      case supabase.AuthChangeEvent.tokenRefreshed:
        // Nothing to reload: a refresh changes the token, not who the user is.
        // Re-reading the profile on every refresh would be a request every hour
        // for an answer that has not changed.
        break;

      case supabase.AuthChangeEvent.mfaChallengeVerified:
        break;

      // The SDK marks `userDeleted` deprecated and says it was never emitted,
      // but the enum still has it and the switch must be exhaustive. Treated as
      // a sign-out, which is what a deleted account amounts to.
      // ignore: deprecated_member_use
      case supabase.AuthChangeEvent.userDeleted:
        state = const AppSession.signedOut();
    }
  }

  Future<void> _loadProfile() async {
    try {
      state =
          await ref.read(authRepositoryProvider).restoreSession() ??
          const AppSession.signedOut();
    } on Object catch (error) {
      // Signed in, but the profile could not be read. Reported as signed in with
      // nothing provisioned, which routes to onboarding and recovers, rather
      // than as signed out — which would throw away a valid session over a
      // failed read.
      AppLog.warning(
        'Signed in but could not read the profile',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
      state = const AppSession.signedIn(
        isOnboarded: false,
        hasHousehold: false,
      );
    }
  }

  /// Signs the user out.
  ///
  /// State is set from the auth event rather than here, so a sign-out that fails
  /// server-side does not leave the app pretending it succeeded — except with no
  /// backend, where there is no event to wait for.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();

    if (!SupabaseBootstrap.isInitialized) {
      state = const AppSession.signedOut();
    }
  }

  /// Records that onboarding is complete, releasing the onboarding-zone guard.
  ///
  /// Called by Sprint 18 after the answers are saved. The flag is written to
  /// `profiles.onboarding_completed` there; this reflects it locally so the
  /// router moves without waiting for a re-read.
  void completeOnboarding() => state = state.copyWith(isOnboarded: true);

  /// Records that an active household exists.
  void setHasHousehold(bool value) =>
      state = state.copyWith(hasHousehold: value);

  /// Adopts [session] directly.
  ///
  /// For the no-backend case, where the in-memory repository has no event stream
  /// to announce a sign-in, and for tests.
  void adopt(AppSession session) => state = session;

  static const String _name = 'Session';
}
