import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/brand_logo.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/preferences/preference_editors.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_step.dart';
import 'package:whats_cooking/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:whats_cooking/features/onboarding/presentation/widgets/onboarding_progress.dart';

/// Onboarding: one route, seven questions, internal paging.
///
/// docs/NAVIGATION_MAP.md §2 requires the single route — "so a mid-flow back
/// gesture cannot strand the user between partially-saved steps" — which is why
/// the step lives in the controller rather than in the URL.
///
/// The visual language follows the auth screens: centred headline, centred
/// subtitle, near-black pill CTA. Onboarding is the other half of the same
/// threshold, and it should not feel like a different app from the sign-up that
/// preceded it by one tap.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  bool _hasSeededName = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  void _updateAnswers(OnboardingAnswers answers) => _controller.update(answers);

  @override
  Widget build(BuildContext context) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);

    // Seeded once, after the stored answers arrive. The signup trigger already
    // derived a name from the email address, so the field starts with something
    // rather than asking a question the app can partly answer itself.
    if (!state.isLoading && !_hasSeededName) {
      _hasSeededName = true;
      _name.text = state.answers.displayName ?? '';
    }

    if (state.isLoading) {
      return const _OnboardingLoading();
    }

    if (state.isFinished) {
      return _FirstSpinInvitation(
        progress: state.progress,
        progressLabel: state.progressLabel,
        onStart: () => context.goNamed(AppRoute.home.routeName),
      );
    }

    return _OnboardingStepView(
      state: state,
      nameController: _name,
      onAnswersChanged: _updateAnswers,
      onBack: _controller.back,
      onContinue: _controller.advance,
      onSkipAll: _controller.skipAll,
      onHouseholdSetup: () =>
          context.goNamed(AppRoute.householdSetup.routeName),
    );
  }
}

class _OnboardingLoading extends StatelessWidget {
  const _OnboardingLoading();

  @override
  Widget build(BuildContext context) {
    // A blank ground rather than a spinner: the read is local-ish and usually
    // finishes within a frame or two, and a spinner that flashes for 80 ms reads
    // as jank rather than as progress (docs/design_ui.md §30).
    return Scaffold(backgroundColor: context.colors.background);
  }
}

class _OnboardingStepView extends StatelessWidget {
  const _OnboardingStepView({
    required this.state,
    required this.nameController,
    required this.onAnswersChanged,
    required this.onBack,
    required this.onContinue,
    required this.onSkipAll,
    required this.onHouseholdSetup,
  });

  final OnboardingState state;
  final TextEditingController nameController;
  final ValueChanged<OnboardingAnswers> onAnswersChanged;
  final VoidCallback onBack;
  final Future<void> Function() onContinue;
  final Future<void> Function() onSkipAll;
  final VoidCallback onHouseholdSetup;

  OnboardingStep get step => state.step;
  OnboardingAnswers get answers => state.answers;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppException? failure = state.failure;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.screenMargin,
                    vertical: AppSpacing.space4,
                  ),
                  child: Column(
                    children: <Widget>[
                      _TopBar(
                        canGoBack: !step.isFirst,
                        onBack: onBack,
                        onSkipAll: onSkipAll,
                        isBusy: state.isSaving,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      OnboardingProgress(
                        progress: state.progress,
                        label: state.progressLabel,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.screenMargin,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.space6),
                        Text(
                          step.title,
                          style: context.text.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        Text(
                          step.subtitle,
                          style: context.text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.space7),
                        if (failure != null) ...<Widget>[
                          // Non-blocking: the answer is held in memory and will
                          // be written again on the next advance, so the flow
                          // continues rather than stopping on a failed save.
                          const InlineErrorBanner(
                            message:
                                "We couldn't save that just yet. We'll try "
                                'again as you go.',
                          ),
                          const SizedBox(height: AppSpacing.space4),
                        ],
                        _StepBody(
                          step: step,
                          answers: answers,
                          nameController: nameController,
                          onAnswersChanged: onAnswersChanged,
                          onHouseholdSetup: onHouseholdSetup,
                        ),
                        const SizedBox(height: AppSpacing.space7),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.screenMargin,
                    vertical: AppSpacing.space5,
                  ),
                  child: AppButton.inverse(
                    label: step.isLast ? 'Finish' : 'Continue',
                    isLoading: state.isSaving,
                    onPressed: onContinue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back on the left, "Skip all" on the right.
///
/// docs/USER_FLOWS.md §5: "Every step is skippable, and skipping is **visible** —
/// not hidden behind a back gesture. Impatience must not cost us the user." So
/// the skip is a labelled control on every step, not a gesture to discover.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.canGoBack,
    required this.onBack,
    required this.onSkipAll,
    required this.isBusy,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final Future<void> Function() onSkipAll;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppLayout.minTouchTarget,
      child: Row(
        children: <Widget>[
          if (canGoBack)
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                boxShadow: context.shadows.xs,
              ),
              child: AppIconButton(
                icon: AppIcons.back,
                semanticLabel: 'Back to the previous question',
                iconSize: AppIconSize.sm,
                onPressed: isBusy ? null : onBack,
              ),
            ),
          const Spacer(),
          AppButton.tertiary(
            label: 'Skip all',
            size: AppButtonSize.small,
            onPressed: isBusy ? null : onSkipAll,
          ),
        ],
      ),
    );
  }
}

/// The body for the current question.
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.answers,
    required this.nameController,
    required this.onAnswersChanged,
    required this.onHouseholdSetup,
  });

  final OnboardingStep step;
  final OnboardingAnswers answers;
  final TextEditingController nameController;
  final ValueChanged<OnboardingAnswers> onAnswersChanged;
  final VoidCallback onHouseholdSetup;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      OnboardingStep.name => AppTextField(
        controller: nameController,
        label: 'Your name',
        hint: 'Marc',
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        // No validator: the step is skippable, and a required-field error on a
        // question nobody has to answer is exactly the friction §5 warns costs
        // you the user.
        onChanged: (String value) =>
            onAnswersChanged(answers.copyWith(displayName: value)),
      ),

      OnboardingStep.cuisines => CuisinePicker(
        selected: answers.preferences.favouriteCuisines,
        onChanged: (Set<Cuisine> selected) => onAnswersChanged(
          answers.withPreferences(favouriteCuisines: selected),
        ),
      ),

      OnboardingStep.dislikes => DislikesEditor(
        foods: answers.preferences.dislikedFoods,
        onChanged: (List<String> foods) =>
            onAnswersChanged(answers.withPreferences(dislikedFoods: foods)),
      ),

      OnboardingStep.dietary => DietaryPicker(
        selected: answers.preferences.dietaryTags,
        onChanged: (Set<DietaryTag> tags) =>
            onAnswersChanged(answers.withPreferences(dietaryTags: tags)),
      ),

      OnboardingStep.budget => BudgetPicker(
        budget: answers.preferences.budget,
        onChanged: (int? budget) => onAnswersChanged(
          budget == null
              ? answers.withPreferences(clearBudget: true)
              : answers.withPreferences(budget: budget),
        ),
      ),

      OnboardingStep.cookingTime => CookingTimePicker(
        minutes: answers.preferences.maxCookingTimeMinutes,
        onChanged: (int? minutes) => onAnswersChanged(
          minutes == null
              ? answers.withPreferences(clearMaxCookingTime: true)
              : answers.withPreferences(maxCookingTimeMinutes: minutes),
        ),
      ),

      OnboardingStep.cookingFor => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CookingForPicker(
            selected: answers.preferences.cookingFor,
            onChanged: (CookingFor choice) =>
                onAnswersChanged(answers.withPreferences(cookingFor: choice)),
          ),
          if (answers.invitesHousehold) ...<Widget>[
            const SizedBox(height: AppSpacing.space5),
            // §5 puts the household prompt here because it is "the
            // highest-intent moment for couple mode — the user is already
            // thinking about who they cook with". Offered, never forced: the
            // Continue button still finishes onboarding without it.
            _HouseholdInvitation(onSetUp: onHouseholdSetup),
          ],
        ],
      ),
    };
  }
}

/// The optional household branch.
class _HouseholdInvitation extends StatelessWidget {
  const _HouseholdInvitation({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: AppRadius.borderLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cook together?',
              style: context.text.titleSmall.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              'Share a kitchen and we will find meals you both want. You can '
              'always do this later.',
              style: context.text.bodySmall.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            AppButton.secondary(
              label: 'Set up our kitchen',
              size: AppButtonSize.small,
              onPressed: onSetUp,
            ),
          ],
        ),
      ),
    );
  }
}

/// The closing screen (docs/USER_FLOWS.md §5).
///
/// "The flow ends by pointing at the spin. Onboarding's job is to deliver the
/// user to their first decision, not to collect data." So the only action here is
/// the spin, and the bar reads 100% — docs/COMPONENTS.md §18b: "Telling someone
/// they are finished underneath a partial bar is a contradiction, and it is
/// asserted in test."
class _FirstSpinInvitation extends StatelessWidget {
  const _FirstSpinInvitation({
    required this.progress,
    required this.progressLabel,
    required this.onStart,
  });

  final double progress;
  final String progressLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.screenMargin,
                vertical: AppSpacing.space5,
              ),
              child: Column(
                children: <Widget>[
                  OnboardingProgress(progress: progress, label: progressLabel),
                  const Spacer(),
                  // The mark, not a glyph: this is the moment the app stops
                  // asking questions and starts being the product, which is the
                  // second and last place the full-colour logo belongs.
                  const BrandLogo(height: _markSize),
                  const SizedBox(height: AppSpacing.space6),
                  Text(
                    'That is all we need',
                    style: context.text.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
                    child: Text(
                      'Let us pick tonight. You can change any of this later.',
                      style: context.text.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  AppButton.inverse(
                    label: "What's Cooking?",
                    onPressed: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Big enough for a wordmark to read. The glyph this replaced worked at 64.
  static const double _markSize = 96;
  static const double _bodyMaxWidth = 280;
}
