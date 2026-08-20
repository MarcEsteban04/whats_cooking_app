import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';

/// [MealRepository] backed by PostgREST.
///
/// Every filter is applied **on the server**. That is not an optimisation, it is
/// what makes pagination correct: if any condition were applied in Dart after
/// the rows arrived, the server's idea of "the next twenty" would no longer
/// match the app's, and the reader would get duplicates and gaps. It is also why
/// migration 0015 exists — `cost_per_serving` had to become a column before the
/// budget filter could be a server-side one.
class SupabaseMealRepository implements MealRepository {
  SupabaseMealRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MealPage> search({
    required MealQuery query,
    int offset = 0,
    int limit = kMealPageSize,
  }) {
    return RemoteCall.guard(
      () async {
        // Filters first, transforms after: PostgREST's builder stops accepting
        // `eq` and friends once `order` or `range` has been called.
        PostgrestFilterBuilder<PostgrestList> filtered = _client
            .from(_table)
            .select(_columns);

        // No visibility filter, on purpose. The `read visible meals` policy
        // already returns exactly "public, or my household's" and nothing else,
        // so filtering here would either duplicate it or — worse — disagree with
        // it. It also means a meal you just wrote appears in the feed without the
        // client having to know its household id.

        final String search = _escapeLike(query.search);
        if (search.isNotEmpty) {
          // Uses the trigram index on `name` (migration 0008).
          filtered = filtered.ilike('name', '%$search%');
        }

        if (query.cuisines.isNotEmpty) {
          filtered = filtered.inFilter('cuisine', <String>[
            for (final Cuisine cuisine in query.cuisines) cuisine.value,
          ]);
        }

        if (query.categories.isNotEmpty) {
          filtered = filtered.inFilter('category', <String>[
            for (final MealCategory category in query.categories)
              category.value,
          ]);
        }

        if (query.maxCookingTimeMinutes case final int minutes) {
          filtered = filtered.lte('cooking_time_minutes', minutes);
        }

        if (query.maxCostPerServing case final int pesos) {
          filtered = filtered.lte('cost_per_serving', pesos);
        }

        // One row more than asked for. Its presence is the answer to "is there
        // another page", and it costs one row rather than a second round trip.
        final PostgrestList rows = await filtered
            .order(query.sort.column, ascending: query.sort.ascending)
            .order(MealSort.tiebreaker)
            .range(offset, offset + limit);

        final bool hasMore = rows.length > limit;

        return MealPage(
          meals: <Meal>[
            for (final Map<String, dynamic> row in rows.take(limit))
              Meal.fromRow(row),
          ],
          hasMore: hasMore,
        );
      },
      label: 'meals.search',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Meal> create(MealDraft draft) {
    return RemoteCall.guard(
      () async {
        final String userId = _requireUserId();

        // The household the meal belongs to. Read rather than assumed: the
        // `create own meals` policy checks membership, so guessing wrong is a
        // rejected insert rather than a wrong row.
        final Map<String, dynamic>? profile = await _client
            .from('profiles')
            .select('active_household_id')
            .eq('id', userId)
            .maybeSingle();

        final String? householdId = profile?['active_household_id'] as String?;
        if (householdId == null) {
          // Every account gets a personal household on signup by trigger
          // (docs/ARCHITECTURE.md §6.2), so this means provisioning has not been
          // observed yet rather than that the user has no household.
          throw const ValidationException(
            message:
                'Your kitchen is still being set up. Try again in a moment.',
            detail: 'profiles.active_household_id was null',
          );
        }

        final Map<String, dynamic> row = await _client
            .from(_table)
            .insert(<String, Object?>{
              'name': draft.name.trim(),
              if (draft.description.trim().isNotEmpty)
                'description': draft.description.trim(),
              'cuisine': draft.cuisine.value,
              'category': draft.category.value,
              'difficulty': draft.difficulty.value,
              'cooking_time_minutes': draft.cookingTimeMinutes,
              'estimated_cost': draft.estimatedCost,
              'servings': draft.servings,
              'instructions': draft.filledInstructions,
              // Both are required by the visibility constraint and by the
              // insert policy, and neither is the caller's choice.
              'is_public': false,
              'household_id': householdId,
              'created_by': userId,
            })
            .select(_columns)
            .single();

        final Meal meal = Meal.fromRow(row);

        await _attachIngredients(meal.id, draft.filledIngredients);

        return meal;
      },
      label: 'meals.create',
      // No retry. A retried insert is a duplicate recipe, and the failure this
      // would be retrying — a rejected policy check or a constraint violation —
      // is not one a second attempt fixes.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  /// Resolves each ingredient name to a row, adding any that are new, then links
  /// them to the meal.
  ///
  /// Names are matched case-insensitively against the shared vocabulary and
  /// added when missing, which is what the `authenticated add ingredients` policy
  /// is for: "Users must never be blocked because our ingredient list is
  /// incomplete" (supabase/migrations/…_rls_policies.sql).
  Future<void> _attachIngredients(
    String mealId,
    List<DraftIngredient> ingredients,
  ) async {
    if (ingredients.isEmpty) {
      return;
    }

    // One round trip for the lookup rather than one per ingredient.
    final List<String> names = <String>[
      for (final DraftIngredient ingredient in ingredients)
        _normaliseIngredient(ingredient.name),
    ];

    final PostgrestList existing = await _client
        .from('ingredients')
        .select('id, name')
        .inFilter('name', names);

    final Map<String, String> idByName = <String, String>{
      for (final Map<String, dynamic> row in existing)
        row['name'] as String: row['id'] as String,
    };

    final List<String> missing = names
        .where((String name) => !idByName.containsKey(name))
        .toSet()
        .toList();

    if (missing.isNotEmpty) {
      final PostgrestList inserted = await _client
          .from('ingredients')
          .insert(<Map<String, Object?>>[
            for (final String name in missing)
              <String, Object?>{
                'name': name,
                // The vocabulary's categories describe where a thing sits in a
                // shop, and the person typing "kangkong" has not been asked. A
                // wrong guess would be worse than an honest "other".
                'category': 'other',
                'default_unit': _unitFor(name, ingredients),
              },
          ])
          .select('id, name');

      for (final Map<String, dynamic> row in inserted) {
        idByName[row['name'] as String] = row['id'] as String;
      }
    }

    await _client.from('meal_ingredients').insert(<Map<String, Object?>>[
      for (final DraftIngredient ingredient in ingredients)
        <String, Object?>{
          'meal_id': mealId,
          'ingredient_id': idByName[_normaliseIngredient(ingredient.name)],
          'quantity': ingredient.quantity,
          'unit': ingredient.unit,
          'is_optional': ingredient.isOptional,
        },
    ]);
  }

  /// The unit a newly-added ingredient defaults to.
  ///
  /// The one the user just chose for it, which is a better guess than ours.
  static String _unitFor(String name, List<DraftIngredient> ingredients) {
    for (final DraftIngredient ingredient in ingredients) {
      if (_normaliseIngredient(ingredient.name) == name) {
        return ingredient.unit;
      }
    }
    return 'pc';
  }

  /// `ingredients.name` is check-constrained to `lower(trim(name))`.
  static String _normaliseIngredient(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _requireUserId() {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      // Reached only if a screen behind the auth guard called this without a
      // session, which is a programming error rather than a runtime condition.
      throw const AuthFailureException(
        message: 'Please sign in again',
        detail: 'meals.create called with no session',
        isSessionExpired: true,
      );
    }
    return id;
  }

  /// Neutralises the characters `LIKE` and PostgREST treat as syntax.
  ///
  /// Without this, searching for `100%` matches every meal, `_` matches any
  /// single character, and a comma or a bracket can change how PostgREST parses
  /// the filter rather than what it looks for. None of that is a security hole —
  /// PostgREST parameterises the value — but all of it is a search that quietly
  /// does something other than what was typed.
  static String _escapeLike(String term) {
    final String trimmed = term.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'[%_,()*\\"]'), ' ').trim();
  }

  static const String _table = 'meals';

  /// Named rather than `*`, so a column added to the table later does not
  /// silently start crossing the wire on every page of the feed.
  static const String _columns =
      'id, name, description, cuisine, category, difficulty, '
      'cooking_time_minutes, estimated_cost, servings, calories, '
      'instructions, dietary_tags, tags, is_public';
}
