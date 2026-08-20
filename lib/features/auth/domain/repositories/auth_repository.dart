import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';

/// What the auth feature needs from a backend.
///
/// Speaks only in entities and plain values (docs/ARCHITECTURE.md §4), so the
/// screens in Sprint 16 are written against this and Sprint 17 swaps the
/// implementation underneath with a one-line provider override.
///
/// Every method **throws** an `AppException` on failure rather than returning a
/// result (docs/CODING_STANDARDS.md §11); the mapping happens once, in the data
/// layer.
abstract interface class AuthRepository {
  /// Signs in with email and password.
  ///
  /// Throws `AuthFailureException` when the credentials are rejected. It must not
  /// say *which* field was wrong: docs/USER_FLOWS.md §3 calls that out as
  /// credential-enumeration defence.
  Future<AppSession> signIn({required String email, required String password});

  /// Creates an account.
  ///
  /// The profile row is created by a database trigger on `auth.users`, not here
  /// (docs/USER_FLOWS.md §2), so a crash between sign-up and profile creation
  /// cannot leave an orphaned account.
  ///
  /// Throws `ValidationException` when the address is already registered, so the
  /// screen can offer a one-tap route to login rather than a dead end.
  Future<AppSession> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Sends a password-reset email.
  ///
  /// Completes identically whether or not the address exists
  /// (docs/USER_FLOWS.md §4) — the confirmation screen must not become an
  /// account-existence oracle.
  Future<void> sendPasswordReset({required String email});

  /// Sets a new password for the session established by a reset deep link.
  Future<AppSession> updatePassword({required String newPassword});

  Future<void> signOut();

  /// The session restored from secure storage, or null.
  Future<AppSession?> restoreSession();
}

/// Thrown by [AuthRepository.signUp] when the address already has an account.
///
/// A distinct type rather than a message match, so the screen can react to it —
/// offering login with the address pre-filled — without string-sniffing an error.
class EmailAlreadyRegistered implements Exception {
  const EmailAlreadyRegistered(this.email);

  final String email;
}

/// Thrown by [AuthRepository.signUp] when the account was created but cannot be
/// used until the address is confirmed.
///
/// This is the Supabase default: with **Confirm email** on, sign-up returns a
/// user and *no session*. Reporting that as a successful sign-in is the worst
/// available outcome — the app would drop someone into onboarding holding no
/// access token, every write would be refused by Row Level Security, and the
/// account would appear broken on the next launch rather than merely unconfirmed.
///
/// A distinct type, like [EmailAlreadyRegistered], so the screen can say what
/// actually happened instead of string-matching an error.
class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired(this.email);

  final String email;
}
