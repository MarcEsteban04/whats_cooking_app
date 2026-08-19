import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/domain/repositories/auth_repository.dart';

/// A stand-in [AuthRepository] that keeps accounts in memory.
///
/// **Sprint 16 only.** Sprint 17 replaces it with a Supabase-backed
/// implementation; this exists so the screens can be built, reviewed and tested
/// as a working flow first. Its job is to behave *correctly* — same errors, same
/// enumeration defences — not to persist anything.
///
/// It is deliberately not a mock. The screens' error handling is only worth
/// anything if it is exercised, so this rejects a wrong password, reports a
/// duplicate address, and stays silent about whether an address exists.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository();

  final Map<String, _Account> _accounts = <String, _Account>{};

  @override
  Future<AppSession> signIn({
    required String email,
    required String password,
  }) async {
    await _simulateLatency();

    final _Account? account = _accounts[_normalise(email)];

    // One error for both "no such account" and "wrong password". §3:
    // "A failed login never states which field was wrong."
    if (account == null || account.password != password) {
      throw const AuthFailureException(message: 'Those details did not match');
    }

    return AppSession.signedIn(
      isOnboarded: account.isOnboarded,
      hasHousehold: true,
    );
  }

  @override
  Future<AppSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _simulateLatency();

    final String key = _normalise(email);
    if (_accounts.containsKey(key)) {
      throw EmailAlreadyRegistered(email);
    }

    _accounts[key] = _Account(password: password, displayName: displayName);

    // Not onboarded: a new account goes to onboarding, which is what the router
    // guard will do with this (docs/USER_FLOWS.md §2).
    return const AppSession.signedIn(isOnboarded: false, hasHousehold: true);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _simulateLatency();

    // Completes either way. §4: "The confirmation screen says the same thing
    // whether or not the address exists — again, enumeration defence." Logged at
    // debug so a developer can still see what happened locally.
    AppLog.debug(
      'Password reset requested',
      name: _name,
      data: <String, Object?>{
        'exists': _accounts.containsKey(_normalise(email)),
      },
    );
  }

  @override
  Future<AppSession> updatePassword({required String newPassword}) async {
    await _simulateLatency();

    // No account is addressable without the reset token Sprint 17 will carry, so
    // this reports success and signs the user in, which is the flow §4 describes.
    return const AppSession.signedIn(isOnboarded: false, hasHousehold: true);
  }

  @override
  Future<void> signOut() async {
    await _simulateLatency();
  }

  @override
  Future<AppSession?> restoreSession() async => null;

  /// Enough delay for a loading state to be visible and tested.
  ///
  /// Without it every submission resolves within a frame, and a spinner that
  /// never appears is a spinner nobody notices is broken.
  static Future<void> _simulateLatency() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  static String _normalise(String email) => email.trim().toLowerCase();

  static const String _name = 'InMemoryAuthRepository';
}

class _Account {
  const _Account({required this.password, required this.displayName});

  final String password;
  final String displayName;
  bool get isOnboarded => false;
}
