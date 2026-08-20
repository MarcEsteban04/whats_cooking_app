import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by Supabase Auth.
///
/// Every call goes through [RemoteCall.guard], so a `PostgrestException` or an
/// `AuthException` never escapes this file (docs/ARCHITECTURE.md §4) and the
/// mapping happens exactly once.
///
/// **Nothing here retries.** [RetryPolicy.none] on every method, deliberately:
/// re-sending a rejected password is how an account gets locked, and re-sending
/// a sign-up is how a duplicate account gets made. The one retry the auth flow
/// does want — a silent refresh on an expired session — is Supabase's own job
/// and happens below this layer.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AppSession> signIn({required String email, required String password}) {
    return RemoteCall.guard(
      () async {
        final supabase.AuthResponse response = await _client.auth
            .signInWithPassword(email: email.trim(), password: password);

        return _sessionFor(response.user);
      },
      label: 'signIn',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<AppSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return RemoteCall.guard(
      () async {
        final supabase.AuthResponse response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          // The key the `handle_new_user` trigger reads
          // (supabase/migrations/…_functions_triggers.sql). The profile row,
          // the personal household and the membership are all created there
          // rather than here, so a crash between sign-up and provisioning
          // cannot leave an orphaned account.
          data: <String, dynamic>{'display_name': displayName.trim()},
        );

        final supabase.User? user = response.user;

        // With email confirmation enabled, signing up with an address that
        // already exists returns 200 and a user with **no identities** rather
        // than an error — Supabase's own defence against using sign-up to
        // enumerate accounts. Treating that as success would drop the user into
        // onboarding for an account they cannot access.
        if (user != null && (user.identities?.isEmpty ?? false)) {
          throw EmailAlreadyRegistered(email.trim());
        }

        return _sessionFor(user);
      },
      label: 'signUp',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    return RemoteCall.guard(
      () => _client.auth.resetPasswordForEmail(
        email.trim(),
        // Sends the user back into the app rather than to a web page
        // (docs/NAVIGATION_MAP.md §5).
        redirectTo: AppConstants.passwordResetRedirect,
      ),
      label: 'sendPasswordReset',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<AppSession> updatePassword({required String newPassword}) {
    return RemoteCall.guard(
      () async {
        final supabase.UserResponse response = await _client.auth.updateUser(
          supabase.UserAttributes(password: newPassword),
        );

        return _sessionFor(response.user);
      },
      label: 'updatePassword',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> signOut() {
    return RemoteCall.guard(
      _client.auth.signOut,
      label: 'signOut',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<AppSession?> restoreSession() async {
    // Already read from secure storage by the SDK during initialisation, so this
    // is a local check rather than a request.
    final supabase.User? user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    return RemoteCall.guard(
      () => _sessionFor(user),
      label: 'restoreSession',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  /// Builds the session for [user] from their profile row.
  ///
  /// The two fields the router needs live on `profiles`, not on the auth user,
  /// so this is one extra read per sign-in. Worth it: the alternative is copying
  /// onboarding state into user metadata, where it would be a second source of
  /// truth that can disagree with the table.
  Future<AppSession> _sessionFor(supabase.User? user) async {
    if (user == null) {
      // Reached when a sign-in returns 200 with no user, which should not
      // happen — but silently returning a signed-out session would look like a
      // sign-in that did nothing.
      throw const AuthFailureException(
        message: 'Those details did not match',
        detail: 'auth returned no user',
      );
    }

    final Map<String, dynamic>? profile = await _client
        .from(_profilesTable)
        .select('$_onboardingColumn, $_householdColumn')
        .eq('id', user.id)
        .maybeSingle();

    // A missing row means the provisioning trigger has not been observed yet —
    // possible in the moment right after sign-up. Reported as "not onboarded,
    // no household", which routes to onboarding and resolves itself, rather
    // than as an error the user would have to act on.
    if (profile == null) {
      return const AppSession.signedIn(isOnboarded: false, hasHousehold: false);
    }

    return AppSession.signedIn(
      isOnboarded: profile[_onboardingColumn] as bool? ?? false,
      hasHousehold: profile[_householdColumn] != null,
    );
  }

  static const String _profilesTable = 'profiles';
  static const String _onboardingColumn = 'onboarding_completed';
  static const String _householdColumn = 'active_household_id';
}
