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
}
