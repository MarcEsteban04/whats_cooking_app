import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/network/remote_call.dart';
import 'package:whats_cooking/core/network/retry_policy.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/domain/repositories/meal_history_repository.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// [MealHistoryRepository] backed by PostgREST.
class SupabaseMealHistoryRepository implements MealHistoryRepository {
  SupabaseMealHistoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MealHistoryEntry> record({
    required Meal meal,
    HistorySource source = HistorySource.roulette,
    double? actualCost,
    bool wasCooked = true,
  }) {
    return RemoteCall.guard(
      () async {
        final String userId = _requireUserId();
        final String householdId = await _requireHouseholdId(userId);

        final Map<String, dynamic> row = await _client
            .from(_table)
            .insert(<String, Object?>{
              'household_id': householdId,
              'meal_id': meal.id,
              // From the session, not from a parameter. The
              // `household members write history` policy checks
              // `decided_by = auth.uid()`, so anything else is a rejected insert
              // rather than a wrong row — but sending the right thing beats being
              // caught sending the wrong one.
              'decided_by': userId,
              // The meal's own category. Since migration 0018 the two enums carry
              // the same five values, so this no longer has to decide what a
              // dessert counts as.
              'meal_type': meal.category.value,
              'source': source.value,
              'was_cooked': wasCooked,
              // Omitted when null rather than sent as null. The column defaults
              // to null anyway, and an explicit null in the payload reads like a
              // deliberate erasure to whoever audits this later.
              'actual_cost': ?actualCost,
            })
            .select(_columns)
            .single();

        return MealHistoryEntry.fromRow(row);
      },
      label: 'history.record',
      // No retry. A retried insert is a second dinner. The table has no
      // uniqueness to lean on — deliberately, because a household really can eat
      // the same meal twice in a day — so a duplicate here is indistinguishable
      // from the truth and would skew every count built on it.
      policy: RetryPolicy.none,
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<List<MealHistoryEntry>> recent({int limit = kHistoryPageSize}) {
    return RemoteCall.guard(
      () async {
        // No household filter. The `household members read history` policy
        // already returns exactly this household's rows, so filtering here would
        // either duplicate it or disagree with it — and it means a meal a partner
        // accepted appears without this client knowing their household id.
        final PostgrestList rows = await _client
            .from(_table)
            .select(_columns)
            .order('eaten_at', ascending: false)
            // The id breaks ties, because two meals accepted in the same second
            // is a thing that happens when both partners tap accept.
            .order('id')
            .limit(limit);

        return <MealHistoryEntry>[
          for (final Map<String, dynamic> row in rows)
            MealHistoryEntry.fromRow(row),
        ];
      },
      label: 'history.recent',
      timeout: AppConstants.requestTimeout,
    );
  }

  @override
  Future<MealHistoryEntry> byId(String id) {
    return RemoteCall.guard(
      () async {
        // `maybeSingle` rather than `single`, so another household's entry and a
        // deleted one give the same answer — which is right, since telling them
        // apart would leak the difference.
        final Map<String, dynamic>? row = await _client
            .from(_table)
            .select(_columns)
            .eq('id', id)
            .maybeSingle();

        if (row == null) {
          throw const NotFoundException(message: 'We could not find that meal');
        }

        return MealHistoryEntry.fromRow(row);
      },
      label: 'history.byId',
      timeout: AppConstants.requestTimeout,
    );
  }

  String _requireUserId() {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthFailureException(
        message: 'Please sign in again',
        detail: 'history called with no session',
        isSessionExpired: true,
      );
    }
    return id;
  }

  Future<String> _requireHouseholdId(String userId) async {
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
        message: 'Your kitchen is still being set up. Try again in a moment.',
        detail: 'profiles.active_household_id was null',
      );
    }
    return householdId;
  }

  static const String _table = 'meal_history';

  /// The row, plus enough of the meal to render a line about it.
  ///
  /// The join is paid for on every read because there is no version of this
  /// screen that does not need the meal's name, and a second request per row to
  /// fetch it would be forty requests for one list.
  static const String _columns =
      'id, meal_id, eaten_at, meal_type, source, actual_cost, was_cooked, '
      'meals(id, name, description, cuisine, category, difficulty, '
      'cooking_time_minutes, estimated_cost, servings, calories, instructions, '
      'dietary_tags, tags, is_public, created_by)';
}
