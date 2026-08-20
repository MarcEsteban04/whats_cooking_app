import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:whats_cooking/features/onboarding/domain/repositories/onboarding_repository.dart';

/// [OnboardingRepository] with no backend.
///
/// Used when the build has no Supabase credentials, so a fresh clone can walk the
/// whole flow. It keeps answers for the session and forgets them on restart,
/// which is the honest behaviour for a build with nothing to write to.
class InMemoryOnboardingRepository implements OnboardingRepository {
  OnboardingAnswers _answers = const OnboardingAnswers();
  bool _isComplete = false;

  /// Whether [complete] has been called. Visible for tests.
  bool get isComplete => _isComplete;

  @override
  Future<OnboardingAnswers> load() async {
    await _latency();
    return _answers;
  }

  @override
  Future<void> save(OnboardingAnswers answers) async {
    await _latency();
    _answers = answers;
  }

  @override
  Future<void> complete() async {
    await _latency();
    _isComplete = true;
  }

  /// Short enough not to slow the flow, long enough that a saving indicator is
  /// real rather than theoretical.
  static const Duration latency = Duration(milliseconds: 120);

  static Future<void> _latency() => Future<void>.delayed(latency);
}
