import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_cooking/core/domain/meal_moment.dart';
import 'package:whats_cooking/core/notifications/meal_reminder.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/home/presentation/providers/tonight.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

part 'reminder_controller.g.dart';

/// When to be asked (Sprint 56).
@immutable
class ReminderSetting {
  const ReminderSetting({
    required this.isOn,
    required this.hour,
    required this.minute,
  });

  /// Off, at half five.
  ///
  /// **Off by default, and that is not timidity.** A notification somebody did
  /// not ask for is the fastest way to have every notification from this app
  /// turned off at the operating system, which cannot be undone from inside it.
  /// The time is pre-filled so turning it on is one tap rather than a decision.
  static const ReminderSetting initial = ReminderSetting(
    isOn: false,
    // Half five: late enough that the afternoon is over, early enough that there
    // is still time to buy the one thing that is missing.
    hour: 17,
    minute: 30,
  );

  final bool isOn;
  final int hour;
  final int minute;

  /// `5:30 pm`.
  String get label {
    final int twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'am' : 'pm'}';
  }

  ReminderSetting copyWith({bool? isOn, int? hour, int? minute}) =>
      ReminderSetting(
        isOn: isOn ?? this.isOn,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSetting &&
      other.isOn == isOn &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(isOn, hour, minute);
}

/// The evening nudge, and the only notification this app sends.
///
/// **Stored on the device, not in the household row.** A notification is a
/// property of a handset: the permission is granted per device, the alarm is held
/// by that device's operating system, and a second phone joining later has its
/// own answer to give. Syncing it would mean one person's "not at weekends"
/// silencing the other's phone. Same reasoning as `ThemeModeController`, and the
/// same store.
///
/// **[apply] is the whole design.** Nothing here schedules a repeating daily
/// alarm — it schedules the *next* one, with text composed from what is true now,
/// and re-does that every time the app is opened. Which is what lets the reminder
/// say "2 things to use up" instead of the same sentence forever, and lets it skip
/// an evening that was already decided at four o'clock rather than interrupting it.
@Riverpod(keepAlive: true)
class ReminderController extends _$ReminderController {
  @override
  ReminderSetting build() {
    unawaited(_restore());
    return ReminderSetting.initial;
  }

  Future<void> _restore() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final ReminderSetting stored = ReminderSetting(
        isOn: preferences.getBool(_onKey) ?? ReminderSetting.initial.isOn,
        hour: preferences.getInt(_hourKey) ?? ReminderSetting.initial.hour,
        minute:
            preferences.getInt(_minuteKey) ?? ReminderSetting.initial.minute,
      );

      state = stored;

      // The alarm the OS holds may be from a previous install, a previous
      // version, or nothing at all — a reboot clears every one of them and the
      // boot receiver only restores what was pending at the time. Re-asserting
      // it on launch is what makes "on" mean on.
      if (stored.isOn) {
        await apply();
      }
    } on Object catch (error) {
      AppLog.debug(
        'Could not read the reminder setting.',
        name: _logName,
        data: <String, Object?>{'reason': error.runtimeType.toString()},
      );
    }
  }

  /// Turns the reminder on or off.
  ///
  /// Returns null on success, or a sentence to show when the operating system
  /// refused. **The switch does not move on a refusal**, because a switch that
  /// says on while Android is dropping every notification is the app lying about
  /// something the reader cannot check.
  Future<String?> setOn(bool isOn) async {
    if (!isOn) {
      state = state.copyWith(isOn: false);
      await _persist();
      await MealReminder.cancel();
      return null;
    }

    // Asked here and nowhere else — at the moment somebody has said what they
    // want, which is the only moment the dialog makes sense.
    if (!await MealReminder.requestPermission()) {
      return 'Your phone is blocking notifications for this app. Turn them '
          'on for What’s Cooking? in your phone’s settings and try '
          'again.';
    }

    state = state.copyWith(isOn: true);
    await _persist();
    await apply();
    return null;
  }

  /// Moves the reminder to a new time of day.
  Future<void> setTime({required int hour, required int minute}) async {
    state = state.copyWith(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
    await _persist();

    // Only when it is on. Setting a time is not consent to be notified, and
    // scheduling on a change to a switched-off reminder would deliver one.
    if (state.isOn) {
      await apply();
    }
  }

  /// Re-lays the whole week of reminders from what is true right now.
  ///
  /// Called on launch, on resume, and whenever the setting changes. Idempotent by
  /// construction — `replaceAll` clears the id block first — and free when the
  /// reminder is off.
  ///
  /// **Only the first one gets today's facts.** "2 things to use up" is true this
  /// evening and a guess by Thursday, and a reminder that states a stale number is
  /// worse than one that states none. The rest carry the plain invitation, and the
  /// next time the app is opened the whole week is rewritten with fresh ones.
  Future<void> apply() async {
    final ReminderSetting setting = state;

    if (!setting.isOn) {
      await MealReminder.cancel();
      return;
    }

    final DateTime now = DateTime.now();
    DateTime first = DateTime(
      now.year,
      now.month,
      now.day,
      setting.hour,
      setting.minute,
    );

    if (!first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }

    // **Skip an evening that is already settled.** The one thing a reminder must
    // never do is ask a question that has been answered — somebody who decided at
    // four o'clock and gets asked at half five learns the app is not paying
    // attention, and that is the last reminder they leave switched on.
    //
    // Only ever checked for *today's* slot. What tomorrow holds is not knowable.
    if (_isSameDay(first, now) && await _isAlreadyDecided(first)) {
      first = first.add(const Duration(days: 1));
    }

    final String todaysBody = _body();

    await MealReminder.replaceAll(<PlannedReminder>[
      for (int day = 0; day < MealReminder.horizon; day++)
        () {
          final DateTime at = first.add(Duration(days: day));
          return PlannedReminder(
            at: at,
            // The meal's own word, so a reminder set for eleven in the morning
            // does not ask about dinner. The same vocabulary Home's heading and
            // the result screen's overline use.
            title: 'What’s for ${MealMoment.at(at).mealName}?',
            body: day == 0 ? todaysBody : _invitation,
          );
        }(),
    ]);
  }

  /// Whether the meal [when] falls in has already been decided.
  ///
  /// Read rather than watched, and failure is a "no": a reminder that does not
  /// arrive because a query failed is worse than one that arrives on an evening
  /// somebody had already chosen.
  Future<bool> _isAlreadyDecided(DateTime when) async {
    try {
      final Decided? decided = await ref.read(decidedNowProvider.future);
      if (decided == null) {
        return false;
      }
      return MealMoment.at(decided.at).mealName == MealMoment.at(when).mealName;
    } on Object catch (error) {
      AppLog.debug(
        'Scheduling the reminder without checking tonight.',
        name: _logName,
        data: <String, Object?>{'reason': error.runtimeType.toString()},
      );
      return false;
    }
  }

  /// The line under the question.
  ///
  /// One extra fact at most. A notification is two lines on a lock screen, and a
  /// reminder that tries to be a dashboard is a reminder nobody finishes reading.
  String _body() {
    final int needsUsing =
        (ref.read(pantryControllerProvider).value ?? const <PantryItem>[])
            .where(
              (PantryItem item) =>
                  item.statusAsOf(DateTime.now()).needsAttention,
            )
            .length;

    if (needsUsing == 0) {
      return _invitation;
    }

    return needsUsing == 1
        ? '1 thing to use up — let us decide for you.'
        : '$needsUsing things to use up — let us decide for you.';
  }

  /// The same sentence Home leads with, on purpose. The reminder is a way into
  /// that screen and should sound like it.
  static const String _invitation = 'Let us decide for you.';

  Future<void> _persist() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setBool(_onKey, state.isOn);
      await preferences.setInt(_hourKey, state.hour);
      await preferences.setInt(_minuteKey, state.minute);
    } on Object catch (error) {
      // The switch has already moved and the alarm is already set. A failed
      // write costs the setting on the next launch, not this one.
      AppLog.warning(
        'Could not save the reminder setting.',
        name: _logName,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const String _onKey = 'whats_cooking.reminder.on';
  static const String _hourKey = 'whats_cooking.reminder.hour';
  static const String _minuteKey = 'whats_cooking.reminder.minute';
  static const String _logName = 'ReminderController';
}
