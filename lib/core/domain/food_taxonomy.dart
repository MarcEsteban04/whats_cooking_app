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
  filipino('Filipino', '🇵🇭'),
  japanese('Japanese', '🍣'),
  korean('Korean', '🍲'),
  chinese('Chinese', '🥡'),
  thai('Thai', '🌶️'),
  vietnamese('Vietnamese', '🍜'),
  italian('Italian', '🍝'),
  mexican('Mexican', '🌮'),
  american('American', '🍔'),
  indian('Indian', '🍛'),
  mediterranean('Mediterranean', '🫒'),
  other('Something else', '🍽️');

  const Cuisine(this.label, this.emoji);

  final String label;
  final String emoji;

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

  /// The emoji shown on this option's tile.
  String get emoji => switch (this) {
    CookingFor.justMe => '🍽️',
    CookingFor.withPartner => '❤️',
    CookingFor.family => '👨‍👩‍👧',
  };
}
