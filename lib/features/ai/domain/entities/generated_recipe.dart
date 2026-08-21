import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';

/// A recipe the assistant wrote (Sprint 48).
///
/// **Parsed from labelled lines, not JSON.** Models are good at JSON now, and JSON
/// would still be the wrong choice here: a brace it forgets to close makes the
/// whole reply worthless, where a labelled block that ends early still yields a
/// name, a time and four steps. This feature's failure mode should be *a recipe
/// missing its cost*, not *nothing at all* — and every field is validated and
/// clamped on the way in anyway, so the strictness JSON would buy is already
/// bought.
///
/// Nothing here is saved automatically. It becomes a [MealDraft] and opens the
/// ordinary meal form, which is where a person confirms it — see [toDraft].
@immutable
class GeneratedRecipe {
  const GeneratedRecipe({
    required this.name,
    this.cuisine = Cuisine.filipino,
    this.category = MealCategory.dinner,
    this.difficulty = Difficulty.easy,
    this.cookingTimeMinutes = 30,
    this.estimatedCost,
    this.servings = 2,
    this.ingredients = const <DraftIngredient>[],
    this.steps = const <String>[],
  });

  final String name;
  final Cuisine cuisine;
  final MealCategory category;
  final Difficulty difficulty;
  final int cookingTimeMinutes;

  /// For the whole dish, in pesos. Null when the model did not say.
  ///
  /// Whole pesos, matching `MealDraft` — the catalogue states cost for the pot and
  /// divides for the head, and a generated recipe has no business being the one
  /// meal in the library carrying centavos.
  final int? estimatedCost;

  final int servings;
  final List<DraftIngredient> ingredients;
  final List<String> steps;

  /// Whether this is worth showing at all.
  ///
  /// A name and something to do. A "recipe" with no steps is a suggestion, and one
  /// with no ingredients is a title — neither is what somebody asked for, and
  /// showing either would teach them the feature does not work.
  bool get isUsable =>
      name.trim().isNotEmpty && steps.isNotEmpty && ingredients.isNotEmpty;

  /// The draft the meal form opens with.
  ///
  /// **The form is the confirmation step, and it is not optional.** A generated
  /// recipe goes into the library only after a person has looked at it, for the
  /// same reason the fridge scanner will confirm its ingredients: a model's
  /// quantities are a good guess and a good guess in a recipe you cook from is
  /// still a guess. Routing through the ordinary form also means the generated
  /// recipe gets the same validation, the same unit vocabulary and the same save
  /// path as one typed by hand — no second way in to keep in step.
  MealDraft toDraft() => MealDraft(
    name: name.trim(),
    // No description. The model was asked for a recipe, and a blurb it invented
    // about a dish nobody has cooked yet is the one field here that would be
    // pure decoration.
    cuisine: cuisine,
    category: category,
    difficulty: difficulty,
    cookingTimeMinutes: cookingTimeMinutes,
    estimatedCost: estimatedCost,
    servings: servings,
    instructions: steps,
    ingredients: ingredients,
  );

  /// Reads the assistant's reply.
  ///
  /// Returns null when there is not enough to be a recipe. Lenient about
  /// everything else: markdown fences, bold labels, a leading "Sure —", numbered
  /// or dashed lists. All of those are things models do, and refusing them would
  /// throw away answers that are correct after the first four characters.
  static GeneratedRecipe? parse(String reply) {
    final List<String> lines = reply
        .replaceAll('**', '')
        .replaceAll('`', '')
        .split('\n')
        .map((String line) => line.trim())
        .toList();

    String name = '';
    Cuisine cuisine = Cuisine.filipino;
    MealCategory category = MealCategory.dinner;
    Difficulty difficulty = Difficulty.easy;
    int? minutes;
    int? cost;
    int? servings;
    final List<DraftIngredient> ingredients = <DraftIngredient>[];
    final List<String> steps = <String>[];

    _Section section = _Section.none;

    for (final String line in lines) {
      if (line.isEmpty) {
        continue;
      }

      final String upper = line.toUpperCase();

      // A label switches section *and* may carry its value on the same line, so
      // both "INGREDIENTS:" and "TIME: 35" work.
      if (upper.startsWith('NAME:')) {
        name = _after(line);
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('CUISINE:')) {
        cuisine = Cuisine.fromValue(_after(line).toLowerCase()) ?? cuisine;
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('MEAL:') || upper.startsWith('CATEGORY:')) {
        category = MealCategory.fromValue(_after(line).toLowerCase()) ?? category;
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('DIFFICULTY:')) {
        difficulty = Difficulty.fromValue(_after(line).toLowerCase()) ?? difficulty;
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('TIME:')) {
        minutes = _firstInt(_after(line));
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('COST:')) {
        cost = _firstInt(_after(line).replaceAll(',', ''));
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('SERVINGS:')) {
        servings = _firstInt(_after(line));
        section = _Section.none;
        continue;
      }
      if (upper.startsWith('INGREDIENTS')) {
        section = _Section.ingredients;
        continue;
      }
      if (upper.startsWith('STEPS') || upper.startsWith('INSTRUCTIONS')) {
        section = _Section.steps;
        continue;
      }

      switch (section) {
        case _Section.ingredients:
          if (_ingredient(line) case final DraftIngredient parsed) {
            ingredients.add(parsed);
          }
        case _Section.steps:
          final String step = _bullet(line);
          if (step.isNotEmpty) {
            steps.add(step);
          }
        case _Section.none:
          break;
      }
    }

    final GeneratedRecipe recipe = GeneratedRecipe(
      name: name,
      cuisine: cuisine,
      category: category,
      difficulty: difficulty,
      // Clamped rather than trusted. A model that writes "TIME: 480" for a stew
      // is not wrong, but a form field that arrives at eight hours reads as a
      // parse failure — and the column is a `smallint` with a positive check.
      cookingTimeMinutes: (minutes ?? 30).clamp(5, 480),
      estimatedCost: cost?.clamp(0, _maxCost),
      servings: (servings ?? 2).clamp(1, 12),
      ingredients: ingredients.take(_maxIngredients).toList(),
      steps: steps.take(_maxSteps).toList(),
    );

    return recipe.isUsable ? recipe : null;
  }

  /// Whatever follows the first colon.
  static String _after(String line) {
    final int colon = line.indexOf(':');
    return colon < 0 ? '' : line.substring(colon + 1).trim();
  }

  /// A list line with its bullet or number removed.
  static String _bullet(String line) => line
      .replaceFirst(RegExp(r'^\s*(?:[-*•]|\d{1,2}[.)])\s*'), '')
      .trim();

  /// `500 g chicken`, `2 pc egg`, `soy sauce`.
  ///
  /// Quantity and unit are optional in the text and mandatory in the model, so a
  /// bare name becomes `1 pc` — which is what a person writing "soy sauce" on a
  /// recipe means, and is editable in the form either way.
  static DraftIngredient? _ingredient(String line) {
    final String text = _bullet(line);
    if (text.isEmpty) {
      return null;
    }

    final RegExpMatch? match = RegExp(
      r'^([\d.,/]+)\s*([A-Za-z]+)?\s+(.+)$',
    ).firstMatch(text);

    if (match == null) {
      return DraftIngredient(name: text, quantity: 1, unit: 'pc');
    }

    final double quantity = _firstDouble(match.group(1) ?? '') ?? 1;
    final String rawUnit = (match.group(2) ?? '').toLowerCase();
    final String rest = (match.group(3) ?? '').trim();

    // A word in the unit slot that is not a unit is part of the name — "2 large
    // onions" is two onions, not two larges.
    final bool isUnit = DraftIngredient.units.contains(rawUnit);

    return DraftIngredient(
      name: isUnit ? rest : '$rawUnit $rest'.trim(),
      quantity: quantity <= 0 ? 1 : quantity,
      unit: isUnit ? rawUnit : 'pc',
    );
  }

  static int? _firstInt(String value) {
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static double? _firstDouble(String value) {
    final RegExpMatch? match = RegExp(
      r'(\d+(?:\.\d+)?)',
    ).firstMatch(value.replaceAll(',', ''));
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  /// Caps, matching what the meal form will accept.
  static const int _maxIngredients = 20;
  static const int _maxSteps = 15;

  /// A hundred thousand pesos for one dinner is a misplaced decimal, not a meal.
  static const int _maxCost = 100000;
}

enum _Section { none, ingredients, steps }
