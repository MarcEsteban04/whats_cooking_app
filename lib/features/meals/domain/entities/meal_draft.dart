import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// One line of a meal's ingredient list, as typed.
///
/// A name rather than an ingredient id, because the person writing a recipe
/// should not have to find their onion in our vocabulary first. Resolving the
/// name to a row — and adding it if it is new — is the repository's job, which is
/// exactly what the `authenticated add ingredients` policy exists to allow:
/// "Users must never be blocked because our ingredient list is incomplete."
@immutable
class DraftIngredient {
  const DraftIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
  });

  final String name;
  final double quantity;

  /// One of the fixed set (docs/DATABASE.md §4.6).
  final String unit;
  final bool isOptional;

  bool get isBlank => name.trim().isEmpty;

  DraftIngredient copyWith({
    String? name,
    double? quantity,
    String? unit,
    bool? isOptional,
  }) {
    return DraftIngredient(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isOptional: isOptional ?? this.isOptional,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DraftIngredient &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.isOptional == isOptional;

  @override
  int get hashCode => Object.hash(name, quantity, unit, isOptional);

  /// The units a quantity may be given in (docs/DATABASE.md §4.6).
  static const List<String> units = <String>[
    'g',
    'ml',
    'pc',
    'tbsp',
    'tsp',
    'cup',
  ];
}

/// A meal a household is writing.
///
/// Separate from `Meal` on purpose. `Meal` describes a row that exists — it has
/// an id, and every column the database requires. A draft is what someone has
/// typed so far, which is allowed to be incomplete while they are typing and is
/// only checked when they submit ([validate]).
@immutable
class MealDraft {
  const MealDraft({
    this.name = '',
    this.description = '',
    this.cuisine = Cuisine.filipino,
    this.category = MealCategory.dinner,
    this.difficulty = Difficulty.easy,
    this.cookingTimeMinutes,
    this.estimatedCost,
    this.servings = 2,
    this.instructions = const <String>[],
    this.ingredients = const <DraftIngredient>[],
  });

  final String name;
  final String description;
  final Cuisine cuisine;
  final MealCategory category;
  final Difficulty difficulty;

  /// Null until typed. Required to submit — the column is `not null`, and a
  /// meal with no time cannot answer "something quick".
  final int? cookingTimeMinutes;

  /// Pesos for [servings] people, matching how the catalogue states cost.
  final int? estimatedCost;

  final int servings;
  final List<String> instructions;
  final List<DraftIngredient> ingredients;

  /// The ingredient lines with something in them.
  List<DraftIngredient> get filledIngredients => ingredients
      .where((DraftIngredient ingredient) => !ingredient.isBlank)
      .toList();

  /// The steps with something in them.
  List<String> get filledInstructions => instructions
      .map((String step) => step.trim())
      .where((String step) => step.isNotEmpty)
      .toList();

  /// What is stopping this being saved, or null.
  ///
  /// One message rather than per-field errors: the form disables its own submit
  /// button, so this is the last line of defence rather than the thing that
  /// guides typing. Returning the *first* problem keeps it actionable.
  String? validate() {
    if (name.trim().length < 2) {
      return 'Give the meal a name';
    }
    if (cookingTimeMinutes == null || cookingTimeMinutes! <= 0) {
      return 'How long does it take?';
    }
    if (estimatedCost == null || estimatedCost! < 0) {
      return 'Roughly what does it cost?';
    }
    if (servings <= 0) {
      return 'How many does it feed?';
    }
    for (final DraftIngredient ingredient in filledIngredients) {
      if (ingredient.quantity <= 0) {
        return 'How much ${ingredient.name.trim()}?';
      }
      if (!DraftIngredient.units.contains(ingredient.unit)) {
        return 'Pick a unit for ${ingredient.name.trim()}';
      }
    }
    return null;
  }

  bool get isValid => validate() == null;

  MealDraft copyWith({
    String? name,
    String? description,
    Cuisine? cuisine,
    MealCategory? category,
    Difficulty? difficulty,
    int? cookingTimeMinutes,
    int? estimatedCost,
    int? servings,
    List<String>? instructions,
    List<DraftIngredient>? ingredients,
  }) {
    return MealDraft(
      name: name ?? this.name,
      description: description ?? this.description,
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      servings: servings ?? this.servings,
      instructions: instructions ?? this.instructions,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MealDraft &&
      other.name == name &&
      other.description == description &&
      other.cuisine == cuisine &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.cookingTimeMinutes == cookingTimeMinutes &&
      other.estimatedCost == estimatedCost &&
      other.servings == servings &&
      listEquals(other.instructions, instructions) &&
      listEquals(other.ingredients, ingredients);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    cuisine,
    category,
    difficulty,
    cookingTimeMinutes,
    estimatedCost,
    servings,
    Object.hashAll(instructions),
    Object.hashAll(ingredients),
  );
}
