import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/constants/app_constants.dart';
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

        return _answersFrom(preferences: preferences, profile: profile);
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
            .update(<String, dynamic>{
              'favorite_cuisines': answers.favouriteCuisines
                  .map((Cuisine cuisine) => cuisine.value)
                  .toList(),
              'dietary_tags': answers.dietaryTags
                  .map((DietaryTag tag) => tag.value)
                  .toList(),
              'default_budget': answers.budget,
              'max_cooking_time': answers.maxCookingTimeMinutes,
              'preferred_servings': answers.preferredServings,
              // Names rather than ids: the ingredient catalogue cannot match what
              // someone types on their first day, so the text is kept and reconciled
              // later (supabase/migrations/…_onboarding_dislikes.sql).
              'disliked_ingredient_names': answers.dislikedFoods,
            })
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
      // transient failure losing an answer is exactly what §5 forbids.
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

  OnboardingAnswers _answersFrom({
    required Map<String, dynamic>? preferences,
    required Map<String, dynamic>? profile,
  }) {
    if (preferences == null && profile == null) {
      return const OnboardingAnswers();
    }

    final List<String> cuisines = _stringList(
      preferences?['favorite_cuisines'],
    );
    final List<String> tags = _stringList(preferences?['dietary_tags']);

    return OnboardingAnswers(
      displayName: profile?['display_name'] as String?,
      // Unknown values are dropped rather than crashing the resume: a cuisine
      // removed from the app should not make onboarding unopenable for whoever
      // had picked it.
      favouriteCuisines: cuisines.map(_cuisineFor).whereType<Cuisine>().toSet(),
      dietaryTags: tags.map(_dietaryTagFor).whereType<DietaryTag>().toSet(),
      dislikedFoods: _stringList(preferences?['disliked_ingredient_names']),
      // numeric(10,2) arrives as a num; the UI works in whole pesos.
      budget: (preferences?['default_budget'] as num?)?.round(),
      maxCookingTimeMinutes: (preferences?['max_cooking_time'] as num?)
          ?.toInt(),
      cookingFor: _cookingForServings(
        (preferences?['preferred_servings'] as num?)?.toInt(),
      ),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((Object? item) => '$item').toList();
    }
    return const <String>[];
  }

  static Cuisine? _cuisineFor(String value) {
    for (final Cuisine cuisine in Cuisine.values) {
      if (cuisine.value == value) {
        return cuisine;
      }
    }
    return null;
  }

  static DietaryTag? _dietaryTagFor(String value) {
    for (final DietaryTag tag in DietaryTag.values) {
      if (tag.value == value) {
        return tag;
      }
    }
    return null;
  }

  /// The [CookingFor] whose servings match [servings], if any.
  ///
  /// `preferred_servings` is `not null default 2`, so a resumed run genuinely
  /// **cannot** tell "chose me and my partner" from "never answered". This
  /// resolves it to the matching option, which pre-selects the likelier answer
  /// rather than losing a real one.
  ///
  /// That ambiguity is contained deliberately: the household branch fires from an
  /// explicit tap in the UI, never from loaded state, so a pre-selected tile
  /// cannot push someone into household setup they did not ask for.
  static CookingFor? _cookingForServings(int? servings) {
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

  static const String _preferencesTable = 'user_preferences';
  static const String _profilesTable = 'profiles';
}
