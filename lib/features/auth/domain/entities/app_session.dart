/// What the router needs to know about the current user.
///
/// Deliberately the *smallest* thing that answers docs/NAVIGATION_MAP.md §4's
/// three questions — is there a session, is onboarding complete, is there a
/// household — and nothing else. The router should not be able to reach a
/// profile, a token or a preference, because none of those decide a redirect.
///
/// Sprint 17 replaces the provider that supplies this with one backed by
/// Supabase auth; the shape here is what it must produce, and the guard tests
/// are written against this rather than against Supabase.
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
  });

  /// The starting state on a cold launch.
  const AppSession.restoring()
    : status = SessionStatus.restoring,
      isOnboarded = false,
      hasHousehold = false;

  /// No session.
  const AppSession.signedOut()
    : status = SessionStatus.unauthenticated,
      isOnboarded = false,
      hasHousehold = false;

  /// A signed-in user.
  const AppSession.signedIn({
    required this.isOnboarded,
    required this.hasHousehold,
  }) : status = SessionStatus.authenticated;

  final SessionStatus status;

  /// Whether the onboarding questions have been answered.
  final bool isOnboarded;

  /// Whether an active household exists.
  ///
  /// Every user gets a personal household on signup by database trigger
  /// (docs/ARCHITECTURE.md §6.2), so in practice this is false only while that
  /// provisioning has not been observed yet.
  final bool hasHousehold;

  bool get isRestoring => status == SessionStatus.restoring;
  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isUnauthenticated => status == SessionStatus.unauthenticated;

  AppSession copyWith({
    SessionStatus? status,
    bool? isOnboarded,
    bool? hasHousehold,
  }) {
    return AppSession(
      status: status ?? this.status,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      hasHousehold: hasHousehold ?? this.hasHousehold,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSession &&
        other.status == status &&
        other.isOnboarded == isOnboarded &&
        other.hasHousehold == hasHousehold;
  }

  @override
  int get hashCode => Object.hash(status, isOnboarded, hasHousehold);

  @override
  String toString() =>
      'AppSession(${status.name}, onboarded: $isOnboarded, '
      'household: $hasHousehold)';
}
