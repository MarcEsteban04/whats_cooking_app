/// Which meal the app is talking about right now.
///
/// **Because "tonight" was hardcoded.** Home's header said `Tonight` and its
/// question said "What are we eating tonight?" at any hour — including three in
/// the morning, which is where somebody noticed. A decision app that does not
/// know what time it is looks like it is not paying attention, and this is the
/// cheapest possible fix for that.
///
/// Deliberately *not* the same thing as `MealCategory`. That is a property of a
/// meal — what a recipe is *for* — and this is a property of the clock. They
/// agree most of the time and the difference matters at the edges: a household
/// spinning at four in the afternoon is deciding dinner, not looking for a meal
/// filed under "afternoon", which is not a category and should not become one.
enum MealMoment {
  morning('This morning', 'this morning', 'breakfast'),
  midday('Today', 'today', 'lunch'),
  afternoon('Today', 'this afternoon', 'dinner'),
  evening('Tonight', 'tonight', 'dinner'),
  lateNight('Tonight', 'tonight', 'dinner');

  const MealMoment(this.heading, this.phrase, this.mealName);

  /// The header's one word — "Tonight", "This morning".
  final String heading;

  /// How it reads inside a sentence — "What are we eating *this morning*?".
  final String phrase;

  /// What the assistant is told it is choosing, so a spin at eight in the morning
  /// is not asked to pick dinner.
  final String mealName;

  /// Which moment [now] falls in.
  ///
  /// The boundaries are about when somebody *decides*, not when they eat. Dinner
  /// gets decided from mid-afternoon onward — that is when the question actually
  /// gets asked — and the small hours stay "tonight" rather than rolling over to
  /// morning at midnight, because somebody spinning at 1 am is finishing an
  /// evening rather than starting a day.
  static MealMoment at(DateTime now) => switch (now.hour) {
    >= 4 && < 11 => MealMoment.morning,
    >= 11 && < 15 => MealMoment.midday,
    >= 15 && < 18 => MealMoment.afternoon,
    >= 18 => MealMoment.evening,
    _ => MealMoment.lateNight,
  };

  /// Now, for a caller with no clock of its own to pass.
  static MealMoment get current => at(DateTime.now());
}
