import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/domain/repositories/pantry_repository.dart';

/// [PantryRepository] backed by PostgREST.
class SupabasePantryRepository implements PantryRepository {
  SupabasePantryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PantryItem>> items() {
    return RemoteCall.guard(
      () async {
        // Ordered on the joined table's columns, which PostgREST expresses as
        // `ingredients(name)`. Doing it here rather than in Dart keeps the order
        // stable across a refresh and costs nothing — the index on
        // `ingredients (name)` from migration 0021 is already there.
        final PostgrestList rows = await _client
            .from(_table)
            .select(_columns)
            .order('category', referencedTable: 'ingredients')
            .order('name', referencedTable: 'ingredients');

        return <PantryItem>[
          for (final Map<String, dynamic> row in rows) PantryItem.fromRow(row),
        ];
      },
      label: 'pantry.items',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<PantryItem> add({
    required String name,
    double? quantity,
    String unit = '',
    DateTime? expiresOn,
  }) {
    return RemoteCall.guard(
      () async {
        final String householdId = await _requireHouseholdId();
        final String ingredientId = await _resolveIngredient(name, unit);

        final Map<String, dynamic> row = await _client
            .from(_table)
            .upsert(
              <String, Object?>{
                'household_id': householdId,
                'ingredient_id': ingredientId,
                'quantity': quantity,
                'unit': unit.trim(),
                'expiration_date': expiresOn?.toIso8601String().substring(
                  0,
                  10,
                ),
                'added_by': _client.auth.currentUser?.id,
                // Touched explicitly because `updated_at` has no trigger on this
                // table and an upsert that changes only the quantity would
                // otherwise keep the original timestamp.
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              // The schema's own uniqueness. Adding chicken twice is one row with
              // the newer amount, not two rows to reconcile at the fridge door.
              onConflict: 'household_id,ingredient_id',
            )
            .select(_columns)
            .single();

        return PantryItem.fromRow(row);
      },
      label: 'pantry.add',
      // Retried, unlike a history insert. This write is idempotent by
      // construction — the same upsert twice is the same row — so a retry cannot
      // produce a second anything.
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<PantryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    DateTime? expiresOn,
    bool clearQuantity = false,
    bool clearExpiry = false,
  }) {
    return RemoteCall.guard(
      () async {
        final Map<String, dynamic> row = await _client
            .from(_table)
            .update(<String, Object?>{
              // Sent as an explicit null when cleared, because that is the
              // difference between "we have some" and "500 g" — and omitted
              // entirely when not being changed, so a unit edit cannot wipe an
              // amount.
              if (clearQuantity) 'quantity': null else 'quantity': ?quantity,
              'unit': ?unit?.trim(),
              if (clearExpiry)
                'expiration_date': null
              else
                'expiration_date': ?expiresOn?.toIso8601String().substring(
                  0,
                  10,
                ),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', id)
            .select(_columns)
            .single();

        return PantryItem.fromRow(row);
      },
      label: 'pantry.updateAmount',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> remove(String id) {
    return RemoteCall.guard(
      () async {
        await _client.from(_table).delete().eq('id', id);
      },
      label: 'pantry.remove',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<Map<String, PantryMatch>> matches() {
    return RemoteCall.guard(
      () async {
        final dynamic rows = await _client.rpc<dynamic>(_matchFunction);

        return <String, PantryMatch>{
          if (rows is List)
            for (final dynamic row in rows)
              if (row is Map<String, dynamic> && row['meal_id'] is String)
                row['meal_id'] as String: PantryMatch.fromRow(row),
        };
      },
      label: 'pantry.matches',
      // **No retry.** Observed on device before migration 0022 landed: a missing
      // function returns `PGRST202`, which three attempts cannot fix, so every
      // load spent ≈700 ms backing off toward the same answer. A schema error is
      // not a flaky connection, and this call is on the path Home warms before a
      // spin — the cheapest possible failure is the right one.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<List<IngredientSuggestion>> suggest(String query) {
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) {
      // Answered without a request. An autocomplete that opens with the whole
      // vocabulary is a list, and a list is not what somebody halfway through
      // typing "chick" is looking at.
      return Future<List<IngredientSuggestion>>.value(
        const <IngredientSuggestion>[],
      );
    }

    return RemoteCall.guard(
      () async {
        final PostgrestList rows = await _client
            .from(_ingredients)
            .select('id, name, category, default_unit')
            // Prefix rather than substring. "on" should offer onion, not every
            // ingredient with an "on" buried in it — and a prefix uses the index
            // on `ingredients (name)` where a leading wildcard cannot.
            .ilike('name', '${_escapeLike(term)}%')
            .order('name')
            .limit(_suggestionLimit);

        return <IngredientSuggestion>[
          for (final Map<String, dynamic> row in rows)
            IngredientSuggestion.fromRow(row),
        ];
      },
      label: 'pantry.suggest',
      // No retry, and a short leash. This fires while somebody is typing; a
      // suggestion that arrives after three retries is a suggestion for a word
      // they have finished writing.
      policy: RetryPolicy.none,
      timeout: _suggestTimeout,
    );
  }

  /// The ingredient row for [name], creating it if the vocabulary lacks it.
  ///
  /// Mirrors `SupabaseMealRepository._attachIngredients`, and for the same reason
  /// the `authenticated add ingredients` policy exists: "Users must never be
  /// blocked because our ingredient list is incomplete". Somebody typing
  /// *bagoong* into their own pantry is not a data-quality problem to reject.
  Future<String> _resolveIngredient(String name, String unit) async {
    final String normalised = name.trim().toLowerCase();
    if (normalised.isEmpty) {
      throw const ValidationException(message: 'Give the ingredient a name.');
    }

    final Map<String, dynamic>? existing = await _client
        .from(_ingredients)
        .select('id')
        .eq('name', normalised)
        .maybeSingle();

    if (existing?['id'] case final String id) {
      return id;
    }

    final Map<String, dynamic> inserted = await _client
        .from(_ingredients)
        .insert(<String, Object?>{
          'name': normalised,
          // `other`, not a guess. The categories describe where a thing sits in a
          // shop and the person typing has not been asked — and putting soy sauce
          // in the fruit aisle is worse than putting it in "everything else".
          'category': 'other',
          // The unit they just used, which is the best evidence available for
          // what this ingredient is normally measured in.
          'default_unit': unit.trim().isEmpty ? 'pc' : unit.trim(),
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  /// The caller's kitchen.
  Future<String> _requireHouseholdId() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailureException(
        message: 'Sign in again to see your kitchen.',
      );
    }

    final Map<String, dynamic>? profile = await _client
        .from('profiles')
        .select('active_household_id')
        .eq('id', userId)
        .maybeSingle();

    if (profile?['active_household_id'] case final String householdId) {
      return householdId;
    }

    // Every account gets a household on signup by trigger
    // (docs/ARCHITECTURE.md §6.2), so this means provisioning has not been
    // observed yet rather than that there is no kitchen.
    throw const ValidationException(
      message: 'Your kitchen is still being set up. Try again in a moment.',
      detail: 'profiles.active_household_id was null',
    );
  }

  /// Escapes the wildcards `ilike` would otherwise treat as syntax.
  static String _escapeLike(String value) =>
      value.replaceAll('\\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// The join PostgREST nests under `ingredients`.
  static const String _columns =
      'id, ingredient_id, quantity, unit, expiration_date, '
      'ingredients(name, category, is_staple)';

  /// Enough to choose from, few enough to read without scrolling a sheet.
  static const int _suggestionLimit = 8;

  /// Shorter than the app default, because this runs on a keystroke.
  static const Duration _suggestTimeout = Duration(seconds: 4);

  /// Migration 0022. Per meal: needed, have, and up to three missing names.
  static const String _matchFunction = 'pantry_match';

  static const String _table = 'pantry_items';
  static const String _ingredients = 'ingredients';
}
