/// What somebody is in the mood for tonight (Sprint 36).
///
/// docs/app_feature.md's "Mood" lists nine, and one line about what they do: "the
/// recommendation engine adjusts accordingly". That word — adjusts — is the whole
/// design, and it is worth being explicit about the alternative that was not
/// taken.
///
/// **A mood is a bias, never a filter.** The seeded catalogue carries `healthy`
/// on three meals of sixty, `light` on one, `spicy` on seven. As a filter,
/// "healthy" would leave a household choosing between three dishes for the rest
/// of the month, and "light meal" would hand them the same plate every time or
/// nothing at all — a roulette that stops being a roulette. As a bias, those
/// three rise to the top of a pool that is still sixty deep, and the ones just
/// outside the tag still turn up sometimes. That is the difference between an app
/// that answers the question and an app that argues with it.
///
/// **Tags, not categories.** Each mood names the tags it leans toward and the
/// tags it leans away from, and those tags already exist on every seeded meal —
/// `comfort`, `fried`, `high_protein`, `budget`, `no_cook` and forty more. Nothing
/// here needed a new column, which is why moods can be tuned by editing this file
/// rather than by re-tagging a catalogue.
///
/// **The discouraged set matters as much as the favoured one.** "Healthy" that
/// only promotes salad still offers deep-fried pork half the time, because
/// promoting three meals out of sixty barely moves a weighted draw. Pushing the
/// contradiction *down* is what makes the mood legible in one spin instead of
/// ten.
///
/// Pure Dart, like everything in `core/domain`: no Flutter, no icons. The glyph
/// for each of these lives in the widget that draws them.
enum Mood {
  /// The rainy-day answer. Something known, warm, and probably in a bowl.
  comfort(
    label: 'Comfort food',
    favours: <String>{'comfort', 'soup', 'rainy_day', 'one_pot', 'filling'},
    discourages: <String>{'light', 'no_cook', 'fresh'},
  ),

  /// A specific want rather than a general hunger — loud flavour, no restraint.
  ///
  /// The vaguest of the nine as a word, so it is defined by what it excludes:
  /// this is the mood where "balanced" is the wrong answer.
  craving(
    label: 'Craving',
    favours: <String>{'street_food', 'sizzling', 'rich', 'spicy', 'fried'},
    discourages: <String>{'light', 'healthy', 'balanced'},
  ),

  /// Eating well, and knowing it.
  healthy(
    label: 'Healthy',
    favours: <String>{
      'healthy',
      'fresh',
      'balanced',
      'meatless',
      'steamed',
      'colourful',
    },
    discourages: <String>{'fried', 'rich', 'sweet'},
    calories: CaloriePreference.fewer,
  ),

  /// Heat. The one mood with a single tag behind it, and no contradiction worth
  /// naming — a dish is spicy or it is not, and nothing is *anti*-spicy.
  spicy(
    label: 'Spicy',
    favours: <String>{'spicy'},
    discourages: <String>{},
  ),

  /// The honest version of a bad idea, which is a thing an app should be able to
  /// help with rather than quietly disapprove of.
  junk(
    label: 'Junk food',
    favours: <String>{'fried', 'street_food', 'sweet', 'sizzling', 'rich'},
    discourages: <String>{'healthy', 'fresh', 'balanced', 'steamed'},
    calories: CaloriePreference.more,
  ),

  /// Small, and preferably not cooked for an hour.
  light(
    label: 'Light meal',
    favours: <String>{'light', 'fresh', 'no_cook', 'steamed', 'quick'},
    discourages: <String>{'rich', 'filling', 'fried', 'comfort'},
    calories: CaloriePreference.fewer,
  ),

  /// After the gym, or before a long day.
  highProtein(
    label: 'High protein',
    favours: <String>{'high_protein', 'grilled'},
    discourages: <String>{'sweet', 'baking', 'no_bake'},
  ),

  /// Payday is Friday.
  ///
  /// The only mood with a number behind it as well as tags, because "cheap" is
  /// the one of the nine that is genuinely measurable — see [favoursLowCost].
  cheap(
    label: 'Cheap',
    favours: <String>{'budget', 'pantry', 'leftovers'},
    discourages: <String>{'special_occasion', 'party'},
    favoursLowCost: true,
  ),

  /// No opinion, held strongly.
  ///
  /// Not the absence of a mood — that is what choosing nothing does. This one
  /// **actively widens the draw**: it favours nothing by tag, rewards food the
  /// household has not had, and multiplies the engine's temperature so the
  /// weighted pick flattens out toward genuine chance. Picking the highest-scoring
  /// meal more decisively would be the opposite of a surprise.
  surpriseMe(
    label: 'Surprise me',
    favours: <String>{},
    discourages: <String>{},
    favoursNovelty: true,
    temperatureMultiplier: 2,
  );

  const Mood({
    required this.label,
    required this.favours,
    required this.discourages,
    this.calories = CaloriePreference.none,
    this.favoursLowCost = false,
    this.favoursNovelty = false,
    this.temperatureMultiplier = 1,
  });

  final String label;

  /// Tags worth points.
  ///
  /// Curated so that **any one of them means the mood applies** — the scorer does
  /// not count how many matched. A dish tagged `soup` is comfort food; a dish
  /// tagged `soup` and `one_pot` is not twice as much comfort food, and scoring it
  /// that way would quietly rank tag density instead of relevance.
  final Set<String> favours;

  /// Tags that count against.
  final Set<String> discourages;

  /// Whether the mood leans on calories, and which way.
  final CaloriePreference calories;

  /// Whether cheaper is better in itself.
  ///
  /// Separate from the budget signal the scorer already has: that one measures a
  /// meal against a limit the household set, and this one has no limit to measure
  /// against — somebody asking for cheap has not necessarily set a budget, and
  /// may be asking for something well under the one they did set.
  final bool favoursLowCost;

  /// Whether food the household has not eaten is worth extra.
  final bool favoursNovelty;

  /// What to multiply the engine's temperature by.
  ///
  /// Above 1 flattens the weighted draw toward chance. This is the knob
  /// [Mood.surpriseMe] exists to turn, and the reason it is a mood at all rather
  /// than a button that clears the others.
  final double temperatureMultiplier;

  String get value => name;

  /// Whether [tags] puts a meal in this mood.
  bool favoursAnyOf(Iterable<String> tags) {
    for (final String tag in tags) {
      if (favours.contains(tag)) {
        return true;
      }
    }
    return false;
  }

  /// Whether [tags] puts a meal against it.
  bool discouragesAnyOf(Iterable<String> tags) {
    for (final String tag in tags) {
      if (discourages.contains(tag)) {
        return true;
      }
    }
    return false;
  }

  static Mood? fromValue(String value) {
    for (final Mood mood in Mood.values) {
      if (mood.value == value) {
        return mood;
      }
    }
    return null;
  }
}

/// Which way a mood leans on calories, if at all.
///
/// Three states rather than a nullable bool, because "fewer", "more" and "does
/// not care" are three real answers and a null bool reads as an oversight.
enum CaloriePreference { none, fewer, more }
