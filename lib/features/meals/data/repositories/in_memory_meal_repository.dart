import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_ingredient.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';

/// A [MealRepository] with the catalogue held in memory.
///
/// Two jobs. It is what a build with no credentials falls back to, so a fresh
/// clone shows a working feed rather than an error (`supabase/README.md`). And it
/// is what the tests run against, which is the more demanding of the two: the
/// filtering, ordering and paging here have to mean the same thing as the
/// PostgREST versions, or the tests prove nothing about the app people use.
///
/// The sample is a slice of `supabase/seed/02_meals.sql` — enough meals to cover
/// every category, several cuisines, and both extremes of time and cost, so a
/// filter that is wired up backwards produces a visibly wrong list rather than a
/// plausible one.
class InMemoryMealRepository implements MealRepository {
  InMemoryMealRepository({List<Meal>? meals, this.latency = _defaultLatency})
    : _meals = List<Meal>.of(meals ?? sampleCatalogue);

  final List<Meal> _meals;

  /// Simulated round trip.
  ///
  /// Exposed so a widget test can advance the fake clock past it. Awaiting a
  /// real delay before pumping deadlocks the test binding, which is a mistake
  /// worth only making once.
  final Duration latency;

  /// Set to make every read fail, for exercising the error state.
  bool failReads = false;

  /// Set to make every write fail.
  bool failWrites = false;

  @override
  Future<MealPage> search({
    required MealQuery query,
    int offset = 0,
    int limit = kMealPageSize,
  }) async {
    await Future<void>.delayed(latency);

    if (failReads) {
      // A `ServerException` rather than a bare `Exception`, so the failure the
      // tests exercise is the one the app actually has to handle: retryable,
      // with a message written for a person.
      throw const ServerException();
    }

    final String search = query.search.trim().toLowerCase();

    final List<Meal> matching = _meals.where((Meal meal) {
      // First, because it is the one condition that is not negotiable: a hidden
      // meal never appears, whatever else matches (Sprint 25).
      if (query.excludedMealIds.contains(meal.id)) {
        return false;
      }
      if (search.isNotEmpty && !meal.name.toLowerCase().contains(search)) {
        return false;
      }
      if (query.cuisines.isNotEmpty && !query.cuisines.contains(meal.cuisine)) {
        return false;
      }
      if (query.categories.isNotEmpty &&
          !query.categories.contains(meal.category)) {
        return false;
      }
      if (query.maxCookingTimeMinutes case final int minutes) {
        if (meal.cookingTimeMinutes > minutes) {
          return false;
        }
      }
      if (query.maxCostPerServing case final int pesos) {
        if (meal.costPerServing > pesos) {
          return false;
        }
      }
      return true;
    }).toList();

    matching.sort((Meal a, Meal b) => _compare(a, b, query.sort));

    final List<Meal> page = matching.skip(offset).take(limit).toList();

    return MealPage(
      meals: page,
      hasMore: matching.length > offset + page.length,
    );
  }

  @override
  Future<Meal> create(MealDraft draft) async {
    await Future<void>.delayed(latency);

    if (failWrites) {
      throw const ServerException();
    }

    final Meal meal = Meal(
      // Sequential rather than random, so a test can predict it and two meals
      // created in the same millisecond cannot collide.
      id: 'local-${_meals.length + 1}',
      name: draft.name.trim(),
      description: draft.description.trim().isEmpty
          ? null
          : draft.description.trim(),
      cuisine: draft.cuisine,
      category: draft.category,
      difficulty: draft.difficulty,
      cookingTimeMinutes: draft.cookingTimeMinutes!,
      estimatedCost: draft.estimatedCost!.toDouble(),
      servings: draft.servings,
      instructions: draft.filledInstructions,
      // Household-written, exactly as the database would store it: the
      // `create own meals` policy accepts nothing else.
      isPublic: false,
    );

    _meals.add(meal);
    return meal;
  }

  @override
  Future<Meal> byId(String id) async {
    await Future<void>.delayed(latency);

    if (failReads) {
      throw const ServerException();
    }

    for (final Meal meal in _meals) {
      if (meal.id == id) {
        return meal;
      }
    }

    throw const NotFoundException(message: 'We could not find that meal');
  }

  @override
  Future<List<Meal>> byIds(Set<String> ids) async {
    await Future<void>.delayed(latency);

    if (failReads) {
      throw const ServerException();
    }

    final List<Meal> found = _meals
        .where((Meal meal) => ids.contains(meal.id))
        .toList();
    found.sort(
      (Meal a, Meal b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return found;
  }

  /// The same order the database produces.
  ///
  /// The id tiebreaker is not decoration. `List.sort` is not stable in Dart, so
  /// without it two meals with the same cooking time could swap places between
  /// the request for page one and the request for page two — and the reader
  /// would see one meal twice and never see another at all.
  static int _compare(Meal a, Meal b, MealSort sort) {
    final int primary = switch (sort) {
      MealSort.alphabetical => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      MealSort.quickest => a.cookingTimeMinutes.compareTo(b.cookingTimeMinutes),
      MealSort.cheapest => a.costPerServing.compareTo(b.costPerServing),
      // No timestamps in the sample, so "newest" falls back to the id. The
      // ordering is arbitrary but *stable*, which is the property paging needs.
      MealSort.newest => 0,
    };

    return primary != 0 ? primary : a.id.compareTo(b.id);
  }

  static const Duration _defaultLatency = Duration(milliseconds: 200);

  /// Twelve meals from the seed.
  static final List<Meal> sampleCatalogue = <Meal>[
    const Meal(
      id: 'sample-adobo',
      name: 'Chicken Adobo',
      description:
          'The one everybody has an opinion about. Soy, vinegar, garlic and '
          'patience.',
      cuisine: Cuisine.filipino,
      category: MealCategory.dinner,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 45,
      estimatedCost: 260,
      servings: 4,
      calories: 520,
      instructions: <String>[
        'Marinate the chicken in soy sauce, crushed garlic and pepper.',
        'Sear the pieces until the skin colours, then set aside.',
        'Add the marinade and vinegar. Do not stir until it boils.',
        'Simmer covered, then reduce until the sauce coats.',
      ],
      ingredients: <MealIngredient>[
        MealIngredient(name: 'chicken thigh', quantity: 800, unit: 'g'),
        MealIngredient(
          name: 'soy sauce',
          quantity: 120,
          unit: 'ml',
          isStaple: true,
        ),
        MealIngredient(
          name: 'vinegar',
          quantity: 80,
          unit: 'ml',
          isStaple: true,
        ),
        MealIngredient(name: 'garlic', quantity: 6, unit: 'pc', isStaple: true),
        MealIngredient(name: 'bay leaf', quantity: 3, unit: 'pc'),
      ],
      tags: <String>['comfort', 'make_ahead', 'one_pot'],
    ),
    const Meal(
      id: 'sample-sinigang',
      name: 'Pork Sinigang',
      description:
          'Sour, hot and full of vegetables. What you cook when it '
          'rains.',
      cuisine: Cuisine.filipino,
      category: MealCategory.dinner,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 60,
      estimatedCost: 320,
      servings: 4,
      calories: 430,
      instructions: <String>[
        'Boil the pork with onion and tomato until tender.',
        'Stir in the tamarind base and season with fish sauce.',
        'Add the vegetables, hardest first, greens last.',
      ],
      tags: <String>['comfort', 'soup', 'rainy_day'],
    ),
    const Meal(
      id: 'sample-tortang-talong',
      name: 'Tortang Talong',
      description:
          'Grilled eggplant folded into egg. Cheap, fast and better than it '
          'sounds.',
      cuisine: Cuisine.filipino,
      category: MealCategory.lunch,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 25,
      estimatedCost: 120,
      servings: 2,
      calories: 280,
      instructions: <String>[
        'Grill the eggplants until the skins blister.',
        'Peel, then flatten each one with a fork.',
        'Dip in beaten egg and fry until set on both sides.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      ingredients: <MealIngredient>[
        MealIngredient(name: 'eggplant', quantity: 2, unit: 'pc'),
        MealIngredient(name: 'egg', quantity: 3, unit: 'pc'),
        MealIngredient(
          name: 'tomato',
          quantity: 1,
          unit: 'pc',
          isOptional: true,
        ),
      ],
      tags: <String>['budget', 'meatless', 'quick'],
    ),
    const Meal(
      id: 'sample-garlic-rice',
      name: 'Garlic Fried Rice and Egg',
      description:
          'Yesterday rice, today garlic, one egg. The cheapest good meal there '
          'is.',
      cuisine: Cuisine.filipino,
      category: MealCategory.breakfast,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 15,
      estimatedCost: 80,
      servings: 2,
      calories: 480,
      instructions: <String>[
        'Use cold day-old rice. Fresh rice steams and clumps.',
        'Fry sliced garlic slowly until pale gold, then lift it out.',
        'Toss the rice through the garlic oil and fry the eggs hard-edged.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      tags: <String>['budget', 'quick', 'leftovers'],
    ),
    const Meal(
      id: 'sample-turon',
      name: 'Turon',
      description:
          'Banana and brown sugar in a wrapper, fried until it '
          'crackles.',
      cuisine: Cuisine.filipino,
      category: MealCategory.dessert,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 20,
      estimatedCost: 90,
      servings: 4,
      calories: 320,
      instructions: <String>[
        'Roll halved bananas in brown sugar.',
        'Wrap tightly, sealing the edge with water.',
        'Fry until the sugar caramelises dark gold.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      ingredients: <MealIngredient>[
        MealIngredient(name: 'banana', quantity: 4, unit: 'pc'),
        MealIngredient(name: 'lumpia wrapper', quantity: 8, unit: 'pc'),
        MealIngredient(name: 'brown sugar', quantity: 100, unit: 'g'),
      ],
      tags: <String>['street_food', 'fried', 'quick'],
    ),
    const Meal(
      id: 'sample-katsu-curry',
      name: 'Chicken Katsu Curry',
      description:
          'Crisp cutlet, thick curry, rice. The most reliable dinner in this '
          'list.',
      cuisine: Cuisine.japanese,
      category: MealCategory.dinner,
      difficulty: Difficulty.medium,
      cookingTimeMinutes: 50,
      estimatedCost: 340,
      servings: 3,
      calories: 720,
      instructions: <String>[
        'Simmer the potato and carrot, then melt in the curry roux.',
        'Flour, egg and panko each cutlet, pressing firmly.',
        'Shallow-fry until deep gold and rest on a rack.',
      ],
      tags: <String>['comfort', 'fried', 'crowd_pleaser'],
    ),
    const Meal(
      id: 'sample-miso-soup',
      name: 'Miso Soup',
      description:
          'Kombu broth, miso, tofu. Fifteen minutes and the table '
          'feels set.',
      cuisine: Cuisine.japanese,
      category: MealCategory.snack,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 15,
      estimatedCost: 110,
      servings: 4,
      calories: 90,
      instructions: <String>[
        'Heat the kombu slowly and lift it out before it boils.',
        'Warm the cubed tofu through.',
        'Whisk the miso in off the heat. Never boil miso.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian, DietaryTag.vegan},
      tags: <String>['light', 'soup', 'meatless'],
    ),
    const Meal(
      id: 'sample-tteokbokki',
      name: 'Tteokbokki',
      description:
          'Chewy rice cakes in a sweet, hot sauce. Ready before you change '
          'your mind.',
      cuisine: Cuisine.korean,
      category: MealCategory.snack,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 25,
      estimatedCost: 180,
      servings: 2,
      calories: 460,
      instructions: <String>[
        'Bring water, gochujang, gochugaru and sugar to a simmer.',
        'Add the rice cakes and stir often so they do not stick.',
        'Cook until the sauce thickens enough to coat.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      tags: <String>['spicy', 'street_food', 'quick'],
    ),
    const Meal(
      id: 'sample-beef-broccoli',
      name: 'Beef and Broccoli',
      description: 'A stir-fry that lives or dies on how hot the pan is.',
      cuisine: Cuisine.chinese,
      category: MealCategory.dinner,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 25,
      estimatedCost: 340,
      servings: 3,
      calories: 420,
      instructions: <String>[
        'Toss the sliced beef with corn starch and soy sauce.',
        'Blanch the broccoli for ninety seconds and drain it well.',
        'Sear the beef in a smoking pan, then bring everything together.',
      ],
      ingredients: <MealIngredient>[
        MealIngredient(name: 'beef sirloin', quantity: 450, unit: 'g'),
        MealIngredient(name: 'broccoli', quantity: 400, unit: 'g'),
        MealIngredient(name: 'oyster sauce', quantity: 60, unit: 'ml'),
        MealIngredient(name: 'corn starch', quantity: 20, unit: 'g'),
      ],
      tags: <String>['quick', 'stir_fry', 'high_protein'],
    ),
    const Meal(
      id: 'sample-aglio-e-olio',
      name: 'Spaghetti Aglio e Olio',
      description:
          'Pasta, garlic, oil, chili. Nothing to buy and nowhere to '
          'hide.',
      cuisine: Cuisine.italian,
      category: MealCategory.dinner,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 20,
      estimatedCost: 150,
      servings: 2,
      calories: 520,
      instructions: <String>[
        'Salt the pasta water properly. It is the only seasoning here.',
        'Warm sliced garlic in oil over a low heat. Do not brown it.',
        'Add chili and pasta water, and swirl until it turns creamy.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian, DietaryTag.vegan},
      tags: <String>['budget', 'quick', 'pantry'],
    ),
    const Meal(
      id: 'sample-quesadillas',
      name: 'Quesadillas',
      description:
          'Cheese between tortillas. Fifteen minutes and everybody is '
          'happy.',
      cuisine: Cuisine.mexican,
      category: MealCategory.snack,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 15,
      estimatedCost: 160,
      servings: 2,
      calories: 480,
      instructions: <String>[
        'Fry the pepper and onion until soft and sweet.',
        'Grate the cheese; sliced cheese slides out and burns.',
        'Dry-fry folded, pressing down, until the cheese runs.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      tags: <String>['quick', 'meatless', 'kid_friendly'],
    ),
    const Meal(
      id: 'sample-pancakes',
      name: 'Buttermilk Pancakes',
      description: 'A stack for a slow morning. Lumpy batter is correct.',
      cuisine: Cuisine.american,
      category: MealCategory.breakfast,
      difficulty: Difficulty.easy,
      cookingTimeMinutes: 20,
      estimatedCost: 140,
      servings: 4,
      calories: 420,
      instructions: <String>[
        'Combine wet and dry with a few strokes only.',
        'Rest the batter while the pan heats to medium.',
        'Cook until bubbles break on the surface, then turn once.',
      ],
      dietaryTags: <DietaryTag>{DietaryTag.vegetarian},
      tags: <String>['weekend', 'sweet', 'kid_friendly'],
    ),
  ];
}
