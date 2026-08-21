/// The app's fixed food vocabulary.
///
/// In `core/domain/` rather than inside a feature because three features need it:
/// onboarding captures these, profile edits them, and the recommendation engine
/// filters on them. docs/ARCHITECTURE.md §2.3 — "anything needed by two or more
/// features moves to `core/`" — and a shared *domain* type has nowhere else to
/// live, since `core/` may not depend on a feature.
///
/// Every value mirrors a database constraint. A mismatch is a failed insert
/// rather than a silent shrug, which is why the wire value is stated here rather
/// than derived at each call site.
library;

/// The cuisines the catalogue knows about.
///
/// Mirrors the `check` constraint on `meals.cuisine`
/// (supabase/migrations/…_meals_ingredients.sql).
enum Cuisine {
  filipino('Filipino'),
  japanese('Japanese'),
  korean('Korean'),
  chinese('Chinese'),
  thai('Thai'),
  vietnamese('Vietnamese'),
  italian('Italian'),
  mexican('Mexican'),
  american('American'),
  indian('Indian'),
  mediterranean('Mediterranean'),
  other('Something else');

  const Cuisine(this.label);

  final String label;

  /// The value written to the database.
  String get value => name;

  /// The cuisine for a stored [value], or null when it is unrecognised.
  ///
  /// Null rather than throwing: a cuisine retired from the app should not make a
  /// profile unopenable for whoever had picked it.
  static Cuisine? fromValue(String value) {
    for (final Cuisine cuisine in Cuisine.values) {
      if (cuisine.value == value) {
        return cuisine;
      }
    }
    return null;
  }
}

/// The dietary tags the schema accepts.
///
/// Mirrors the `dietary_tag` enum. The recommendation engine applies these as a
/// **hard filter, never a penalty** (supabase/migrations/…_preferences.sql), so
/// getting one wrong does not merely skew a score — it hides food someone can
/// eat, or offers food they cannot.
enum DietaryTag {
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  pescatarian('Pescatarian'),
  halal('Halal'),
  kosher('Kosher'),
  glutenFree('Gluten free', 'gluten_free'),
  dairyFree('Dairy free', 'dairy_free'),
  nutFree('Nut free', 'nut_free'),
  lowCarb('Low carb', 'low_carb'),
  keto('Keto');

  const DietaryTag(this.label, [this._wireValue]);

  final String label;

  /// Set only where the database value differs from the Dart name.
  final String? _wireValue;

  /// The value written to the database — snake_case, unlike the Dart name.
  String get value => _wireValue ?? name;

  static DietaryTag? fromValue(String value) {
    for (final DietaryTag tag in DietaryTag.values) {
      if (tag.value == value) {
        return tag;
      }
    }
    return null;
  }
}

/// Who the user cooks for.
///
/// Drives `user_preferences.preferred_servings`, and decides whether onboarding
/// offers the household branch — docs/USER_FLOWS.md §5 puts that prompt at this
/// question because it is "the highest-intent moment for couple mode".
enum CookingFor {
  justMe(label: 'Just me', servings: 1, caption: 'One plate, no negotiating'),
  withPartner(
    label: 'Me and my partner',
    servings: 2,
    caption: 'The "ikaw bahala" cure',
  ),
  family(label: 'My family', servings: 4, caption: 'Feeding a household');

  const CookingFor({
    required this.label,
    required this.servings,
    required this.caption,
  });

  final String label;
  final int servings;

  /// The supporting line on the tile (docs/COMPONENTS.md §18b).
  final String caption;

  /// Whether choosing this should offer to set up a household.
  bool get invitesHousehold => this != CookingFor.justMe;

  /// The option matching [servings], if any.
  static CookingFor? fromServings(int? servings) {
    if (servings == null) {
      return null;
    }
    for (final CookingFor option in CookingFor.values) {
      if (option.servings == servings) {
        return option;
      }
    }
    return null;
  }

  // No glyph here any more. The tiles carry icons now, and mapping one would
  // mean importing Flutter into `core/domain` — which imports nothing, on
  // purpose. `preference_editors.dart` owns that mapping instead.
}

/// When a meal is eaten.
///
/// Mirrors the `meal_category` enum. Named `MealCategory` rather than
/// `MealType`: the schema has both, and `meal_type` belongs to the planner
/// (v1.3), which has its own idea of a slot in a day.
enum MealCategory {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snacks'),
  dessert('Desserts');

  const MealCategory(this.label);

  final String label;

  String get value => name;

  /// Null rather than throwing, for the same reason [Cuisine.fromValue] does: a
  /// value the app does not recognise should hide one meal, not break a feed.
  static MealCategory? fromValue(String value) {
    for (final MealCategory category in MealCategory.values) {
      if (category.value == value) {
        return category;
      }
    }
    return null;
  }
}

/// How hard a meal is to cook.
///
/// Mirrors the `difficulty` enum. Presented as a word rather than a number of
/// stars — "medium" is a claim someone can argue with, three stars out of five
/// pretends to a precision the data does not have.
enum Difficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const Difficulty(this.label);

  final String label;

  String get value => name;

  static Difficulty? fromValue(String value) {
    for (final Difficulty difficulty in Difficulty.values) {
      if (difficulty.value == value) {
        return difficulty;
      }
    }
    return null;
  }
}

/// Where an ingredient sits in a shop (docs/DATABASE.md §4.6).
///
/// The `ingredients.category` column's eight values. They exist to group a pantry
/// and a grocery list the way the shop is laid out rather than alphabetically — a
/// list that reads *protein, vegetables, dairy* is a list you can walk, and one
/// sorted A-to-Z sends you back across the aisle four times.
///
/// `other` is a real answer and not a failure. Anything the app adds on somebody's
/// behalf lands here, because guessing that "kangkong" is a vegetable is easy and
/// guessing that "bagoong" is a condiment is not, and a wrong aisle is worse than
/// no aisle.
enum IngredientCategory {
  protein('Protein'),
  vegetable('Vegetables'),
  fruit('Fruit'),
  grain('Grains'),
  dairy('Dairy'),
  spice('Spices'),
  condiment('Condiments'),
  other('Everything else');

  const IngredientCategory(this.label);

  /// Plural, because it labels a group rather than a thing.
  final String label;

  String get value => name;

  static IngredientCategory fromValue(String? value) {
    for (final IngredientCategory category in IngredientCategory.values) {
      if (category.value == value) {
        return category;
      }
    }
    // Unrecognised rather than throwing: a category added to the database ahead
    // of the app should show up in the last group, not break the screen.
    return IngredientCategory.other;
  }
}
