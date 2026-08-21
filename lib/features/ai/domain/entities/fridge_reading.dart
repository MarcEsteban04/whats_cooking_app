/// What the assistant says it can see in a photo (Sprint 49).
///
/// **Names only, and that is a decision.** The obvious extra field is the aisle —
/// a vision model guessing "kangkong is a vegetable" would let the confirmation
/// list group itself. It is not asked for, because
/// [IngredientCategory][1] already records the reason: *guessing that "kangkong" is
/// a vegetable is easy and guessing that "bagoong" is a condiment is not, and a
/// wrong aisle is worse than no aisle*. The catalogue owns the aisle; a photo does
/// not get a vote.
///
/// **No quantities either.** A picture cannot say how much rice is in the bag, and
/// the pantry already has the honest answer to that — a null quantity means *we
/// have some*, which is exactly what a photo establishes and no more.
///
/// [1]: ../../../core/domain/food_taxonomy.dart
abstract final class FridgeReading {
  /// Reads the reply into ingredient names.
  ///
  /// Lower cased and trimmed, matching the shared vocabulary the pantry resolves
  /// names against — so what comes out of here is already in the shape
  /// `PantryRepository.add` wants.
  ///
  /// An empty list means the model said it could see no food, or said something
  /// that was not a list. Those are the same outcome for the caller: there is
  /// nothing to confirm, and a screen that has to distinguish "no food" from
  /// "unreadable answer" is a screen showing the reader a distinction they cannot
  /// act on.
  static List<String> parse(String reply) {
    final List<String> names = <String>[];
    final Set<String> seen = <String>{};

    for (final String raw in reply.split('\n')) {
      final String line = _clean(raw);

      if (line.isEmpty || _isNone(line)) {
        continue;
      }

      // Prose, not an item. A vision model that starts "I can see the following
      // items in your fridge:" is being helpful, and the helpfulness is the thing
      // that would end up in somebody's kitchen as an ingredient.
      if (line.length > _maxNameChars || line.split(' ').length > _maxWords) {
        continue;
      }

      if (seen.add(line)) {
        names.add(line);
      }

      if (names.length >= _maxItems) {
        break;
      }
    }

    return names;
  }

  /// One line, minus its bullet, its number, its trailing note and its case.
  static String _clean(String line) {
    String text = line.trim().replaceAll('**', '').replaceAll('`', '');

    // `- `, `* `, `1. `, `1) `.
    text = text.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d{1,2}[.)])\s*'), '');

    // "eggs (about six)" and "eggs — half a dozen" are both one ingredient with a
    // count attached. The count is dropped rather than parsed: see the class
    // comment on why a photo does not get to set a quantity.
    text = text.split(RegExp(r'[(—,:]')).first;

    return text.trim().toLowerCase();
  }

  /// The agreed way of saying "there is no food in this picture".
  ///
  /// Checked loosely because a model asked for one word sometimes sends a
  /// sentence, and the sentence still means the same thing.
  static bool _isNone(String line) =>
      line == 'none' || line == 'nothing' || line.startsWith('none ');

  /// Long enough for "spring onions", short enough to exclude a sentence.
  static const int _maxNameChars = 40;
  static const int _maxWords = 4;

  /// A fridge holds more than this, but a confirmation list nobody scrolls to the
  /// end of is a list where the last few get added unread.
  static const int _maxItems = 20;
}
