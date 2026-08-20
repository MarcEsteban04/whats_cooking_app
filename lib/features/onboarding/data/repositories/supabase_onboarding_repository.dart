import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/core/utils/logger.dart';
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

        final Map<String, dynamic>? preferences = await readPreferences(
          _client,
          id,
        );

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

        await writePreferences(_client, id, answers.preferences);

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

  /// Every `user_preferences` column this build reads.
  static const String preferenceColumns =
      'favorite_cuisines, dietary_tags, default_budget, '
      'max_cooking_time, preferred_servings, repetition_window_days, '
      'disliked_ingredient_names';

  /// The same list, minus anything a database might not have yet.
  ///
  /// See [readPreferences] — this exists so a build can land before its
  /// migration and still work.
  static const String _establishedPreferenceColumns =
      'favorite_cuisines, dietary_tags, default_budget, '
      'max_cooking_time, preferred_servings, '
      'disliked_ingredient_names';

  /// Columns added recently enough that a database may not have them.
  ///
  /// Emptied as migrations become universal. A name lingering here after
  /// everything has been migrated costs one fallback path that never runs, which
  /// is cheap; a name *missing* from it costs a broken profile screen.
  static const Set<String> _recentColumns = <String>{
    // Migration 0019, Sprint 32.
    'repetition_window_days',
  };

  /// Reads the preferences row, tolerating a database that has not caught up.
  ///
  /// **Why this is not just a `select`.** Migrations here are applied by hand, so
  /// the app and the schema move independently — and a build that names a column
  /// the database does not have gets a 400 on the whole query, not a null for
  /// that field. Without this, shipping Sprint 32's code before pasting Sprint
  /// 32's migration took out the entire profile read: no name, no budget, no
  /// dietary needs, on every screen that asks.
  ///
  /// So a `42703` (undefined column) is retried once without the recent
  /// additions, and shouts in the log. Everything else rethrows — this is a
  /// narrow allowance for one ordering problem, not a general "try again with
  /// less".
  static Future<Map<String, dynamic>?> readPreferences(
    supabase.SupabaseClient client,
    String userId,
  ) async {
    try {
      return await client
          .from(_preferencesTable)
          .select(preferenceColumns)
          .eq('user_id', userId)
          .maybeSingle();
    } on supabase.PostgrestException catch (error) {
      if (!_isUndefinedColumn(error)) {
        rethrow;
      }

      AppLog.warning(
        'user_preferences is missing a column this build reads — apply the '
        'latest migration in supabase/migrations. Falling back for now.',
        name: 'preferences',
        data: <String, Object?>{'expected': _recentColumns.join(', ')},
      );

      return client
          .from(_preferencesTable)
          .select(_establishedPreferenceColumns)
          .eq('user_id', userId)
          .maybeSingle();
    }
  }

  /// Writes the preferences row, tolerating the same lag.
  ///
  /// The write has the same problem as the read and one extra wrinkle: dropping a
  /// column here means an answer the user gave is *silently not saved*. So it
  /// says so in the log, loudly, rather than looking like a save that worked.
  static Future<void> writePreferences(
    supabase.SupabaseClient client,
    String userId,
    FoodPreferences preferences,
  ) async {
    final Map<String, dynamic> columns = columnsFor(preferences);

    try {
      await client
          .from(_preferencesTable)
          .update(columns)
          .eq('user_id', userId);
      return;
    } on supabase.PostgrestException catch (error) {
      if (!_isUndefinedColumn(error)) {
        rethrow;
      }
    }

    AppLog.warning(
      'user_preferences is missing a column this build writes — the following '
      'were NOT saved. Apply the latest migration.',
      name: 'preferences',
      data: <String, Object?>{'dropped': _recentColumns.join(', ')},
    );

    await client
        .from(_preferencesTable)
        .update(<String, dynamic>{
          for (final MapEntry<String, dynamic> entry in columns.entries)
            if (!_recentColumns.contains(entry.key)) entry.key: entry.value,
        })
        .eq('user_id', userId);
  }

  /// Whether [error] is PostgREST saying a column does not exist.
  ///
  /// **`code` is the HTTP status, not the SQLSTATE.** A missing column arrives as
  /// `code: 400` with the real `42703` buried in `message`, which is the raw
  /// PostgREST body as a JSON string — so a check against `code` alone silently
  /// never matches, which is exactly the bug this replaced. Both are inspected,
  /// because the SDK's shape here is not something to rely on.
  static bool _isUndefinedColumn(supabase.PostgrestException error) {
    return error.code == _undefinedColumn ||
        error.message.contains(_undefinedColumn);
  }

  /// Postgres SQLSTATE for `undefined_column`.
  static const String _undefinedColumn = '42703';

  /// The `user_preferences` columns for [preferences].
  ///
  /// Shared with the profile repository, which writes the same fields from the
  /// same model — one mapping, so the two cannot disagree about which column a
  /// dietary tag goes in.
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
      // Null is meaningful here and 0 is not the same thing: null means "use
      // the app default", 0 means "we do not mind repeats". Sent either way so
      // clearing the answer is possible.
      'repetition_window_days': preferences.repetitionWindowDays,
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
      // Null stays null. It means "use the app default", which the engine treats
      // differently from the 0 that means "we do not mind repeats".
      repetitionWindowDays: (row['repetition_window_days'] as num?)?.toInt(),
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
