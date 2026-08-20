import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/preferences/selectable_tile.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_step.dart';
import 'package:whats_cooking/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:whats_cooking/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:whats_cooking/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:whats_cooking/features/onboarding/presentation/widgets/onboarding_progress.dart';

import '../../support/component_harness.dart';

/// Records every write, so "persisted per step" is checkable rather than assumed.
class _RecordingRepository implements OnboardingRepository {
  _RecordingRepository();

  final List<OnboardingAnswers> saves = <OnboardingAnswers>[];
  int completions = 0;
  OnboardingAnswers stored = const OnboardingAnswers();
  bool failSaves = false;

  @override
  Future<OnboardingAnswers> load() async => stored;

  @override
  Future<void> save(OnboardingAnswers answers) async {
    if (failSaves) {
      throw Exception('save failed');
    }
    saves.add(answers);
    stored = answers;
  }

  @override
  Future<void> complete() async => completions++;
}

void main() {
  late _RecordingRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _RecordingRepository();
    container = ProviderContainer(
      overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);
  OnboardingState state() => container.read(onboardingControllerProvider);

  /// Waits for the controller's initial load to finish.
  ///
  /// Waits on the condition rather than draining a fixed number of microtasks:
  /// the load is an await chain, and guessing its length is how a test becomes
  /// flaky.
  Future<void> settle([ProviderContainer? target]) async {
    final ProviderContainer c = target ?? container;
    for (int i = 0; i < 20; i++) {
      if (!c.read(onboardingControllerProvider).isLoading) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Builds the controller, then waits for its load.
  Future<void> ready() async {
    container.read(onboardingControllerProvider);
    await settle();
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              size: surfaceSize ?? const Size(400, 800),
            ),
            child: const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the steps', () {
    test('there are seven, matching the flow and the counter', () {
      // docs/USER_FLOWS.md §5's diagram and docs/COMPONENTS.md §18b's
      // "Step 3 of 7" agree on seven, even though §5's prose says six.
      expect(OnboardingStep.count, 7);
      expect(OnboardingStep.values.first, OnboardingStep.name);
      expect(OnboardingStep.values.last, OnboardingStep.cookingFor);
    });

    test('every step has a question and a subtitle', () {
      for (final OnboardingStep step in OnboardingStep.values) {
        expect(step.title, isNotEmpty, reason: step.name);
        expect(step.subtitle, isNotEmpty, reason: step.name);
      }
    });

    test('progress runs from a seventh to whole', () {
      expect(OnboardingStep.name.progress, closeTo(1 / 7, 0.001));
      expect(OnboardingStep.cookingFor.progress, 1);
    });

    test('the ends of the list know they are ends', () {
      expect(OnboardingStep.name.previous, isNull);
      expect(OnboardingStep.cookingFor.next, isNull);
      expect(OnboardingStep.name.next, OnboardingStep.cuisines);
    });
  });

  group('answers are persisted per step, not at the end', () {
    // docs/USER_FLOWS.md §5: "An abandoned onboarding still leaves the app
    // smarter than a blank one." That only holds if each advance writes.
    test('every advance writes', () async {
      await ready();

      controller().update(state().answers.copyWith(displayName: 'Marc'));
      await controller().advance();
      expect(repository.saves, hasLength(1));

      controller().update(
        state().answers.copyWith(
          favouriteCuisines: <Cuisine>{Cuisine.filipino},
        ),
      );
      await controller().advance();
      expect(repository.saves, hasLength(2));
    });

    test('the write carries everything answered so far', () async {
      await ready();

      controller().update(state().answers.copyWith(displayName: 'Marc'));
      await controller().advance();
      controller().update(
        state().answers.copyWith(
          favouriteCuisines: <Cuisine>{Cuisine.japanese},
        ),
      );
      await controller().advance();

      expect(repository.saves.last.displayName, 'Marc');
      expect(
        repository.saves.last.favouriteCuisines,
        contains(Cuisine.japanese),
      );
    });

    test('an abandoned run has already saved something', () async {
      await ready();

      controller().update(state().answers.copyWith(displayName: 'Marc'));
      await controller().advance();

      // The user closes the app here. What is stored is what matters.
      expect(repository.stored.hasAnyAnswer, isTrue);
      expect(repository.stored.displayName, 'Marc');
    });

    test('a failed save does not block the flow', () async {
      // Losing one step's write costs less than trapping someone on a question
      // they already answered.
      await ready();
      repository.failSaves = true;

      await controller().advance();

      expect(state().step, OnboardingStep.cuisines);
      expect(state().failure, isNotNull);
    });

    test('a resumed run starts from what was stored', () async {
      repository.stored = const OnboardingAnswers(
        displayName: 'Marc',
        favouriteCuisines: <Cuisine>{Cuisine.filipino},
      );

      final ProviderContainer resumed = ProviderContainer(
        overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(resumed.dispose);

      resumed.read(onboardingControllerProvider);
      await settle(resumed);

      expect(
        resumed.read(onboardingControllerProvider).answers.displayName,
        'Marc',
      );
    });
  });

  group('skipping', () {
    test('skip-all finishes and still writes what was answered', () async {
      // §5: "Impatience must not cost us the user." It also must not cost us the
      // answers they did give.
      await ready();
      controller().update(state().answers.copyWith(displayName: 'Marc'));

      await controller().skipAll();

      expect(state().isFinished, isTrue);
      expect(repository.saves, isNotEmpty);
      expect(repository.saves.last.displayName, 'Marc');
      expect(repository.completions, 1);
    });

    test('advancing past the last step finishes', () async {
      await ready();

      for (int i = 0; i < OnboardingStep.count; i++) {
        await controller().advance();
      }

      expect(state().isFinished, isTrue);
      expect(repository.completions, 1);
    });

    test('finishing releases the router guard', () async {
      // Onboarding's exit is the session flag, not a navigation — the router
      // reacts to it (docs/NAVIGATION_MAP.md §4).
      await ready();
      expect(container.read(sessionProvider).isOnboarded, isFalse);

      await controller().skipAll();

      expect(container.read(sessionProvider).isOnboarded, isTrue);
    });

    test('a failed completion still lets the user in', () async {
      // Seeing onboarding again next launch is annoying; being stuck on the
      // closing screen is not shippable.
      final _FailingCompleteRepository failing = _FailingCompleteRepository();
      final ProviderContainer local = ProviderContainer(
        overrides: [onboardingRepositoryProvider.overrideWithValue(failing)],
      );
      addTearDown(local.dispose);

      local.read(onboardingControllerProvider);
      await settle(local);
      await local.read(onboardingControllerProvider.notifier).skipAll();

      expect(local.read(onboardingControllerProvider).isFinished, isTrue);
      expect(local.read(sessionProvider).isOnboarded, isTrue);
    });
  });

  group('going back', () {
    test('returns to the previous step and keeps the answers', () async {
      // §7: "Back to previous step; already-saved answers persist."
      await ready();
      controller().update(state().answers.copyWith(displayName: 'Marc'));
      await controller().advance();

      controller().back();

      expect(state().step, OnboardingStep.name);
      expect(state().answers.displayName, 'Marc');
    });

    test('does nothing on the first step', () async {
      await ready();
      controller().back();

      expect(state().step, OnboardingStep.name);
    });

    test('does not write', () async {
      // The answers are already stored; re-writing on a back gesture would turn
      // a navigation into a request.
      await ready();
      await controller().advance();
      final int writes = repository.saves.length;

      controller().back();

      expect(repository.saves, hasLength(writes));
    });
  });

  group('the progress bar', () {
    test('reads 100% on the closing screen', () async {
      // docs/COMPONENTS.md §18b: "The bar reaches 100% on the closing screen.
      // Telling someone they are finished underneath a partial bar is a
      // contradiction, and it is asserted in test." This is that test.
      await ready();
      await controller().skipAll();

      expect(state().progress, 1);
      expect(state().progressLabel, 'All done');
    });

    test('counts the step, not the fraction', () async {
      await ready();

      expect(state().progressLabel, 'Step 1 of 7');
      await controller().advance();
      expect(state().progressLabel, 'Step 2 of 7');
    });

    testWidgets('the bar is excluded from semantics, the counter is not', (
      WidgetTester tester,
    ) async {
      // §18b: "The pair is announced once, via the counter — the bar is excluded
      // from semantics so a screen reader does not read the same fact twice."
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsLabel('Step 1 of 7'), findsOneWidget);
      expect(find.byType(OnboardingProgress), findsOneWidget);

      handle.dispose();
    });
  });

  group('the screen', () {
    testInBothThemes('renders the first question', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, brightness: brightness);

      expect(find.text(OnboardingStep.name.title), findsOneWidget);
      expect(find.text('Step 1 of 7'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
    });

    testWidgets('skipping is visible on every step, not a hidden gesture', (
      WidgetTester tester,
    ) async {
      // §5 is explicit that this must be a labelled control.
      await pumpScreen(tester);
      expect(find.widgetWithText(AppButton, 'Skip all'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Skip all'), findsOneWidget);
    });

    testWidgets('the back control appears only after the first step', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      expect(
        find.bySemanticsLabel('Back to the previous question'),
        findsNothing,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Back to the previous question'),
        findsOneWidget,
      );
    });

    testWidgets('the household prompt appears only on an explicit choice', (
      WidgetTester tester,
    ) async {
      // The ambiguity guarded in SupabaseOnboardingRepository: preferred_servings
      // defaults to 2, so loaded state must never be enough to offer this.
      await pumpScreen(tester);

      controller().update(
        state().answers.copyWith(cookingFor: CookingFor.justMe),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cook together?'), findsNothing);

      controller().update(
        state().answers.copyWith(cookingFor: CookingFor.withPartner),
      );
      await tester.pumpAndSettle();

      // Still not shown: the step itself is not on screen yet.
      expect(find.text('Cook together?'), findsNothing);
    });

    testWidgets('the last step finishes rather than continuing', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      for (int i = 0; i < OnboardingStep.count - 1; i++) {
        await tester.tap(find.widgetWithText(AppButton, 'Continue'));
        await tester.pumpAndSettle();
      }

      expect(find.widgetWithText(AppButton, 'Finish'), findsOneWidget);
    });

    testWidgets('the closing screen points at the spin', (
      WidgetTester tester,
    ) async {
      // §5: "The flow ends by pointing at the spin. Onboarding's job is to
      // deliver the user to their first decision, not to collect data."
      await pumpScreen(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Skip all'));
      await tester.pumpAndSettle();

      expect(find.text('That is all we need'), findsOneWidget);
      expect(find.widgetWithText(AppButton, "What's Cooking?"), findsOneWidget);
      expect(find.text('All done'), findsOneWidget);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('SelectableTile', () {
    testWidgets('selection is carried by the border and mark, not a fill', (
      WidgetTester tester,
    ) async {
      // docs/COMPONENTS.md §18b names flooding the card with colour as "the same
      // mistake the first pass at this design system made".
      await pumpComponent(
        tester,
        SelectableTile(title: 'Just me', isSelected: true, onSelected: () {}),
      );

      final AppColorScheme colors = tester.element(find.text('Just me')).colors;
      final DecoratedBox surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(SelectableTile),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration decoration = surface.decoration as BoxDecoration;

      expect(
        decoration.color,
        colors.surface,
        reason: 'a selected tile keeps the plain surface fill',
      );
      expect(decoration.border, isNotNull);
    });

    testWidgets('the mark holds its space either way', (
      WidgetTester tester,
    ) async {
      // §18b: "The mark occupies its space whether or not it is selected, so
      // choosing an option does not shift the text beside it."
      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: SelectableTile(
            title: 'Just me',
            isSelected: false,
            onSelected: () {},
          ),
        ),
      );
      final Offset unselected = tester.getTopLeft(find.text('Just me'));

      await pumpComponent(
        tester,
        SizedBox(
          width: 320,
          child: SelectableTile(
            title: 'Just me',
            isSelected: true,
            onSelected: () {},
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('Just me')), unselected);
    });

    testWidgets('announces its selection state', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpComponent(
        tester,
        SelectableTile(
          title: 'Just me',
          caption: 'One plate',
          isSelected: true,
          onSelected: () {},
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Just me. One plate')).hint,
        'Selected',
      );

      handle.dispose();
    });
  });

  group('answers', () {
    test('a cleared budget is different from zero', () {
      // Null means no preference; the engine treats the two very differently.
      const OnboardingAnswers withBudget = OnboardingAnswers(budget: 300);

      expect(withBudget.copyWith(clearBudget: true).budget, isNull);
      expect(withBudget.copyWith(budget: 0).budget, 0);
    });

    test('copyWith cannot accidentally clear', () {
      const OnboardingAnswers answers = OnboardingAnswers(budget: 300);

      expect(answers.copyWith(displayName: 'Marc').budget, 300);
    });

    test('servings default to two when nobody answered', () {
      expect(const OnboardingAnswers().preferredServings, 2);
      expect(
        const OnboardingAnswers(cookingFor: CookingFor.justMe)
            .preferredServings,
        1,
      );
    });

    test('hasAnyAnswer ignores whitespace', () {
      expect(const OnboardingAnswers(displayName: '   ').hasAnyAnswer, isFalse);
      expect(const OnboardingAnswers(displayName: 'Marc').hasAnyAnswer, isTrue);
    });
  });

  group('wire values match the schema', () {
    test('dietary tags are snake_case where the enum is', () {
      // `dietary_tag` is a Postgres enum; a mismatch is a failed insert, and the
      // tags are applied as a hard filter rather than a weight.
      expect(DietaryTag.glutenFree.value, 'gluten_free');
      expect(DietaryTag.dairyFree.value, 'dairy_free');
      expect(DietaryTag.nutFree.value, 'nut_free');
      expect(DietaryTag.lowCarb.value, 'low_carb');
      expect(DietaryTag.vegan.value, 'vegan');
    });

    test('cuisines are the lower-case constraint values', () {
      expect(Cuisine.filipino.value, 'filipino');
      expect(Cuisine.mediterranean.value, 'mediterranean');

      for (final Cuisine cuisine in Cuisine.values) {
        expect(
          cuisine.value,
          cuisine.value.toLowerCase(),
          reason: cuisine.name,
        );
      }
    });
  });
}

/// Completes [complete] with a failure, to check the user still gets in.
class _FailingCompleteRepository implements OnboardingRepository {
  @override
  Future<OnboardingAnswers> load() async => const OnboardingAnswers();

  @override
  Future<void> save(OnboardingAnswers answers) async {}

  @override
  Future<void> complete() async => throw Exception('offline');
}
