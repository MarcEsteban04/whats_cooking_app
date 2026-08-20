/// What the router needs to know about the current user.
///
/// Deliberately the *smallest* thing that answers docs/NAVIGATION_MAP.md §4's
/// questions — is there a session, is onboarding complete, is there a household,
/// and is this a password reset in progress — and nothing else. The router should
/// not be able to reach a profile, a token or a preference, because none of those
/// decide a redirect.
library;

/// Whether a session exists, or is not yet known.
enum SessionStatus {
  /// Still restoring from secure storage.
  ///
  /// A distinct state rather than "not authenticated yet" on purpose: treating
  /// an unrestored session as signed out flashes the welcome screen on every
  /// cold start, which is the single most common bug in this area.
  restoring,

  /// No session. The public zone.
  unauthenticated,

  /// A valid session.
  authenticated,
}

/// An immutable snapshot of session state.
class AppSession {
  const AppSession({
    required this.status,
    this.isOnboarded = false,
    this.hasHousehold = false,
    this.isRecoveringPassword = false,
  });

  /// The starting state on a cold launch.
  const AppSession.restoring()
    : status = SessionStatus.restoring,
      isOnboarded = false,
      hasHousehold = false,
      isRecoveringPassword = false;

  /// No session.
  const AppSession.signedOut()
    : status = SessionStatus.unauthenticated,
      isOnboarded = false,
      hasHousehold = false,
      isRecoveringPassword = false;

  /// A signed-in user.
  const AppSession.signedIn({
    required this.isOnboarded,
    required this.hasHousehold,
  }) : status = SessionStatus.authenticated,
       isRecoveringPassword = false;

  /// A session established by following a password-reset link.
  ///
  /// A real and easily-missed state. Supabase's recovery flow signs the user
  /// **in** before they choose a new password, so without distinguishing it the
  /// router sees an authenticated user and sends them to Home — stranding them
  /// with a live session and no way to finish the reset they started.
  ///
  /// Onboarding and household are reported as satisfied because neither is
  /// relevant while recovering: the only screen this session may reach is the
  /// new-password form, and claiming otherwise would bounce it through the
  /// onboarding guard on the way there.
  const AppSession.recoveringPassword()
    : status = SessionStatus.authenticated,
      isOnboarded = true,
      hasHousehold = true,
      isRecoveringPassword = true;

  final SessionStatus status;

  /// Whether the onboarding questions have been answered.
  ///
  /// Read from `profiles.onboarding_completed`.
  final bool isOnboarded;

  /// Whether an active household exists.
  ///
  /// Every user gets a personal household on signup by database trigger
  /// (docs/ARCHITECTURE.md §6.2), so in practice this is false only in the
  /// moment between the account existing and that trigger's work being observed.
  final bool hasHousehold;

  /// Whether this session exists only to complete a password reset.
  final bool isRecoveringPassword;

  bool get isRestoring => status == SessionStatus.restoring;
  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isUnauthenticated => status == SessionStatus.unauthenticated;

  AppSession copyWith({
    SessionStatus? status,
    bool? isOnboarded,
    bool? hasHousehold,
    bool? isRecoveringPassword,
  }) {
    return AppSession(
      status: status ?? this.status,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      hasHousehold: hasHousehold ?? this.hasHousehold,
      isRecoveringPassword: isRecoveringPassword ?? this.isRecoveringPassword,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSession &&
        other.status == status &&
        other.isOnboarded == isOnboarded &&
        other.hasHousehold == hasHousehold &&
        other.isRecoveringPassword == isRecoveringPassword;
  }

  @override
  int get hashCode =>
      Object.hash(status, isOnboarded, hasHousehold, isRecoveringPassword);

  @override
  String toString() =>
      'AppSession(${status.name}, onboarded: $isOnboarded, '
      'household: $hasHousehold, recovering: $isRecoveringPassword)';
}
