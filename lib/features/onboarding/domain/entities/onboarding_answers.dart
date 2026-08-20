/// The cuisines the catalogue knows about.
///
/// Mirrors the `check` constraint on `meals.cuisine`
/// (supabase/migrations/…_meals_ingredients.sql). Stored as the lower-case
/// database value and displayed as [label], so the wire format and the copy can
/// change independently — and a typo here fails at insert rather than silently
/// saving a cuisine nothing matches.
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
}

/// Who the user cooks for.
///
/// Drives `user_preferences.preferred_servings`, and decides whether onboarding
/// offers the household branch — docs/USER_FLOWS.md §5 puts that prompt here
/// because it is "the highest-intent moment for couple mode".
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
}

/// The answers gathered during onboarding.
///
/// **Every field is nullable or empty-able, and that is the point.** Every step
/// is skippable (docs/USER_FLOWS.md §5, US-A-06), so "not answered" has to be
/// representable — and distinguishable from "answered with nothing". A budget of
/// null means *no preference*; the recommendation engine treats those very
/// differently from a budget of zero.
class OnboardingAnswers {
  const OnboardingAnswers({
    this.displayName,
    this.favouriteCuisines = const <Cuisine>{},
    this.dislikedFoods = const <String>[],
    this.dietaryTags = const <DietaryTag>{},
    this.budget,
    this.maxCookingTimeMinutes,
    this.cookingFor,
  });

  final String? displayName;
  final Set<Cuisine> favouriteCuisines;

  /// Foods to avoid, as the user typed them.
  ///
  /// Free text, not ingredient ids. `user_preferences.disliked_ingredients`
  /// holds ids, which is the right long-term shape, but onboarding runs before
  /// the ingredient catalogue can match what someone types — so the names are
  /// stored alongside in `disliked_ingredient_names` and reconciled later
  /// (supabase/migrations/…_onboarding_dislikes.sql).
  final List<String> dislikedFoods;

  final Set<DietaryTag> dietaryTags;

  /// Null means no budget preference, which is not the same as zero.
  final int? budget;

  /// Null means no time limit.
  final int? maxCookingTimeMinutes;

  final CookingFor? cookingFor;

  /// Servings to store, defaulting to the product's assumption of two.
  int get preferredServings =>
      cookingFor?.servings ?? _defaultPreferredServings;

  /// Whether anything at all has been answered.
  ///
  /// Used to decide whether an abandoned run left the app smarter than a blank
  /// one — §5's stated bar for the whole flow.
  bool get hasAnyAnswer =>
      (displayName != null && displayName!.trim().isNotEmpty) ||
      favouriteCuisines.isNotEmpty ||
      dislikedFoods.isNotEmpty ||
      dietaryTags.isNotEmpty ||
      budget != null ||
      maxCookingTimeMinutes != null ||
      cookingFor != null;

  OnboardingAnswers copyWith({
    String? displayName,
    Set<Cuisine>? favouriteCuisines,
    List<String>? dislikedFoods,
    Set<DietaryTag>? dietaryTags,
    int? budget,
    int? maxCookingTimeMinutes,
    CookingFor? cookingFor,
    bool clearBudget = false,
    bool clearMaxCookingTime = false,
  }) {
    return OnboardingAnswers(
      displayName: displayName ?? this.displayName,
      favouriteCuisines: favouriteCuisines ?? this.favouriteCuisines,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      // Explicit clears, because `copyWith(budget: null)` cannot mean "unset" in
      // Dart — null is indistinguishable from "not passed". Skipping the budget
      // step has to be able to clear a previously chosen one.
      budget: clearBudget ? null : (budget ?? this.budget),
      maxCookingTimeMinutes: clearMaxCookingTime
          ? null
          : (maxCookingTimeMinutes ?? this.maxCookingTimeMinutes),
      cookingFor: cookingFor ?? this.cookingFor,
    );
  }

  static const int _defaultPreferredServings = 2;
}
