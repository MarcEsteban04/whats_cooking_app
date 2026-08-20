import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:whats_cooking/features/onboarding/domain/repositories/onboarding_repository.dart';

/// [OnboardingRepository] backed by Supabase.
///
/// Writes to two tables: `user_preferences` for the answers and `profiles` for
/// the name and the completion flag. Both rows already exist — the signup trigger
/// created them (supabase/migrations/…_functions_triggers.sql) — so these are
/// updates rather than inserts, and a missing row means something upstream failed
/// rather than something to create here.
class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _userId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      // Unreachable through the router, which only admits an authenticated
      // session to the onboarding zone. Explicit anyway: silently writing
      // nothing would look like a save that worked.
      throw const AuthFailureException(
        message: 'Please sign in again',
        detail: 'onboarding ran with no authenticated user',
      );
    }
    return id;
  }

  @override
  Future<OnboardingAnswers> load() {
    return RemoteCall.guard(
      () async {
        final String id = _userId;

        final Map<String, dynamic>? preferences = await _client
            .from(_preferencesTable)
            .select(
              'favorite_cuisines, dietary_tags, default_budget, '
              'max_cooking_time, preferred_servings, '
              'disliked_ingredient_names',
            )
            .eq('user_id', id)
            .maybeSingle();

        final Map<String, dynamic>? profile = await _client
            .from(_profilesTable)
            .select('display_name')
            .eq('id', id)
            .maybeSingle();

        return OnboardingAnswers(
          displayName: profile?['display_name'] as String?,
          preferences: preferencesFrom(preferences),
        );
      },
      label: 'loadOnboarding',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> save(OnboardingAnswers answers) {
    return RemoteCall.guard(
      () async {
        final String id = _userId;

        await _client
            .from(_preferencesTable)
            .update(columnsFor(answers.preferences))
            .eq('user_id', id);

        final String? name = answers.displayName?.trim();
        if (name != null && name.isNotEmpty) {
          // Only when given. The signup trigger already derived a name from the
          // email address, and overwriting it with an empty string would leave
          // the user with no name at all.
          await _client
              .from(_profilesTable)
              .update(<String, dynamic>{'display_name': name})
              .eq('id', id);
        }
      },
      label: 'saveOnboarding',
      // Idempotent, so a retry is safe — and this runs after every step, where a
      // transient failure losing an answer is exactly what
      // docs/USER_FLOWS.md §5 forbids.
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> complete() {
    return RemoteCall.guard(
      () => _client
          .from(_profilesTable)
          .update(<String, dynamic>{'onboarding_completed': true})
          .eq('id', _userId),
      label: 'completeOnboarding',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  /// The `user_preferences` columns for [preferences].
  ///
  /// Shared with the profile repository, which writes the same six fields from
  /// the same model — one mapping, so the two cannot disagree about which column
  /// a dietary tag goes in.
  static Map<String, dynamic> columnsFor(FoodPreferences preferences) {
    return <String, dynamic>{
      'favorite_cuisines': preferences.favouriteCuisines
          .map((Cuisine cuisine) => cuisine.value)
          .toList(),
      'dietary_tags': preferences.dietaryTags
          .map((DietaryTag tag) => tag.value)
          .toList(),
      'default_budget': preferences.budget,
      'max_cooking_time': preferences.maxCookingTimeMinutes,
      'preferred_servings': preferences.preferredServings,
      // Names rather than ids: the ingredient catalogue cannot match what someone
      // types on their first day, so the text is kept and reconciled later
      // (supabase/migrations/…_onboarding_dislikes.sql).
      'disliked_ingredient_names': preferences.dislikedFoods,
    };
  }

  /// [FoodPreferences] from a `user_preferences` row.
  static FoodPreferences preferencesFrom(Map<String, dynamic>? row) {
    if (row == null) {
      return const FoodPreferences();
    }

    return FoodPreferences(
      // Unrecognised values are dropped rather than throwing: a cuisine retired
      // from the app should not make the screen unopenable for whoever picked it.
      favouriteCuisines: _stringList(row['favorite_cuisines'])
          .map(Cuisine.fromValue)
          .whereType<Cuisine>()
          .toSet(),
      dietaryTags: _stringList(row['dietary_tags'])
          .map(DietaryTag.fromValue)
          .whereType<DietaryTag>()
          .toSet(),
      dislikedFoods: _stringList(row['disliked_ingredient_names']),
      // numeric(10,2) arrives as a num; the UI works in whole pesos.
      budget: (row['default_budget'] as num?)?.round(),
      maxCookingTimeMinutes: (row['max_cooking_time'] as num?)?.toInt(),
      // `preferred_servings` is `not null default 2`, so this genuinely cannot
      // tell "chose me and my partner" from "never answered". It resolves to the
      // matching option, pre-selecting the likelier answer rather than losing a
      // real one — and the household branch fires from an explicit tap, never
      // from loaded state, so a pre-selected tile cannot push anyone into setup
      // they did not ask for.
      cookingFor: CookingFor.fromServings(
        (row['preferred_servings'] as num?)?.toInt(),
      ),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((Object? item) => '$item').toList();
    }
    return const <String>[];
  }

  static const String _preferencesTable = 'user_preferences';
  static const String _profilesTable = 'profiles';
}
