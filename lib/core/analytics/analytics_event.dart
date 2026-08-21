import 'package:flutter/foundation.dart';

/// The event vocabulary from docs/ARCHITECTURE.md §10.
///
/// **Why this exists as types rather than strings.** §10 names one metric as the
/// product's north star — Time to Decision, which *is*
/// `meal_accepted.seconds_since_app_open` — and lists it under risk 14:
/// "Analytics from build one. Cannot be measured retroactively." A string-keyed
/// `track(name, map)` satisfies that on paper and fails in practice, because the
/// day somebody writes `'meal_accept'` or drops the seconds field is the day the
/// series breaks, and nothing complains until the number is needed and the
/// history is gone. Here the compiler is the schema.
///
/// **No PII, no meal names — IDs only** (§10, last line). That is enforced by the
/// constructors rather than trusted: every property is an id, a count, a duration
/// or a flag, so there is no parameter a name could be passed to. `AnalyticsSink`
/// re-checks in debug builds, because the cheapest place to catch a leak is
/// before it is written and the second cheapest is never.
///
/// **Only events that are actually emitted are defined here.** §10's table also
/// lists `onboarding_step`, `household_created`, `invite_accepted`,
/// `pantry_item_added` and `grocery_generated`; those arrive with the sprints
/// that own those features (41, 48, 51). An event class with no call site is a
/// dashboard promising a series that will always be empty.
@immutable
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// The wire name. Snake case, matching §10's table exactly — these strings end
  /// up as rows in a warehouse, and renaming one splits its own history in two.
  String get name;

  /// The event's properties, already reduced to primitives.
  ///
  /// Null values are kept rather than dropped: "this spin had no blocking
  /// constraint" and "this spin did not record one" are different facts, and
  /// collapsing them makes the no-match funnel unreadable.
  Map<String, Object?> get properties;

  @override
  String toString() => '$name $properties';
}

/// The app came to the foreground.
///
/// [isCold] separates a launch from a resume, which matters because the session
/// clock behind Time to Decision restarts on both — see `SessionClock`.
final class AppOpened extends AnalyticsEvent {
  const AppOpened({required this.isCold});

  final bool isCold;

  @override
  String get name => 'app_open';

  @override
  Map<String, Object?> get properties => <String, Object?>{'cold': isCold};
}

/// A spin was asked for.
final class SpinStarted extends AnalyticsEvent {
  const SpinStarted({
    required this.filtersApplied,
    required this.householdSize,
    required this.spinCountThisSession,
  });

  /// How many constraints the reader had chosen — not which ones.
  ///
  /// The count answers the question this event exists for: does narrowing help
  /// people decide, or does it strand them? *Which* filters were set is a
  /// different question, and `no_match` answers it for the spins where it
  /// mattered.
  final int filtersApplied;

  /// How many people are being cooked for.
  ///
  /// The reader's preferred servings. Households are Sprint 41; until then this
  /// is the closest true statement available about the size of the table.
  final int householdSize;

  /// Which spin this is since the last accepted meal — 1 for the first.
  ///
  /// Pairs with `meal_accepted.spin_count`: a session that ends at spin 1 and a
  /// session that ends at spin 9 are the same accepted meal and two very
  /// different products.
  final int spinCountThisSession;

  @override
  String get name => 'spin_started';

  @override
  Map<String, Object?> get properties => <String, Object?>{
    'filters_applied': filtersApplied,
    'household_size': householdSize,
    'spin_count': spinCountThisSession,
  };
}

/// A spin produced a meal.
final class SpinCompleted extends AnalyticsEvent {
  const SpinCompleted({
    required this.mealId,
    required this.score,
    required this.candidatePoolSize,
    required this.latency,
  });

  final String mealId;

  /// The winner's score, out of the scorer's weight table.
  final double score;

  /// How many meals the weighted draw chose between.
  ///
  /// A pool of one is not a recommendation, and the difference between "we chose
  /// well" and "there was nothing else" is invisible without this.
  final int candidatePoolSize;

  /// How long the pick took — the query, the scoring and the draw.
  ///
  /// Not how long the animation took. The animation is a fixed 2.2 s by design,
  /// so measuring it would produce a flat line; what can regress is the work
  /// happening underneath it, and the spin only feels instant while this stays
  /// shorter than the reel.
  final Duration latency;

  @override
  String get name => 'spin_completed';

  @override
  Map<String, Object?> get properties => <String, Object?>{
    'meal_id': mealId,
    // Three places. The score is a means to a ranking, and a warehouse full of
    // seventeen-digit doubles compresses badly for no insight gained.
    'score': double.parse(score.toStringAsFixed(3)),
    'pool_size': candidatePoolSize,
    'latency_ms': latency.inMilliseconds,
  };
}

/// The reader said yes. **This is the north-star event.**
final class MealAccepted extends AnalyticsEvent {
  const MealAccepted({
    required this.mealId,
    required this.sinceAppOpen,
    required this.spinCount,
  });

  final String mealId;

  /// Time to Decision, in full.
  ///
  /// docs/ARCHITECTURE.md §10: "`meal_accepted.seconds_since_app_open` **is**
  /// Time to Decision. Everything else is diagnostic." Measured from the session
  /// clock rather than from the spin, because the product's promise is about
  /// opening the app and knowing what is for dinner — the browsing and the
  /// filter-fiddling before the first spin are part of that cost, and a
  /// measurement starting at the spin would flatter it.
  final Duration sinceAppOpen;

  /// How many spins it took.
  final int spinCount;

  @override
  String get name => 'meal_accepted';

  @override
  Map<String, Object?> get properties => <String, Object?>{
    'meal_id': mealId,
    // Seconds, as §10 names the field — and whole seconds, because the metric
    // has a 60-second target and nobody is going to argue over 400 ms of it.
    'seconds_since_app_open': sinceAppOpen.inSeconds,
    'spin_count': spinCount,
  };
}

/// The reader said no and asked for another.
final class MealRejected extends AnalyticsEvent {
  const MealRejected({required this.mealId, required this.spinCount});

  final String mealId;
  final int spinCount;

  @override
  String get name => 'meal_rejected';

  @override
  Map<String, Object?> get properties => <String, Object?>{
    'meal_id': mealId,
    'spin_count': spinCount,
  };
}

/// A spin had nothing to offer.
///
/// The one event whose property is a constraint name rather than an id, and it is
/// not PII: `budget`, `time` and `cuisine` are this app's own vocabulary. It is
/// also the whole point of the event — "spins fail" is not actionable, and "spins
/// fail on the time limit" is.
final class NoMatchFound extends AnalyticsEvent {
  const NoMatchFound({
    required this.blockingConstraint,
    required this.eligibleCount,
    required this.blockedByRepetition,
  });

  /// The constraint costing the reader dinner, or null when nothing was filtering
  /// and the pool itself was empty.
  final String? blockingConstraint;

  /// How many meals were eligible before the filters were applied.
  final int eligibleCount;

  /// How many were ruled out for having been eaten too recently.
  ///
  /// Separated from the filters because the fix is different: a filter is the
  /// reader's choice for tonight, the repetition window is a standing setting,
  /// and a spike here means the default window is too long rather than that
  /// people over-filter.
  final int blockedByRepetition;

  @override
  String get name => 'no_match';

  @override
  Map<String, Object?> get properties => <String, Object?>{
    'blocking_constraint': blockingConstraint,
    'eligible_count': eligibleCount,
    'blocked_by_repetition': blockedByRepetition,
  };
}
