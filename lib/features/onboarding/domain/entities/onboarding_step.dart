/// The onboarding questions, in order (docs/USER_FLOWS.md §5).
///
/// Seven, matching the flow diagram and the "Step 3 of 7" counter in
/// docs/COMPONENTS.md §18b. (§5's prose says "six short steps" while its own
/// diagram draws seven; the diagram and the component spec agree, so seven it
/// is.)
///
/// An enum rather than an integer index, so the paging cannot drift out of step
/// with the questions and a new question cannot be added without deciding where
/// it sits.
enum OnboardingStep {
  name(
    title: 'What should we call you?',
    subtitle: 'So the app can say hello.',
  ),

  cuisines(
    title: 'What do you love to eat?',
    subtitle: 'Pick as many as you like. We will lean towards these.',
  ),

  dislikes(
    title: 'Anything you avoid?',
    subtitle:
        'The one thing worth telling us. We will never suggest these again.',
  ),

  dietary(
    title: 'Any dietary needs?',
    subtitle: 'These are hard rules for us, not suggestions.',
  ),

  budget(
    title: 'What is a normal spend?',
    subtitle: 'Per meal. You can change it any time.',
  ),

  cookingTime(
    title: 'How long do you have?',
    subtitle: 'On a normal weeknight.',
  ),

  cookingFor(
    title: 'Who are you cooking for?',
    subtitle: 'This is the one that makes couple mode work.',
  );

  const OnboardingStep({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  /// 1-based position, for the "Step 3 of 7" counter.
  int get number => index + 1;

  /// Total steps, for the same counter.
  static int get count => OnboardingStep.values.length;

  /// Progress *after* this step is answered, from 0 to 1.
  ///
  /// Used by the bar, and the reason the closing screen reads 1.0: the bar
  /// reaching 100% is what makes "you are finished" and the bar agree.
  double get progress => number / count;

  bool get isFirst => index == 0;
  bool get isLast => index == count - 1;

  OnboardingStep? get previous =>
      isFirst ? null : OnboardingStep.values[index - 1];

  OnboardingStep? get next => isLast ? null : OnboardingStep.values[index + 1];
}
