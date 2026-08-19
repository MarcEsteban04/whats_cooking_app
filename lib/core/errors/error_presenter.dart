import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';

/// The one place a failure becomes something a person reads.
///
/// docs/design_ui.md §31: "Never expose technical errors to normal users."
/// Keeping the translation here — rather than letting each screen decide —
/// means a screen cannot accidentally render [AppException.detail], because it
/// never has to touch it.
extension AppExceptionPresentation on AppException {
  /// Which [ErrorState] copy this failure should use.
  ///
  /// The mapping is exhaustive over the sealed hierarchy, so a new exception kind
  /// will not compile until someone decides what the user should be told.
  ErrorStateKind get errorStateKind => switch (this) {
    NetworkException() => ErrorStateKind.network,
    ServerException() => ErrorStateKind.server,
    NotFoundException() => ErrorStateKind.notFound,
    PermissionException() => ErrorStateKind.permission,
    // An auth failure is shown as a server error only when it reaches a full
    // error state at all — normally the router has already redirected to sign-in
    // (docs/ARCHITECTURE.md §7), so arriving here means something unexpected.
    AuthFailureException() => ErrorStateKind.server,
    ValidationException() => ErrorStateKind.server,
    UnknownException() => ErrorStateKind.unknown,
  };

  /// A message safe to display, or null to use the kind's standard copy.
  ///
  /// Only [ValidationException] overrides it: its message is written at the
  /// throw site and is more specific than anything generic
  /// ("Enter a budget above zero"). Everything else falls back to the copy
  /// tables in docs/COMPONENTS.md §13, which were written for a person.
  String? get displayMessage => this is ValidationException ? message : null;

  /// The support code to show beneath the action, if any.
  ///
  /// docs/COMPONENTS.md §13: "An error code may appear in `bodySmall` on
  /// `textDisabled` **beneath** the action, for support purposes only — never in
  /// the primary message."
  String? get supportCode => code;

  /// Whether to offer a retry.
  ///
  /// Offering "Try Again" for a permission failure invites someone to hammer a
  /// button that cannot ever work.
  bool get shouldOfferRetry => isRetryable;
}
