import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:whats_cooking/core/utils/logger.dart';

/// One reminder, ready to be scheduled.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.title,
    required this.body,
  });

  /// Local wall-clock time.
  final DateTime at;

  final String title;
  final String body;
}

/// The one notification this app sends (Sprint 56).
///
/// **The app could not remind anybody it existed.** Every feature in it answers
/// one question — what are we eating — and that question arrives at half five, in
/// a kitchen, from somebody who is hungry and is not thinking *let me open an
/// app*. So the roulette, the pantry, the assistant and the history were all
/// waiting behind a launcher icon nobody had a reason to tap. This is the only
/// feature in the app whose job is to be the reason.
///
/// **A short queue of individual notifications, not a repeating alarm.** The two
/// obvious designs are both wrong. A daily repeat has fixed text, so it would say
/// the same nine words for the rest of the year and fire on the evenings dinner
/// was decided at four. Scheduling only the *next* one is worse in a quieter way:
/// the reminder would arrive, nobody would open the app because they had already
/// decided out loud, and there would never be another one — a feature that
/// switches itself off after one use.
///
/// So [replaceAll] lays down a week of them at once, the first carrying what is
/// true today and the rest a plain invitation, and every app open replaces the
/// whole queue with a fresh week. The reminder survives a week of the app not
/// being opened, and still says something current whenever it is.
///
/// **Inexact, deliberately.** `AndroidScheduleMode.inexactAllowWhileIdle` lets
/// Android batch this with whatever else it was going to wake for. The
/// alternative is `SCHEDULE_EXACT_ALARM`, a permission Google Play restricts to
/// apps that need alarm-clock precision — and "around half five" is the entire
/// requirement.
///
/// Nothing here reads the database, holds a provider, or knows what a meal is.
/// It takes times and strings and puts them in front of somebody.
class MealReminder {
  MealReminder._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _isReady = false;

  /// Prepares the plugin. Safe to call repeatedly.
  ///
  /// Not called from `main`, on purpose: this is a platform channel and a
  /// notification channel registration, and the startup budget
  /// (docs/ARCHITECTURE.md §12: 1.5 s to interactive) should not be spent on a
  /// feature that may be switched off. It runs the first time anything actually
  /// needs it.
  static Future<bool> _ready() async {
    if (_isReady) {
      return true;
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // The silhouette, not the launcher mark — see the drawable's own
          // comment for why the usual shortcut puts a white square in the status
          // bar.
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            // All three false. Permission is asked for when somebody turns the
            // reminder *on*, not the first time the plugin wakes up — an app
            // that asks before it has explained what it wants is an app that
            // gets told no once and permanently.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      _isReady = true;
      return true;
    } on Object catch (error, stackTrace) {
      // A reminder that cannot be set up is a reminder that does not arrive. It
      // is never a reason to fail whatever asked — the settings screen reads
      // `false` here and says so.
      AppLog.error(
        'Could not set up the reminder.',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Asks the operating system, and reports what it said.
  ///
  /// Called when the switch is turned on and at no other time. Returns false on
  /// a refusal *and* on a platform that has not been asked yet — the caller
  /// treats both the same way, because a reminder that cannot be shown is off
  /// whatever the reason.
  static Future<bool> requestPermission() async {
    if (!await _ready()) {
      return false;
    }

    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        // Below Android 13 there is no runtime permission and this answers null,
        // which is a yes: notifications were granted at install time.
        return await android.requestNotificationsPermission() ?? true;
      }

      final IOSFlutterLocalNotificationsPlugin? apple = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (apple != null) {
        return await apple.requestPermissions(alert: true, sound: true) ??
            false;
      }

      // Some other platform, or a test. Nothing to ask, nothing to promise.
      return false;
    } on Object catch (error) {
      AppLog.debug(
        'Could not ask about notifications.',
        name: _logName,
        data: <String, Object?>{'reason': error.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Throws away every pending reminder and lays down [planned] instead.
  ///
  /// **Replace, never add.** Ids are assigned from the same fixed block every
  /// time, and the block is cleared first, so this is the only way reminders get
  /// scheduled and there is no path that accumulates a backlog of yesterdays.
  ///
  /// Anything already in the past is skipped rather than fired. A caller changing
  /// a setting at six o'clock is not asking to be notified at six o'clock.
  ///
  /// More than [horizon] entries are ignored, which is a cap rather than an
  /// error: the block of ids is fixed, and quietly overflowing it would schedule
  /// notifications [cancel] cannot reach.
  static Future<void> replaceAll(List<PlannedReminder> planned) async {
    if (!await _ready()) {
      return;
    }

    await cancel();

    final DateTime now = DateTime.now();
    int id = _firstId;

    for (final PlannedReminder one in planned) {
      if (id >= _firstId + horizon) {
        AppLog.debug(
          'More reminders than the id block holds; the rest are dropped.',
          name: _logName,
          data: <String, Object?>{'asked': planned.length, 'kept': horizon},
        );
        break;
      }
      if (!one.at.isAfter(now)) {
        continue;
      }

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: one.title,
          body: one.body,
          scheduledDate: _localise(one.at),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Dinner reminder',
              channelDescription:
                  'A nudge at the time you chose, so deciding what to eat does '
                  'not start with remembering this app exists.',
              // Not `high`. High importance is the level that takes over the top
              // of the screen with sound, and this is a question rather than an
              // emergency — a reminder that interrupts is a reminder somebody
              // turns off in week two.
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        id++;
      } on Object catch (error, stackTrace) {
        // One that failed does not stop the rest. A week with six reminders in it
        // is a working feature; abandoning the loop would turn one bad day into a
        // silent week.
        AppLog.error(
          'Could not schedule a reminder.',
          name: _logName,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Drops every reminder this class could have scheduled.
  ///
  /// Walks the whole id block rather than tracking what is outstanding: the
  /// pending set belongs to the operating system and survives reinstalls, reboots
  /// and a build that scheduled a different number of them.
  static Future<void> cancel() async {
    if (!await _ready()) {
      return;
    }

    for (int id = _firstId; id < _firstId + horizon; id++) {
      try {
        await _plugin.cancel(id: id);
      } on Object catch (error) {
        AppLog.debug(
          'Could not cancel a reminder.',
          name: _logName,
          data: <String, Object?>{
            'id': id,
            'reason': error.runtimeType.toString(),
          },
        );
      }
    }
  }

  /// A local wall-clock time the plugin will accept.
  ///
  /// **A fixed-offset zone built from the device's own offset, rather than the
  /// tz database.** The obvious version of this loads the whole IANA database at
  /// startup and adds a second plugin to read the device's zone name — several
  /// hundred kilobytes and a platform channel, spent on a startup path with a
  /// 1.5 s budget, to be correct about daylight saving.
  ///
  /// This app schedules **one** reminder at a time and re-schedules it every time
  /// it is opened, so the only question a zone has to answer is "what is the
  /// offset for the next day or so" — and the device already knows that. The
  /// failure mode is precise and small: a household that crosses a daylight
  /// saving boundary *and* does not open the app for a day gets one reminder an
  /// hour out, and the next open fixes it. The Philippines has not observed
  /// daylight saving since 1978.
  static tz.TZDateTime _localise(DateTime at) {
    final Duration offset = at.timeZoneOffset;

    final tz.Location here = tz.Location(
      'device',
      <int>[_beginningOfTime],
      <int>[0],
      <tz.TimeZone>[tz.TimeZone(offset, isDst: false, abbreviation: 'device')],
    );

    return tz.TZDateTime(here, at.year, at.month, at.day, at.hour, at.minute);
  }

  /// The single transition point every zone definition needs a value for.
  ///
  /// `tz.Location` describes a zone as "these rules apply from these instants",
  /// and a zone with one fixed rule still needs one instant to start from. The
  /// smallest the library accepts, so no date this app can produce falls before
  /// it.
  static const int _beginningOfTime = -8640000000000000;

  /// How many days ahead [replaceAll] will accept.
  ///
  /// A week. Long enough that the app can go unopened for days and still ask;
  /// short enough that the queue's stale tail is never more than a few plain
  /// invitations, and that Android's per-app alarm allowance is nowhere near.
  static const int horizon = 7;

  /// The first id in the block this class owns.
  ///
  /// A block rather than a single id, because a queue needs one per entry — and
  /// fixed rather than remembered, so [cancel] can clear reminders scheduled by
  /// an earlier install with no record of them anywhere.
  static const int _firstId = 1;

  static const String _channelId = 'whats_cooking.dinner_reminder';
  static const String _logName = 'MealReminder';
}
