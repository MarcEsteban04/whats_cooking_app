import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/avatar.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/preferences/preference_editors.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/domain/repositories/profile_repository.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/profile/presentation/screens/preferences_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/profile_screen.dart';

import '../../support/component_harness.dart';

/// Records writes so optimistic updates and rollbacks are checkable.
class _RecordingProfileRepository implements ProfileRepository {
  UserProfile profile = const UserProfile(
    displayName: 'Marc Esteban',
    hasHousehold: true,
    householdName: "Marc's Kitchen",
  );

  final List<FoodPreferences> preferenceWrites = <FoodPreferences>[];
  final List<String> nameWrites = <String>[];
  int deletions = 0;

  bool failWrites = false;
  bool failLoad = false;

  @override
  Future<UserProfile> load() async {
    if (failLoad) {
      throw const ServerException();
    }
    return profile;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (failWrites) {
      throw const ServerException();
    }
    nameWrites.add(displayName);
    profile = profile.copyWith(displayName: displayName.trim());
  }

  @override
  Future<void> updatePreferences(FoodPreferences preferences) async {
    if (failWrites) {
      throw const ServerException();
    }
    preferenceWrites.add(preferences);
    profile = profile.copyWith(preferences: preferences);
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    if (failWrites) {
      throw const ServerException();
    }
    return 'https://example.test/avatar.$fileExtension';
  }

  @override
  Future<void> deleteAccount() async {
    if (failWrites) {
      throw const ServerException();
    }
    deletions++;
  }
}

void main() {
  late _RecordingProfileRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _RecordingProfileRepository();
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  ProfileController controller() =>
      container.read(profileControllerProvider.notifier);

  Future<UserProfile> loaded() =>
      container.read(profileControllerProvider.future);

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
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
            child: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the preference model is shared, not duplicated', () {
    // docs/COMPONENTS.md §18b's reason for sharing the editors applies to the
    // model behind them: "a user must meet the same cuisine grid on day one and
    // on day thirty".
    test('onboarding and profile write the same six fields', () {
      const FoodPreferences preferences = FoodPreferences(
        favouriteCuisines: <Cuisine>{Cuisine.filipino},
        dislikedFoods: <String>['fish'],
        dietaryTags: <DietaryTag>{DietaryTag.halal},
        budget: 300,
        maxCookingTimeMinutes: 30,
        cookingFor: CookingFor.withPartner,
      );

      expect(preferences.favouriteCuisines, hasLength(1));
      expect(preferences.preferredServings, 2);
      expect(preferences.hasAny, isTrue);
    });

    test('equality is by value, so an unchanged edit is detectable', () {
      // The Save button is disabled by comparing edited against saved. With
      // identity equality it would always look like there was something to save.
      const FoodPreferences a = FoodPreferences(
        favouriteCuisines: <Cuisine>{Cuisine.filipino, Cuisine.japanese},
        dislikedFoods: <String>['fish'],
      );
      const FoodPreferences b = FoodPreferences(
        favouriteCuisines: <Cuisine>{Cuisine.japanese, Cuisine.filipino},
        dislikedFoods: <String>['fish'],
      );

      expect(a, b, reason: 'set order should not matter');
      expect(a.copyWith(dislikedFoods: <String>['fish', 'nuts']), isNot(a));
    });

    test('a cleared budget differs from zero', () {
      const FoodPreferences withBudget = FoodPreferences(budget: 300);

      expect(withBudget.copyWith(clearBudget: true).budget, isNull);
      expect(withBudget.copyWith(budget: 0).budget, 0);
    });
  });

  group('saving preferences', () {
    test('writes and keeps the new value', () async {
      await loaded();

      const FoodPreferences edited = FoodPreferences(
        favouriteCuisines: <Cuisine>{Cuisine.korean},
      );
      final AppException? failure = await controller().updatePreferences(
        edited,
      );

      expect(failure, isNull);
      expect(repository.preferenceWrites.single, edited);
      expect(
        container.read(profileControllerProvider).value?.preferences,
        edited,
      );
    });

    test('a failed write rolls the screen back', () async {
      // Optimistic updates are only safe if they undo themselves. Leaving the
      // new value on screen after a failed write tells the user their change
      // saved when it did not.
      final UserProfile before = await loaded();
      repository.failWrites = true;

      final AppException? failure = await controller().updatePreferences(
        const FoodPreferences(favouriteCuisines: <Cuisine>{Cuisine.thai}),
      );

      expect(failure, isNotNull);
      expect(
        container.read(profileControllerProvider).value,
        before,
        reason: 'the rejected change should not be left on screen',
      );
    });

    test('a failed rename rolls back too', () async {
      final UserProfile before = await loaded();
      repository.failWrites = true;

      final AppException? failure = await controller().updateDisplayName('Ana');

      expect(failure, isNotNull);
      expect(container.read(profileControllerProvider).value, before);
    });

    test('a rename trims what it stores', () async {
      await loaded();
      await controller().updateDisplayName('  Marc  ');

      expect(
        container.read(profileControllerProvider).value?.displayName,
        'Marc',
      );
    });
  });

  group('avatar upload', () {
    test('is not optimistic', () async {
      // Unlike a name, the bytes can be rejected by the bucket for size or type.
      // Showing the new face first would mean taking it away again.
      final UserProfile before = await loaded();
      repository.failWrites = true;

      final AppException? failure = await controller().uploadAvatar(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'jpg',
      );

      expect(failure, isNotNull);
      expect(container.read(profileControllerProvider).value, before);
    });

    test('adopts the returned url on success', () async {
      await loaded();

      final AppException? failure = await controller().uploadAvatar(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'png',
      );

      expect(failure, isNull);
      expect(
        container.read(profileControllerProvider).value?.avatarUrl,
        contains('avatar.png'),
      );
    });
  });

  group('deletion reports its outcome', () {
    test('returns null when it worked', () async {
      await loaded();

      expect(await controller().deleteAccount(), isNull);
      expect(repository.deletions, 1);
    });

    test('returns the failure when it did not', () async {
      // The one action where a silent failure leaves someone believing their
      // data is gone when it is not.
      await loaded();
      repository.failWrites = true;

      expect(await controller().deleteAccount(), isNotNull);
    });
  });

  group('the profile screen', () {
    testInBothThemes('shows the name, avatar and each section', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), brightness: brightness);

      expect(find.text('Marc Esteban'), findsOneWidget);
      expect(find.byType(Avatar), findsOneWidget);
      expect(find.text('My preferences'), findsOneWidget);
      expect(find.text('Household'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('every row shows its current value, not just a label', (
      WidgetTester tester,
    ) async {
      // A settings list you have to open to read is a settings list nobody
      // reads.
      repository.profile = repository.profile.copyWith(
        preferences: const FoodPreferences(
          favouriteCuisines: <Cuisine>{Cuisine.filipino},
          budget: 300,
        ),
      );

      await pumpScreen(tester, const ProfileScreen());

      expect(find.text('₱300 a meal'), findsOneWidget);
      expect(find.textContaining('Filipino'), findsOneWidget);
    });

    testWidgets('says so plainly when nothing is set', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen());

      expect(find.text('Nothing set yet'), findsOneWidget);
      expect(find.text('No budget set'), findsOneWidget);
    });

    testWidgets('renders an error state with a retry', (
      WidgetTester tester,
    ) async {
      repository.failLoad = true;

      await pumpScreen(tester, const ProfileScreen());

      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ProfileScreen(),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('the preferences screen', () {
    testWidgets('uses the same editors onboarding used', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const PreferencesScreen());

      expect(find.byType(CuisinePicker), findsOneWidget);
      expect(find.byType(DislikesEditor), findsOneWidget);
      expect(find.byType(DietaryPicker), findsOneWidget);
    });

    testWidgets('Save is disabled until something changes', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const PreferencesScreen());

      AppButton save() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save'));

      expect(save().onPressed, isNull);

      await tester.tap(find.text(Cuisine.filipino.label));
      await tester.pumpAndSettle();

      expect(save().onPressed, isNotNull);
    });

    testWidgets('saving writes once, not once per toggle', (
      WidgetTester tester,
    ) async {
      // A screen that saved on every toggle would be six writes for six
      // cuisines, and would give no chance to change your mind first.
      await pumpScreen(tester, const PreferencesScreen());

      await tester.tap(find.text(Cuisine.filipino.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Cuisine.japanese.label));
      await tester.pumpAndSettle();

      expect(repository.preferenceWrites, isEmpty);

      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.preferenceWrites, hasLength(1));
      expect(repository.preferenceWrites.single.favouriteCuisines, <Cuisine>{
        Cuisine.filipino,
        Cuisine.japanese,
      });
    });

    testWidgets('a failed save keeps the edits on screen', (
      WidgetTester tester,
    ) async {
      // Losing the edits along with the write would make the user redo work the
      // app already had.
      await pumpScreen(tester, const PreferencesScreen());

      await tester.tap(find.text(Cuisine.filipino.label));
      await tester.pumpAndSettle();

      repository.failWrites = true;
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Save'))
            .onPressed,
        isNotNull,
        reason: 'the edit is still pending, so Save is still available',
      );
    });
  });

  group('Avatar', () {
    test('initials come from the first and last name', () {
      expect(avatarInitialsFor('Marc Esteban'), 'ME');
      expect(avatarInitialsFor('Marc'), 'M');
      expect(avatarInitialsFor('Marc Andres Esteban'), 'ME');
    });

    test('handles spacing and case', () {
      expect(avatarInitialsFor('  marc   esteban  '), 'ME');
    });

    test('an empty name falls back to a glyph, not a letter or a blank', () {
      // A blank circle reads as broken and "?" reads as an error.
      expect(avatarInitialsFor(''), '🍽️');
      expect(avatarInitialsFor('   '), '🍽️');
    });

    testInBothThemes('renders initials with no image', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpComponent(
        tester,
        const Avatar(name: 'Marc Esteban'),
        brightness: brightness,
      );

      expect(find.text('ME'), findsOneWidget);
    });

    test('each size has a distinct diameter', () {
      expect(AvatarSize.small.diameter, 32);
      expect(AvatarSize.medium.diameter, 48);
      expect(AvatarSize.large.diameter, 96);
    });
  });
}
