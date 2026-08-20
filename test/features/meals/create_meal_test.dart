import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/meals/data/repositories/in_memory_meal_repository.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';

/// Writing your own meal (Sprint 26's create half).
void main() {
  late InMemoryMealRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemoryMealRepository(latency: Duration.zero);
    container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  group('MealDraft validation', () {
    const MealDraft complete = MealDraft(
      name: 'Tita Baby adobo',
      cookingTimeMinutes: 45,
      estimatedCost: 260,
    );

    test('a complete draft is valid', () {
      expect(complete.validate(), isNull);
      expect(complete.isValid, isTrue);
    });

    test('names the first thing missing, so the message is actionable', () {
      expect(const MealDraft().validate(), 'Give the meal a name');
      expect(
        const MealDraft(name: 'Adobo').validate(),
        'How long does it take?',
      );
      expect(
        const MealDraft(name: 'Adobo', cookingTimeMinutes: 45).validate(),
        contains('cost'),
      );
    });

    test('a quantity of zero is caught, and names the ingredient', () {
      // The database would reject it — `quantity > 0` — and a constraint
      // violation is not a message anyone can act on.
      final MealDraft draft = complete.copyWith(
        ingredients: <DraftIngredient>[
          const DraftIngredient(name: 'chicken thigh', quantity: 0, unit: 'g'),
        ],
      );

      expect(draft.validate(), contains('chicken thigh'));
    });

    test('a unit outside the fixed set is caught', () {
      // docs/DATABASE.md §4.6 fixes the vocabulary, and the grocery list depends
      // on it to add two quantities together (Sprint 50).
      final MealDraft draft = complete.copyWith(
        ingredients: <DraftIngredient>[
          const DraftIngredient(name: 'rice', quantity: 2, unit: 'sacks'),
        ],
      );

      expect(draft.validate(), contains('unit'));
    });

    test('blank lines are dropped rather than saved', () {
      // The editors add an empty row when you tap "add another", and leaving one
      // untouched must not write an empty ingredient or an empty step.
      final MealDraft draft = complete.copyWith(
        ingredients: <DraftIngredient>[
          const DraftIngredient(name: '  ', quantity: 1, unit: 'pc'),
          const DraftIngredient(name: 'garlic', quantity: 6, unit: 'pc'),
        ],
        instructions: <String>['Fry the garlic.', '   ', ''],
      );

      expect(draft.filledIngredients, hasLength(1));
      expect(draft.filledInstructions, <String>['Fry the garlic.']);
      expect(draft.validate(), isNull);
    });
  });

  group('creating a meal', () {
    const MealDraft draft = MealDraft(
      name: 'Tita Baby adobo',
      description: 'More vinegar than anyone expects.',
      cookingTimeMinutes: 50,
      estimatedCost: 300,
      servings: 3,
      instructions: <String>['Marinate.', 'Simmer.'],
    );

    test('is stored as private to the household, never as catalogue', () async {
      // The `create own meals` policy accepts an insert only when `is_public` is
      // false. Anything else is a rejected write, so the app must not even try.
      final Meal meal = await repository.create(draft);

      expect(meal.isPublic, isFalse);
      expect(meal.isMine, isTrue);
      expect(meal.name, 'Tita Baby adobo');
      expect(meal.instructions, hasLength(2));
    });

    test('appears in the feed straight away', () async {
      await repository.create(draft);

      final MealPage page = await repository.search(
        query: const MealQuery(search: 'tita'),
      );

      expect(page.meals.single.name, 'Tita Baby adobo');
    });

    test('is found by the same filters as a catalogue meal', () async {
      // Household meals are not a separate list. They go through the same query,
      // which is why the repository applies no visibility filter of its own and
      // lets Row Level Security decide.
      await repository.create(draft);

      final MealPage byCuisine = await repository.search(
        query: const MealQuery(cuisines: <Cuisine>{Cuisine.filipino}),
      );

      expect(
        byCuisine.meals.map((Meal meal) => meal.name),
        contains('Tita Baby adobo'),
      );
    });
  });
}
