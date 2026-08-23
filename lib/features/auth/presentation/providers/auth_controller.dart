import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/data/timestamped_store.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/domain/repositories/auth_repository.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_repository_provider.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';

part 'auth_controller.g.dart';

/// What a submitted auth form is doing.
///
/// A sealed state rather than a `bool isSubmitting` beside a `String? error`:
/// those are two fields that can disagree, and the disagreement shows up as a
/// spinner spinning over an error message (docs/ARCHITECTURE.md §3.2).
sealed class AuthFormState {
  const AuthFormState();

  bool get isSubmitting => this is AuthSubmitting;

  /// The failure to show, if any.
  AppException? get failure => switch (this) {
    AuthFailed(:final AppException exception) => exception,
    _ => null,
  };
}

/// Nothing has been submitted.
class AuthIdle extends AuthFormState {
  const AuthIdle();
}

/// A submission is in flight.
class AuthSubmitting extends AuthFormState {
  const AuthSubmitting();
}

/// The submission succeeded.
class AuthSucceeded extends AuthFormState {
  const AuthSucceeded();
}

/// The account was created but needs its address confirmed before it works.
///
/// Not a failure and not a success. Nothing went wrong, but there is also no
/// session, so the screen must send the user to their inbox rather than into
/// onboarding — see [EmailConfirmationRequired].
class AuthAwaitingEmailConfirmation extends AuthFormState {
  const AuthAwaitingEmailConfirmation(this.email);

  final String email;
}

/// The submission failed.
class AuthFailed extends AuthFormState {
  const AuthFailed(this.exception, {this.suggestLoginFor});

  final AppException exception;

  /// Set when sign-up hit an already-registered address.
  ///
  /// docs/USER_FLOWS.md §2: that case "offers a one-tap route to login with the
  /// address pre-filled — never a dead-end error", so the screen needs the
  /// address rather than just the message.
  final String? suggestLoginFor;
}

/// Drives the auth forms.
///
/// Holds submission state only. The *session* is owned by [Session]: two places
/// tracking whether someone is signed in is one place too many, and the router's
/// guard reads the session, not this.
@riverpod
class AuthController extends _$AuthController {
  @override
  AuthFormState build() => const AuthIdle();

  Future<void> signIn({required String email, required String password}) {
    return _submit(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthSubmitting();

    try {
      final AppSession session = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, displayName: displayName);

      _adopt(session);
      state = const AuthSucceeded();
    } on EmailConfirmationRequired catch (error) {
      // Deliberately does not adopt a session — there isn't one. Adopting
      // anything here would move the router into the app on an account that
      // cannot read or write a single row.
      state = AuthAwaitingEmailConfirmation(error.email);
    } on EmailAlreadyRegistered catch (error) {
      // Carried through as a distinct state so the screen can offer login with
      // the address filled in, rather than showing a message and stopping.
      state = AuthFailed(
        const ValidationException(
          message: 'That email already has an account',
          field: 'email',
        ),
        suggestLoginFor: error.email,
      );
    } on Object catch (error, stackTrace) {
      state = AuthFailed(_forSignUp(ErrorMapper.map(error, stackTrace)));
    }
  }

  /// Rewords the one message that cannot be true on a sign-up form.
  ///
  /// `ErrorMapper` has no idea which form it is mapping for, so an
  /// `AuthApiException` it cannot place becomes "Those details did not match" —
  /// correct on a sign-in, and nonsense on a sign-up, where there is nothing to
  /// match against. Somebody reading it on the register screen goes looking for a
  /// typo in a password they are inventing.
  ///
  /// Only the catch-all is replaced. A rate limit, an unconfirmed address and an
  /// expired session all carry wording this mapper chose on purpose, and those
  /// have to survive.
  AppException _forSignUp(AppException mapped) {
    if (mapped is! AuthFailureException ||
        mapped.message != ErrorMapper.genericAuthFailure) {
      return mapped;
    }

    return AuthFailureException(
      // Says what to do rather than what went wrong, because at this point the
      // app genuinely does not know which it was — the backend refused and the
      // reason is in `detail`, which only a verbose build shows.
      message:
          'We could not create that account. Check the address, or sign '
          'in if you already have one.',
      detail: mapped.detail,
      code: mapped.code,
      cause: mapped.cause,
      stackTrace: mapped.stackTrace,
    );
  }

  /// Requests a reset email.
  ///
  /// Succeeds whether or not the address exists (docs/USER_FLOWS.md §4). Only a
  /// transport failure surfaces, because only a transport failure is something
  /// the user can act on.
  Future<void> sendPasswordReset({required String email}) async {
    state = const AuthSubmitting();

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
      state = const AuthSucceeded();
    } on Object catch (error, stackTrace) {
      state = AuthFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  Future<void> updatePassword({required String newPassword}) {
    return _submit(
      () => ref
          .read(authRepositoryProvider)
          .updatePassword(newPassword: newPassword),
    );
  }

  /// Signs the user out.
  ///
  /// Routed through here rather than called on the session directly so a screen
  /// gets the same submitting-and-failed states it gets for every other auth
  /// action — a sign-out can fail too.
  Future<void> signOut() async {
    state = const AuthSubmitting();

    try {
      await ref.read(sessionProvider.notifier).signOut();

      // Every cache goes with the session (Sprint 27). The cached meals are
      // public, but the saved and hidden id sets stored beside them are not,
      // and the next person to use this device must not inherit the last one's
      // lists. Swept by key prefix rather than named here, so this does not
      // have to know what any feature caches — or be updated when one starts.
      //
      // After the sign-out rather than before: a sign-out that fails should not
      // also cost a working offline catalogue.
      await TimestampedStore.clearAll();

      state = const AuthSucceeded();
    } on Object catch (error, stackTrace) {
      state = AuthFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Clears a failure so a corrected form starts from a clean state.
  void reset() => state = const AuthIdle();

  Future<void> _submit(Future<AppSession> Function() operation) async {
    state = const AuthSubmitting();

    try {
      _adopt(await operation());
      state = const AuthSucceeded();
    } on Object catch (error, stackTrace) {
      state = AuthFailed(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Publishes [session] as the app's auth truth.
  ///
  /// This is what moves the router: its redirect watches the session, so
  /// assigning it is what navigates away from the auth zone. No screen pushes a
  /// route after signing in (docs/NAVIGATION_MAP.md §4).
  ///
  /// With a backend, Supabase's own event stream has usually published it
  /// already — this makes the no-backend path work and closes the window
  /// between a successful call and the event arriving.
  void _adopt(AppSession session) {
    ref.read(sessionProvider.notifier).adopt(session);
  }
}
