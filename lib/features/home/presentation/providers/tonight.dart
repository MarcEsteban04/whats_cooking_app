import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/meal_moment.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_history_repository.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_visits.dart';

part 'tonight.g.dart';

/// What was already decided for this meal (Sprint 55).
@immutable
class Decided {
  const Decided({
    required this.name,
    required this.at,
    required this.wasEatenOut,
    this.mealId,
    this.historyId,
  });

  final String name;
  final DateTime at;

  /// Whether this was a night out rather than something cooked.
  final bool wasEatenOut;

  /// Set on a cooked meal, so the panel can open it.
  final String? mealId;
  final String? historyId;
}

/// Whether tonight — or this morning, or lunch — is already settled.
///
/// **The app did not know when its own job was done.** Home asked "What are we
/// eating tonight?" over a large SPIN button whether or not a decision had been
/// made an hour earlier, and spinning again recorded a *second* dinner: the week's
/// count went up, the spend chart moved, and the household's own history claimed
/// they ate twice. For an app whose entire purpose is one decision per evening,
/// that is the sharpest thing it could be wrong about.
///
/// **Keyed on the meal, not the calendar day.** `MealMoment.mealName` groups the
/// afternoon, the evening and the small hours into "dinner", so deciding at four
/// and checking at eight matches, and deciding at breakfast does not stop the
/// evening being asked about.
///
/// **And the day starts at four in the morning**, matching `MealMoment.at`'s own
/// boundary. A decision made at eight in the evening is still the answer at half
/// past midnight — the calendar has rolled over and the evening has not, and a
/// panel that forgets dinner at midnight would be wrong in the most annoying
/// possible way.
@riverpod
Future<Decided?> decidedNow(Ref ref) async {
  final DateTime now = DateTime.now();
  final MealMoment moment = MealMoment.at(now);
  final DateTime dayStart = _foodDayStart(now);

  // Cooked. Watched rather than read: accepting a meal invalidates the history,
  // and this panel has to change the moment it does.
  final List<MealHistoryEntry> history =
      ref.watch(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

  for (final MealHistoryEntry entry in history) {
    if (_isThisMeal(entry.eatenAt, dayStart, moment)) {
      return Decided(
        name: entry.meal?.name ?? 'What you decided',
        at: entry.eatenAt,
        wasEatenOut: !entry.wasCooked,
        mealId: entry.mealId,
        historyId: entry.id,
      );
    }
  }

  // Eaten out. Through `restaurantVisits` rather than the repository directly,
  // and that is what makes this panel correct: accepting a night out invalidates
  // that provider, so Home changes the moment the decision is made. Reading the
  // repository here would leave this cached and stale for as long as the tab
  // stayed mounted — which, inside the shell's `IndexedStack`, is always.
  //
  // Wrapped, because migration 0025 may not be applied — and a missing table must
  // cost this panel rather than the screen.
  try {
    final List<RestaurantVisit> visits = await ref.watch(
      restaurantVisitsProvider.future,
    );

    for (final RestaurantVisit visit in visits) {
      if (_isThisMeal(visit.eatenAt, dayStart, moment)) {
        return Decided(
          name: visit.restaurantName,
          at: visit.eatenAt,
          wasEatenOut: true,
        );
      }
    }
  } on Object catch (error) {
    AppLog.debug(
      'Could not check nights out for tonight.',
      name: 'decidedNow',
      data: <String, Object?>{'reason': error.runtimeType.toString()},
    );
  }

  return null;
}

/// Whether [at] belongs to the current meal of the current food day.
bool _isThisMeal(DateTime at, DateTime dayStart, MealMoment moment) =>
    !at.isBefore(dayStart) && MealMoment.at(at).mealName == moment.mealName;

/// Four in the morning, today or yesterday.
///
/// The same boundary `MealMoment.at` uses to decide that 3 am is still "tonight".
/// Two definitions of when a day starts would eventually disagree, and this one
/// is downstream of that one.
DateTime _foodDayStart(DateTime now) {
  final DateTime shifted = now.subtract(const Duration(hours: _dayStartsAt));
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
  ).add(const Duration(hours: _dayStartsAt));
}

const int _dayStartsAt = 4;
