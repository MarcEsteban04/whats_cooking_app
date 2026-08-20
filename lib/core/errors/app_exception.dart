/// The exception hierarchy from docs/ARCHITECTURE.md §9.
///
/// Repositories **throw** these; they do not return `Result<T>`
/// (docs/CODING_STANDARDS.md §11). `AsyncValue` already models failure as a
/// first-class state, so a `Result` wrapper would be unwrapped and immediately
/// re-wrapped at every call site.
///
/// Every exception carries two messages, and the distinction is the whole point:
///
/// * [message] is written for a person and may be displayed.
/// * [detail] is technical, is logged, and is **never** displayed
///   (docs/design_ui.md §31).
///
/// Sealed, so a `switch` over a failure is exhaustive and adding a new kind
/// forces every consumer to decide what it means.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.detail,
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// A message written for a person. Safe to display.
  final String message;

  /// Technical context. Logged, never displayed.
  final String? detail;

  /// A support code, e.g. a Postgres error code. May be shown *beneath* an
  /// action for support purposes (docs/COMPONENTS.md §13), never in the message.
  final String? code;

  /// The exception this was mapped from.
  final Object? cause;

  final StackTrace? stackTrace;

  /// Whether retrying the same operation could plausibly succeed.
  ///
  /// Drives both the retry policy and whether a UI offers "Try Again": offering
  /// a retry for a permission failure invites someone to hammer a button that
  /// cannot work.
  bool get isRetryable => false;

  @override
  String toString() {
    final String suffix = detail == null ? '' : ' — $detail';
    return '$runtimeType: $message$suffix';
  }
}

/// No connectivity, or a request that timed out.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No connection',
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  bool get isRetryable => true;
}

/// A 5xx, or an unexpected backend failure.
class ServerException extends AppException {
  const ServerException({
    super.message = 'Something went wrong',
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  bool get isRetryable => true;
}

/// Invalid credentials, or an expired session.
class AuthFailureException extends AppException {
  const AuthFailureException({
    super.message = 'Please sign in again',
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
    this.isSessionExpired = false,
  });

  /// Whether this was an expired session rather than a rejected credential.
  ///
  /// An expired session gets one silent refresh-and-retry before the user sees
  /// anything (docs/ARCHITECTURE.md §7); a wrong password must not be retried,
  /// because retrying it just locks the account faster.
  final bool isSessionExpired;

  @override
  bool get isRetryable => isSessionExpired;
}

/// An RLS denial, or an attempt to reach another household's data.
class PermissionException extends AppException {
  const PermissionException({
    super.message = "You don't have access",
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// The resource is not there.
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = "We couldn't find that",
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// A client-side rule was broken.
///
/// The one kind whose [message] is usually written at the throw site, because
/// "Enter a budget above zero" is more useful than any generic wording.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
    this.field,
  });

  /// The offending field, so a form can attach the message to the right input.
  final String? field;
}

/// The escape hatch. Always logged (docs/ARCHITECTURE.md §9).
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'Something went wrong',
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Too many attempts in too short a window.
///
/// Its own type because docs/USER_FLOWS.md §3 gives it its own path and its own
/// copy: "Too many attempts | Rate-limit message with wait time". Folded into
/// [AuthFailureException] it would tell someone their details were wrong when
/// they were not, and send them to change a password that is perfectly correct.
///
/// Deliberately **not** retryable. A rate limit is the one failure where an
/// automatic retry is precisely the wrong response: it extends the lockout.
class RateLimitException extends AppException {
  const RateLimitException({
    super.message = 'Too many attempts',
    super.detail,
    super.code,
    super.cause,
    super.stackTrace,
    this.retryAfter,
  });

  /// How long to wait, when the backend says how long.
  final Duration? retryAfter;
}
