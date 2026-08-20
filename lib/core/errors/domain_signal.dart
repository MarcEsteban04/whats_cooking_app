/// A deliberate, expected outcome that a repository reports by throwing.
///
/// Not a failure. Sign-up against an address that already has an account has not
/// gone wrong — the answer is "sign in instead", and docs/USER_FLOWS.md §2
/// requires the screen to offer exactly that with the address pre-filled. The
/// same is true of an account that needs its email confirmed: nothing broke,
/// there is just one more step.
///
/// The marker exists because `RemoteCall.guard` catches everything a backend
/// call throws and maps it to an `AppException` — which is right for failures
/// and wrong for these. Without it, a signal thrown inside a guarded call
/// arrives at the controller as `UnknownException`, the
/// `on EmailAlreadyRegistered` branch never runs, and the user is told
/// "Something went wrong" for a situation the app knows precisely how to handle.
///
/// That is not hypothetical: it is the bug this file was written to fix, and it
/// had swallowed two separate signals before anyone noticed. The marker also
/// stops a retrying policy from re-sending a request whose answer was never in
/// doubt.
///
/// In `core/` rather than beside the signals themselves, because
/// `RemoteCall.guard` must be able to recognise one without depending on any
/// feature (docs/ARCHITECTURE.md §2.3).
///
/// Implement it on an exception that means "this is what happened", never on one
/// that means "this went wrong". A signal reaches the caller unmapped, so
/// anything the user should never see must not be one.
abstract interface class DomainSignal implements Exception {}
