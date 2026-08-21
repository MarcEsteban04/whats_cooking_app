import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/meals/data/datasources/meal_cache.dart';
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
  SupabaseMealRepository(this._client, {this.cache = const MealCache()});

  final SupabaseClient _client;

  /// Where the last unfiltered first page is kept (Sprint 27).
  final MealCache cache;

  /// The catalogue's first page, from the network, falling back to the disk.
  ///
  /// Read-through, as docs/ARCHITECTURE.md §5 specifies, and narrower than it
  /// sounds: only the **unfiltered first page** is written or read. A filtered
  /// page is cheap to fetch again and no use offline — someone who filtered for
  /// "under 30 minutes" and lost signal needs *something to cook*, not their
  /// something — and caching every permutation would buy an invalidation problem
  /// in exchange for that.
  ///
  /// The fallback is deliberately quiet about nothing. `MealPage.cachedAt` comes
  /// back set, the screen says so, and `hasMore` is false because there is no
  /// page two on the disk.
  @override
  Future<MealPage> search({
    required MealQuery query,
    int offset = 0,
    int limit = kMealPageSize,
  }) async {
    // Read and write are gated differently on purpose.
    //
    // Anything unfiltered starting at row zero can be *answered* from the stored
    // page — including the roulette's pool request, which is how spinning works
    // with no signal (docs/USER_FLOWS.md §18).
    //
    // Only a request for exactly one page may *replace* it, because only that
    // request is the thing being cached. The roulette asks for the whole
    // catalogue at once and excludes what it has already offered this session;
    // storing that as "the first page" would persist a catalogue with meals
    // missing for no reason a later reader could see.
    final bool canReadCache = offset == 0 && !query.hasFilters;
    final bool canWriteCache = canReadCache && limit == kMealPageSize;

    try {
      final MealPage page = await _search(
        query: query,
        offset: offset,
        limit: limit,
      );

      if (canWriteCache) {
        // Not awaited. A slow disk must not hold up a page that has already
        // arrived, and a failed write costs a cache hit rather than a screen.
        unawaited(cache.writeFeed(page.meals, now: DateTime.now()));
      }

      return page;
    } on AppException catch (failure) {
      // Only the two failures the disk is an answer to. A 5xx is not the same
      // as being offline, but the response is: the device has a catalogue and
      // the server cannot give it one. Auth and permission failures are
      // excluded on purpose — the fix there is signing in, and yesterday's meals
      // would hide that from the person who needs to see it.
      if (failure is! NetworkException && failure is! ServerException) {
        rethrow;
      }

      final MealPage? cached = await _cachedPage(query, canRead: canReadCache);
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  /// The stored page, with this reader's exclusions applied, or null.
  Future<MealPage?> _cachedPage(
    MealQuery query, {
    required bool canRead,
  }) async {
    if (!canRead) {
      return null;
    }

    final CachedMeals? cached = await cache.readFeed(now: DateTime.now());
    if (cached == null) {
      return null;
    }

    // The one place in this class where a condition is applied in Dart, and it
    // is safe for the reason the others are not: there is no page two behind a
    // cache, so nothing can slip through a gap between pages. It is also
    // necessary — the page was stored under whatever the exclusions were then,
    // and a meal hidden since must not come back through the cache (US-B-07).
    final List<Meal> visible = query.excludedMealIds.isEmpty
        ? cached.meals
        : cached.meals
              .where((Meal meal) => !query.excludedMealIds.contains(meal.id))
              .toList();

    return MealPage(meals: visible, hasMore: false, cachedAt: cached.storedAt);
  }

  Future<MealPage> _search({
    required MealQuery query,
    required int offset,
    required int limit,
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

        // The cookable-now filter (Sprint 41). Applied server-side like every
        // other condition here, because the feed is paged: a page filtered in
        // Dart leaves the server counting twenty rows where the reader sees
        // nineteen, and the next page skips a meal.
        if (query.onlyMealIds case final Set<String> allowed) {
          if (allowed.isEmpty) {
            // "On, and nothing qualifies" is a real state and has to show an
            // empty feed. `in.()` with no values is a query PostgREST rejects, so
            // the answer is given without asking.
            return const MealPage(meals: <Meal>[], hasMore: false);
          }
          filtered = filtered.inFilter('id', allowed.toList());
        }

        if (query.excludedMealIds.isNotEmpty) {
          // The dislikes, as a hard exclusion (Sprint 25). Server-side like
          // every other condition here, and for the sharpest version of the
          // same reason: a hidden meal dropped from a page in Dart would leave
          // a nineteen-row page whose offset the server still counts as twenty,
          // so the next page would skip a meal. `not.in` keeps the two agreed.
          //
          // Sent as a literal list rather than a join against `disliked_meals`,
          // because the set is one person's dislikes of a sixty-meal catalogue —
          // tens of ids at the outside. If it ever reaches the hundreds this
          // becomes a URL-length problem and wants a view or an RPC instead;
          // the scoring engine will likely take it there anyway (Sprint 30).
          filtered = filtered.not(
            'id',
            'in',
            '(${query.excludedMealIds.join(',')})',
          );
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

  @override
  Future<Meal> update(String id, MealDraft draft) {
    return RemoteCall.guard(
      () async {
        // Named columns rather than a whole-row write. `calories`,
        // `dietary_tags` and `tags` are not on the form, and sending a default
        // for a field nobody was shown is how a save quietly loses data.
        //
        // `is_public`, `household_id` and `created_by` are absent for a
        // different reason: they are not the caller's to change, and omitting
        // them means a bug here cannot move a recipe into the public catalogue
        // or hand it to another household.
        final Map<String, dynamic> row = await _client
            .from(_table)
            .update(<String, Object?>{
              'name': draft.name.trim(),
              // Explicit null rather than omitted: clearing a description has
              // to be possible, and leaving the key out would silently keep it.
              'description': draft.description.trim().isEmpty
                  ? null
                  : draft.description.trim(),
              'cuisine': draft.cuisine.value,
              'category': draft.category.value,
              'difficulty': draft.difficulty.value,
              'cooking_time_minutes': draft.cookingTimeMinutes,
              'estimated_cost': draft.estimatedCost,
              'servings': draft.servings,
              'instructions': draft.filledInstructions,
            })
            .eq('id', id)
            .select(_columns)
            .maybeSingle()
            .then((Map<String, dynamic>? result) {
              if (result == null) {
                // No rows updated. `update own meals` is author-scoped, so this
                // is either someone else's recipe or one already deleted — and
                // RLS makes those indistinguishable, which is the right
                // behaviour rather than a gap to close.
                throw const NotFoundException(
                  message: 'We could not save that meal',
                  detail: 'meals.update matched no row the caller may write',
                );
              }
              return result;
            });

        // Replaced, not merged. Removing an ingredient has to mean something,
        // and matching lines by a name the user is also editing would be
        // guesswork. The delete goes first so a failure leaves the old list
        // intact rather than a doubled one.
        await _client.from('meal_ingredients').delete().eq('meal_id', id);
        await _attachIngredients(id, draft.filledIngredients);

        return Meal.fromRow(row);
      },
      label: 'meals.update',
      // No retry, for the same reason `create` has none: the failures this
      // would retry are a rejected policy check or a constraint violation, and
      // a second attempt fixes neither.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> delete(String id) {
    return RemoteCall.guard(
      () async {
        // No check that the row exists first. `delete own meals` already
        // restricts this to the author, and a delete that matches nothing is
        // the outcome the caller wanted anyway — the meal is gone.
        await _client.from(_table).delete().eq('id', id);
      },
      label: 'meals.delete',
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<List<Meal>> mine() {
    return RemoteCall.guard(
      () async {
        // `is_public = false` is the whole filter. The `read visible meals`
        // policy already returns "public, or my household's", so the non-public
        // half of that is exactly this household's own writing — no household
        // id needed, and no way to accidentally ask for another one's.
        final PostgrestList rows = await _client
            .from(_table)
            .select(_detailColumns)
            .eq('is_public', false)
            .order('created_at', ascending: false)
            .order(MealSort.tiebreaker);

        return <Meal>[
          for (final Map<String, dynamic> row in rows) Meal.fromRow(row),
        ];
      },
      label: 'meals.mine',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Meal> byId(String id) {
    return RemoteCall.guard(
      () async {
        // `maybeSingle` rather than `single`: Row Level Security makes a meal
        // this household may not see indistinguishable from one that does not
        // exist — both come back as no rows — and that is the right behaviour.
        // `single` would raise a PostgREST error where a not-found is what the
        // screen wants to show.
        final Map<String, dynamic>? row = await _client
            .from(_table)
            .select(_detailColumns)
            .eq('id', id)
            .maybeSingle();

        if (row == null) {
          throw const NotFoundException(message: 'We could not find that meal');
        }

        return Meal.fromRow(row);
      },
      label: 'meals.byId',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<List<Meal>> byIds(Set<String> ids) {
    if (ids.isEmpty) {
      // No request at all. `in.()` with an empty list is a query PostgREST
      // rejects, and the answer is knowable without asking.
      return Future<List<Meal>>.value(const <Meal>[]);
    }

    return RemoteCall.guard(
      () async {
        final PostgrestList rows = await _client
            .from(_table)
            .select(_columns)
            .inFilter('id', ids.toList())
            .order('name');

        return <Meal>[
          for (final Map<String, dynamic> row in rows) Meal.fromRow(row),
        ];
      },
      label: 'meals.byIds',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Set<String>> mealsBlockedByDislikes() {
    return RemoteCall.guard(
      () async {
        // An RPC rather than a filter on the meal query. "No meal containing any
        // of these" is a join through `meal_ingredients`, which PostgREST cannot
        // express as a negated filter on `meals` — and the alternative, fetching
        // every meal's ingredients to sift them here, would pull the whole
        // catalogue's recipe rows to answer a question about a handful of words.
        final dynamic rows = await _client.rpc<dynamic>(_blockedFunction);

        return <String>{
          if (rows is List)
            for (final dynamic row in rows)
              if (row is Map && row['meal_id'] is String)
                row['meal_id'] as String,
        };
      },
      label: 'meals.blockedByDislikes',
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

  /// Migration 0021. Reads `disliked_ingredient_names` for `auth.uid()` and
  /// returns the meal ids those foods rule out.
  static const String _blockedFunction = 'meals_blocked_by_dislikes';

  static const String _table = 'meals';

  /// Named rather than `*`, so a column added to the table later does not
  /// silently start crossing the wire on every page of the feed.
  static const String _columns =
      'id, name, description, cuisine, category, difficulty, '
      'cooking_time_minutes, estimated_cost, servings, calories, '
      'instructions, dietary_tags, tags, is_public, created_by';

  /// The feed columns plus the ingredient join.
  ///
  /// Two hops: PostgREST nests a joined table under its own name, and the second
  /// reaches through the link table into the shared vocabulary — which is why an
  /// ingredient's name arrives at `meal_ingredients[].ingredients.name` rather
  /// than flat.
  ///
  /// Paid for here and nowhere else. On the feed it would be twenty rows times
  /// six ingredients that no card renders.
  static const String _detailColumns =
      '$_columns, '
      'meal_ingredients(quantity, unit, is_optional, '
      'ingredients(name, is_staple))';
}
