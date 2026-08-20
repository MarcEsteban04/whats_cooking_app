import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// The answers gathered during onboarding.
///
/// A name plus the shared [FoodPreferences]. The preferences are *not* redefined
/// here: the profile screen edits the same six fields, and docs/COMPONENTS.md
/// §18b's reason for sharing the editors applies just as much to the model behind
/// them — two copies would drift the moment one gained a seventh field.
///
/// The name sits outside them because it belongs to `profiles`, not to
/// `user_preferences`, and because it is the one answer that is not a preference.
class OnboardingAnswers {
  const OnboardingAnswers({
    this.displayName,
    this.preferences = const FoodPreferences(),
  });

  final String? displayName;
  final FoodPreferences preferences;

  /// Whether anything at all has been answered.
  ///
  /// docs/USER_FLOWS.md §5's bar for the whole flow: an abandoned run should
  /// still leave the app smarter than a blank one.
  bool get hasAnyAnswer =>
      (displayName != null && displayName!.trim().isNotEmpty) ||
      preferences.hasAny;

  /// Servings to store.
  int get preferredServings => preferences.preferredServings;

  /// Whether the household branch should be offered.
  bool get invitesHousehold =>
      preferences.cookingFor?.invitesHousehold ?? false;

  OnboardingAnswers copyWith({
    String? displayName,
    FoodPreferences? preferences,
  }) {
    return OnboardingAnswers(
      displayName: displayName ?? this.displayName,
      preferences: preferences ?? this.preferences,
    );
  }

  /// Convenience for the steps, each of which edits one preference field.
  OnboardingAnswers withPreferences({
    Set<Cuisine>? favouriteCuisines,
    List<String>? dislikedFoods,
    Set<DietaryTag>? dietaryTags,
    int? budget,
    int? maxCookingTimeMinutes,
    CookingFor? cookingFor,
    bool clearBudget = false,
    bool clearMaxCookingTime = false,
  }) {
    return copyWith(
      preferences: preferences.copyWith(
        favouriteCuisines: favouriteCuisines,
        dislikedFoods: dislikedFoods,
        dietaryTags: dietaryTags,
        budget: budget,
        maxCookingTimeMinutes: maxCookingTimeMinutes,
        cookingFor: cookingFor,
        clearBudget: clearBudget,
        clearMaxCookingTime: clearMaxCookingTime,
      ),
    );
  }
}
