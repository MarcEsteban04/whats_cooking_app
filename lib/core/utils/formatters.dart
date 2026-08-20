import 'package:intl/intl.dart';

/// Display formatting for the values that appear all over the UI.
///
/// Centralised because a meal's cost and cooking time are rendered on the meal
/// card, the result screen, the planner, the history row and the grocery
/// summary. Six local formats is six chances for one of them to read `₱220.00`
/// while the rest read `₱220`.
abstract final class AppFormat {
  /// Philippine peso, whole units.
  ///
  /// Meal costs are estimates; centavos imply a precision the data does not
  /// have, so the fraction is dropped rather than rounded for display.
  static final NumberFormat _peso = NumberFormat.currency(
    symbol: '₱',
    decimalDigits: 0,
  );

  /// `₱220`.
  static String peso(num amount) => _peso.format(amount);

  /// `30 min`, `1 hr`, `1 hr 30 min`.
  static String cookingTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;

    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }

  /// `1 serving`, `2 servings`.
  static String servings(int count) =>
      count == 1 ? '1 serving' : '$count servings';

  /// `2 people`, used for household size rather than plated servings.
  static String people(int count) => count == 1 ? '1 person' : '$count people';

  /// `85%`.
  /// Capitalises the first letter and leaves the rest alone.
  ///
  /// For the shared ingredient vocabulary, which is stored lower-case by a
  /// database check constraint. Only the first letter: "chicken thigh" should
  /// read as "Chicken thigh", not as "Chicken Thigh" — it is one ingredient,
  /// not a title.
  static String sentenceCase(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  static String percent(double fraction) => '${(fraction * 100).round()}%';

  /// Joins metadata with the interpunct separator the design uses throughout:
  /// `Japanese · 30 min · ₱220`.
  ///
  /// Empty and null parts are dropped so a meal missing its cuisine does not
  /// render a dangling separator.
  static String metadata(Iterable<String?> parts) {
    return parts
        .where((String? part) => part != null && part.isNotEmpty)
        .join(' · ');
  }

  /// `Today`, `Yesterday`, `Friday`, or `12 August` (Sprint 31).
  ///
  /// Four scales, because a history is read at four distances. Today and
  /// yesterday get their names — those are the two days somebody is checking
  /// against when they wonder whether they had chicken again. Inside the week the
  /// weekday is enough. Beyond that the date, because "eleven days ago" is
  /// arithmetic somebody has to do.
  static String dayLabel(DateTime day, {DateTime? now}) {
    final DateTime today = _startOfDay(now ?? DateTime.now());
    final int difference = today.difference(_startOfDay(day)).inDays;

    return switch (difference) {
      0 => 'Today',
      1 => 'Yesterday',
      // Not "in the last 7 days": a weekday name six days back is ambiguous with
      // the same weekday a fortnight ago, and a history goes back further.
      >= 2 && < 7 => _weekdays[day.weekday - 1],
      _ => '${day.day} ${_months[day.month - 1]}',
    };
  }

  /// `7:30 pm`.
  ///
  /// Lower-case meridiem and no leading zero, because this appears in a metadata
  /// line beside words rather than in a table of times.
  static String timeOfDay(DateTime at) {
    final int hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final String minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'am' : 'pm'}';
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// How long ago, in the vaguest terms that are still true (Sprint 27).
  ///
  /// For "showing the meals saved 20 minutes ago". Deliberately coarse: the
  /// reader wants to know whether what they are looking at is minutes or hours
  /// old, and "saved 23 minutes ago" claims a precision that does not help them
  /// decide anything.
  ///
  /// [now] is injectable so the wording can be checked without waiting.
  static String relativeTime(DateTime when, {DateTime? now}) {
    final Duration elapsed = (now ?? DateTime.now()).toUtc().difference(
      when.toUtc(),
    );

    if (elapsed.inMinutes < 1) {
      return 'just now';
    }
    if (elapsed.inMinutes < 60) {
      final int minutes = elapsed.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (elapsed.inHours < 24) {
      final int hours = elapsed.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }

    final int days = elapsed.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
}
