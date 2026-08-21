import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/domain/repositories/grocery_repository.dart';

/// [GroceryRepository] backed by PostgREST.
class SupabaseGroceryRepository implements GroceryRepository {
  SupabaseGroceryRepository(this._client);

  final SupabaseClient _client;

  /// The active list, once resolved.
  ///
  /// Cached for the life of the repository, which is the life of the session: the
  /// answer cannot change without a household change, and looking it up before
  /// every tick in a supermarket would double the round trips on the one screen
  /// used with one hand.
  String? _listId;

  @override
  Future<List<GroceryItem>> items() {
    return RemoteCall.guard(
      () async {
        final String listId = await _requireListId();

        final PostgrestList rows = await _client
            .from(_items)
            .select(_columns)
            .eq('grocery_list_id', listId)
            // Aisle first, then name, and **completion is not in the ordering**.
            // A ticked line staying where it was is the whole point — see the
            // repository interface. Sorting done items to the bottom would move
            // things under a thumb mid-shop.
            .order('category', referencedTable: 'ingredients')
            .order('custom_name')
            .order('created_at');

        return <GroceryItem>[
          for (final Map<String, dynamic> row in rows) GroceryItem.fromRow(row),
        ];
      },
      label: 'grocery.items',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<GroceryItem> add({
    required String name,
    double? quantity,
    String unit = '',
  }) {
    return RemoteCall.guard(
      () async {
        final String trimmed = name.trim();
        if (trimmed.isEmpty) {
          throw const ValidationException(message: 'Give the item a name.');
        }

        final String listId = await _requireListId();
        final String normalised = trimmed.toLowerCase();

        // Looked up but never created. A shopping note is not a catalogue entry —
        // see the interface for why the pantry does the opposite.
        final Map<String, dynamic>? known = await _client
            .from(_ingredients)
            .select('id')
            .eq('name', normalised)
            .maybeSingle();

        final String? ingredientId = known?['id'] as String?;

        // The existing line for this thing, if there is one. Matched on the
        // column that identifies it: the id when it is a catalogue ingredient,
        // the name when it is free text.
        final PostgrestList existing = await _client
            .from(_items)
            .select(_columns)
            .eq('grocery_list_id', listId)
            .eq(
              ingredientId == null ? 'custom_name' : 'ingredient_id',
              ingredientId ?? trimmed,
            )
            .limit(1);

        if (existing.isNotEmpty) {
          final GroceryItem current = GroceryItem.fromRow(existing.first);

          // Quantities add. Two lines for chicken is a list you read twice in an
          // aisle — and adding it again after ticking it off means it is wanted
          // again, so this un-ticks as well.
          final double? merged = switch ((current.quantity, quantity)) {
            (final double a, final double b) => a + b,
            (final double a, null) => a,
            (null, final double b) => b,
            _ => null,
          };

          return _decodeOne(
            await _client
                .from(_items)
                .update(<String, Object?>{
                  'quantity': merged,
                  'unit': unit.trim().isEmpty ? current.unit : unit.trim(),
                  'is_completed': false,
                  'completed_at': null,
                  'completed_by': null,
                })
                .eq('id', current.id)
                .select(_columns)
                .single(),
          );
        }

        return _decodeOne(
          await _client
              .from(_items)
              .insert(<String, Object?>{
                'grocery_list_id': listId,
                // Exactly one of these, which `grocery_items_name_ck` enforces.
                'ingredient_id': ingredientId,
                'custom_name': ingredientId == null ? trimmed : null,
                'quantity': quantity,
                'unit': unit.trim(),
              })
              .select(_columns)
              .single(),
        );
      },
      label: 'grocery.add',
      // No retry. The merge path is idempotent, but the insert path is not — a
      // retried insert on a free-text line would produce the second row this
      // method exists to prevent.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<int> addMissingForMeal(String mealId) {
    return RemoteCall.guard(
      () async {
        final dynamic touched = await _client.rpc<dynamic>(
          _addMissingFunction,
          params: <String, Object?>{'p_meal_id': mealId},
        );

        return touched is int ? touched : 0;
      },
      label: 'grocery.addMissingForMeal',
      // No retry. The function merges rather than duplicating, so a second run
      // is not catastrophic — but it *does* add the quantities again, and a
      // shopping list that quietly doubled the chicken is worse than one that
      // missed it. The caller treats a failure as "nothing added" and says so.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<GroceryItem> setCompleted(String id, {required bool isCompleted}) {
    return RemoteCall.guard(
      () async {
        return _decodeOne(
          await _client
              .from(_items)
              .update(<String, Object?>{
                'is_completed': isCompleted,
                // Who and when, cleared on un-ticking. Recorded because the
                // column is there and a half-filled audit trail is worse than
                // none.
                'completed_at': isCompleted
                    ? DateTime.now().toUtc().toIso8601String()
                    : null,
                'completed_by': isCompleted
                    ? _client.auth.currentUser?.id
                    : null,
              })
              .eq('id', id)
              .select(_columns)
              .single(),
        );
      },
      label: 'grocery.setCompleted',
      // Idempotent: setting a flag to the same value twice is the same row. This
      // is the write that happens most, one-handed, on a bad supermarket
      // connection — retrying it is exactly right.
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<GroceryItem> updateAmount(
    String id, {
    double? quantity,
    String? unit,
    bool clearQuantity = false,
  }) {
    return RemoteCall.guard(
      () async {
        return _decodeOne(
          await _client
              .from(_items)
              .update(<String, Object?>{
                if (clearQuantity) 'quantity': null else 'quantity': ?quantity,
                'unit': ?unit?.trim(),
              })
              .eq('id', id)
              .select(_columns)
              .single(),
        );
      },
      label: 'grocery.updateAmount',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<void> remove(String id) {
    return RemoteCall.guard(
      () async {
        await _client.from(_items).delete().eq('id', id);
      },
      label: 'grocery.remove',
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<int> clearCompleted() {
    return RemoteCall.guard(
      () async {
        final String listId = await _requireListId();

        final PostgrestList gone = await _client
            .from(_items)
            .delete()
            .eq('grocery_list_id', listId)
            .eq('is_completed', true)
            .select('id');

        return gone.length;
      },
      label: 'grocery.clearCompleted',
      // Idempotent by construction: a second run finds nothing left to delete.
      policy: RetryPolicy.standard,
      timeout: AppConstants.requestTimeout,
    );
  }

  /// The household's active list, creating it the first time.
  ///
  /// `grocery_lists_one_active_idx` is a unique partial index on
  /// `(household_id) where is_active`, so two devices racing to create the first
  /// list cannot both win — the loser gets a conflict and re-reads. Which is why
  /// this handles the insert failing by looking again rather than by giving up.
  Future<String> _requireListId() async {
    if (_listId case final String cached) {
      return cached;
    }

    final String householdId = await _requireHouseholdId();

    final Map<String, dynamic>? existing = await _client
        .from(_lists)
        .select('id')
        .eq('household_id', householdId)
        .eq('is_active', true)
        .maybeSingle();

    if (existing?['id'] case final String id) {
      return _listId = id;
    }

    try {
      final Map<String, dynamic> created = await _client
          .from(_lists)
          .insert(<String, Object?>{'household_id': householdId})
          .select('id')
          .single();

      return _listId = created['id'] as String;
    } on PostgrestException {
      // Lost the race, or the index refused for some other reason. Either way the
      // list exists now, and re-reading is a better answer than an error on a
      // screen whose whole job is a checklist.
      final Map<String, dynamic>? raced = await _client
          .from(_lists)
          .select('id')
          .eq('household_id', householdId)
          .eq('is_active', true)
          .maybeSingle();

      if (raced?['id'] case final String id) {
        return _listId = id;
      }
      rethrow;
    }
  }

  /// The caller's kitchen.
  Future<String> _requireHouseholdId() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailureException(
        message: 'Sign in again to see your list.',
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

    throw const ValidationException(
      message: 'Your kitchen is still being set up. Try again in a moment.',
      detail: 'profiles.active_household_id was null',
    );
  }

  static GroceryItem _decodeOne(Map<String, dynamic> row) =>
      GroceryItem.fromRow(row);

  /// The join PostgREST nests under `ingredients`, null for a free-text line.
  static const String _columns =
      'id, ingredient_id, custom_name, quantity, unit, is_completed, '
      'added_from_meal_id, created_at, ingredients(name, category), '
      // The meal that put this here, by name. One extra nested select on a list
      // of a dozen rows, and it turns "bay leaves" into "bay leaves — for
      // Chicken Adobo", which is the difference between a line you trust and a
      // line you delete because you cannot remember adding it.
      'meals!grocery_items_added_from_meal_id_fkey(name)';

  /// Migration 0023. Adds a meal's missing ingredients, merging with what is
  /// already on the list, and returns how many lines it touched.
  static const String _addMissingFunction = 'add_missing_to_grocery';

  static const String _lists = 'grocery_lists';
  static const String _items = 'grocery_items';
  static const String _ingredients = 'ingredients';
}
