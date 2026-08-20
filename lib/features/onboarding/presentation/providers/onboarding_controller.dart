import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/onboarding/data/repositories/in_memory_onboarding_repository.dart';
import 'package:whats_cooking/features/onboarding/data/repositories/supabase_onboarding_repository.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_step.dart';
import 'package:whats_cooking/features/onboarding/domain/repositories/onboarding_repository.dart';

part 'onboarding_controller.g.dart';

/// Where onboarding answers are written.
@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    return InMemoryOnboardingRepository();
  }
  return SupabaseOnboardingRepository(ref.read(supabaseClientProvider));
}

/// The onboarding flow's state.
///
/// One route with internal paging (docs/NAVIGATION_MAP.md §2), so this holds the
/// current step rather than the router doing it: "a mid-flow back gesture cannot
/// strand the user between partially-saved steps".
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.name,
    this.answers = const OnboardingAnswers(),
    this.isLoading = true,
    this.isSaving = false,
    this.isFinished = false,
    this.failure,
  });

  final OnboardingStep step;
  final OnboardingAnswers answers;

  /// Loading the answers already stored, so a resumed run does not start blank.
  final bool isLoading;

  /// A per-step save is in flight.
  final bool isSaving;

  /// The closing screen — the "first spin invitation" §5 ends on.
  final bool isFinished;

  /// The last save failure, if any.
  ///
  /// Shown without blocking: an answer that failed to save is worth mentioning,
  /// but stopping the flow over it would cost the user the whole run.
  final AppException? failure;

  /// Progress for the bar. 1.0 once finished, which is what makes the bar and
  /// "you are done" agree (docs/COMPONENTS.md §18b).
  double get progress => isFinished ? 1 : step.progress;

  /// The counter beneath the bar.
  String get progressLabel => isFinished
      ? 'All done'
      : 'Step ${step.number} of ${OnboardingStep.count}';

  OnboardingState copyWith({
    OnboardingStep? step,
    OnboardingAnswers? answers,
    bool? isLoading,
    bool? isSaving,
    bool? isFinished,
    AppException? failure,
    bool clearFailure = false,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      answers: answers ?? this.answers,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isFinished: isFinished ?? this.isFinished,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Drives onboarding.
///
/// The rule that shapes it: **answers are persisted per step, not at the end**
/// (docs/USER_FLOWS.md §5). Every advance writes, so "an abandoned onboarding
/// still leaves the app smarter than a blank one" is true of every step rather
/// than only of a completed run.
/// Kept alive, which is a deliberate exception to the `autoDispose` default
/// (docs/CODING_STANDARDS.md §11).
///
/// The flow leaves its own screen mid-run: §5's household branch navigates to
/// `/couple/setup` and back. With `autoDispose`, nothing watches the controller
/// while that screen is up, so returning would restart onboarding at question
/// one — after the user had answered six.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() {
    _load();
    return const OnboardingState();
  }

  Future<void> _load() async {
    try {
      final OnboardingAnswers stored = await ref
          .read(onboardingRepositoryProvider)
          .load();

      // Only adopted if the user has not started answering. The load is a
      // request, and someone can type a name before it returns — overwriting
      // that with the stored (probably empty) answers loses input they watched
      // themselves enter, which is the worst kind of data loss.
      state = state.copyWith(
        answers: state.answers.hasAnyAnswer ? state.answers : stored,
        isLoading: false,
      );
    } on Object catch (error, stackTrace) {
      // A failed load starts the flow blank rather than blocking it. The answers
      // are a nicety on the way in; being unable to onboard at all is not.
      AppLog.warning(
        'Could not load stored onboarding answers; starting fresh',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
      AppLog.debug('Onboarding load failed', name: _name, data: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }

  /// Records [answers] without advancing.
  ///
  /// For live edits within a step — typing a name, toggling a chip — which should
  /// not write on every keystroke.
  void update(OnboardingAnswers answers) {
    state = state.copyWith(answers: answers, clearFailure: true);
  }

  /// Saves and moves to the next step, or finishes.
  ///
  /// Called by both "Continue" and "Skip": skipping still writes, because the
  /// answers behind it are worth keeping and because a skipped step may have
  /// cleared a previous answer.
  Future<void> advance() async {
    await _persist();

    final OnboardingStep? next = state.step.next;
    if (next == null) {
      await _finish();
      return;
    }
    state = state.copyWith(step: next);
  }

  /// Goes back one step.
  ///
  /// docs/NAVIGATION_MAP.md §7: "Back to previous step; already-saved answers
  /// persist." Nothing is written on the way back — the answers are already
  /// stored, and re-writing them would turn a navigation into a request.
  void back() {
    final OnboardingStep? previous = state.step.previous;
    if (previous == null) {
      return;
    }
    state = state.copyWith(step: previous, clearFailure: true);
  }

  /// Skips the rest of the flow.
  ///
  /// §5: "Every step is skippable, and skipping is visible — not hidden behind a
  /// back gesture. Impatience must not cost us the user." So this exists, it is
  /// reachable from every step, and it still writes what was answered.
  Future<void> skipAll() async {
    await _persist();
    await _finish();
  }

  /// Leaves onboarding for Home.
  ///
  /// The flow "ends by pointing at the spin" (§5), so the closing screen's action
  /// lands there — this only releases the guard.
  Future<void> finishAndContinue() async {
    if (!state.isFinished) {
      await _persist();
      await _finish();
    }
  }

  Future<void> _persist() async {
    state = state.copyWith(isSaving: true, clearFailure: true);

    try {
      await ref.read(onboardingRepositoryProvider).save(state.answers);
      state = state.copyWith(isSaving: false);
    } on Object catch (error, stackTrace) {
      // Recorded, not blocking. Losing one step's write is a smaller cost than
      // trapping someone on a question they already answered.
      final AppException mapped = ErrorMapper.map(error, stackTrace);
      AppLog.warning(
        'Could not save onboarding answers',
        name: _name,
        data: <String, Object?>{'code': mapped.code},
      );
      state = state.copyWith(isSaving: false, failure: mapped);
    }
  }

  Future<void> _finish() async {
    try {
      await ref.read(onboardingRepositoryProvider).complete();
    } on Object catch (error, stackTrace) {
      // Deliberately swallowed for the *local* release below. If the flag did
      // not persist, the user sees onboarding again next launch — annoying, and
      // far better than being stuck on the closing screen with no way into the
      // app.
      AppLog.warning(
        'Could not mark onboarding complete',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
      AppLog.debug('Complete failed', name: _name, data: stackTrace);
    }

    // Releases the router's onboarding guard. Set regardless of whether the write
    // landed, for the reason above.
    ref.read(sessionProvider.notifier).completeOnboarding();
    state = state.copyWith(isFinished: true, isSaving: false);
  }

  static const String _name = 'OnboardingController';
}
