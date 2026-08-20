import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';

/// Persistence for the onboarding answers.
///
/// [save] is called **after every step**, not once at the end
/// (docs/USER_FLOWS.md §5): "Preferences are persisted per step, not at the end.
/// An abandoned onboarding still leaves the app smarter than a blank one."
///
/// That is why there is one `save` taking the whole accumulated set rather than
/// seven per-field methods. The row is an upsert either way, and a single
/// idempotent write is far easier to reason about than a sequence of partial ones
/// — particularly when a step is revisited by going back.
abstract interface class OnboardingRepository {
  /// The answers already stored, so a resumed run does not start blank.
  Future<OnboardingAnswers> load();

  /// Writes everything answered so far.
  ///
  /// Idempotent: calling it twice with the same answers is one row in the same
  /// state, so a retry after a failed write is safe.
  Future<void> save(OnboardingAnswers answers);

  /// Marks onboarding finished.
  ///
  /// Separate from [save] because it is a different question. Answers can be
  /// written a dozen times; "this user is done" happens once and is what
  /// releases the router's onboarding guard.
  Future<void> complete();
}
