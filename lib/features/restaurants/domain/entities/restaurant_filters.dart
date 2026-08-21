import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';

/// One thing narrowing a night out (Sprint 46).
///
/// The same shape `SpinConstraint` has for meals, and for the same reason: the
/// no-match state has to name what emptied the pool and offer the one relaxation
/// that opens the most options, which is impossible to write against four nullable
/// fields.
///
/// **There is no dietary constraint here.** A restaurant row records what a place
/// costs and how far it is, not what its kitchen can leave out — so promising a
/// vegetarian a safe menu from this data would be a promise the app cannot keep.
/// Dietary needs are a hard filter on *meals* precisely because a meal's
/// ingredients are known; pretending the same certainty about a restaurant would be
/// the worst kind of feature.
enum RestaurantConstraint {
  budget('the budget'),
  cuisine('the cuisine'),
  distance('how far'),
  delivery('needing delivery');

  const RestaurantConstraint(this.label);

  /// How the no-match state refers to it, mid-sentence.
  final String label;
}

/// What the restaurant roulette is allowed to offer (Sprint 46).
///
/// Applied in Dart, like the meal filters and for the same reason: the whole pool
/// arrives in one request, so exact answers to "how many would come back if I
/// dropped *this*" are free.
@immutable
class RestaurantFilters {
  const RestaurantFilters({
    this.maxCostPerHead,
    this.cuisines = const <Cuisine>{},
    this.maxDistance,
    this.mustDeliver = false,
    this.mood,
  });

  /// Pesos a head.
  final int? maxCostPerHead;

  /// Empty means every cuisine, not none.
  final Set<Cuisine> cuisines;

  /// The furthest we are willing to go, or null for anywhere.
  ///
  /// A **ceiling**, not a set. "Nothing further than a short ride" is how somebody
  /// holds it; "walkable or worth the trip but not a short ride" is not — the same
  /// reasoning `max_difficulty` uses for meals, and it relies on [Proximity] being
  /// declared nearest-first.
  final Proximity? maxDistance;

  /// Only places that deliver.
  ///
  /// A filter rather than a preference, because on the night it is set it is
  /// absolute: somebody who does not want to leave the house is not talked into it
  /// by a good score.
  final bool mustDeliver;

  /// What we are in the mood for.
  ///
  /// Not a [RestaurantConstraint], for the reason the meal filters give: a mood
  /// moves scores and hands the engine the pool it was given, so it can never be
  /// the thing that emptied it.
  final Mood? mood;

  /// Whether [place] survives every filter here.
  bool allows(Restaurant place) => blockers(place).isEmpty;

  /// Which of these filters [place] fails.
  ///
  /// Every one rather than the first, because the count that matters is how many
  /// places a *given* filter is costing — and a place blocked by two is not
  /// evidence against either on its own.
  Set<RestaurantConstraint> blockers(Restaurant place) {
    return <RestaurantConstraint>{
      if (maxCostPerHead case final int limit)
        if (place.costPerHead > limit) RestaurantConstraint.budget,
      if (cuisines.isNotEmpty && !cuisines.contains(place.cuisine))
        RestaurantConstraint.cuisine,
      if (maxDistance case final Proximity limit)
        if (place.proximity.index > limit.index) RestaurantConstraint.distance,
      if (mustDeliver && !place.delivers) RestaurantConstraint.delivery,
    };
  }

  /// The constraints currently narrowing anything.
  Set<RestaurantConstraint> get active => <RestaurantConstraint>{
    if (maxCostPerHead != null) RestaurantConstraint.budget,
    if (cuisines.isNotEmpty) RestaurantConstraint.cuisine,
    if (maxDistance != null) RestaurantConstraint.distance,
    if (mustDeliver) RestaurantConstraint.delivery,
  };

  int get chosenCount => active.length;

  bool get hasChosen => chosenCount > 0;

  /// The same filters with [constraint] dropped.
  RestaurantFilters without(RestaurantConstraint constraint) {
    return switch (constraint) {
      RestaurantConstraint.budget => copyWith(clearBudget: true),
      RestaurantConstraint.cuisine => copyWith(cuisines: const <Cuisine>{}),
      RestaurantConstraint.distance => copyWith(clearDistance: true),
      RestaurantConstraint.delivery => copyWith(mustDeliver: false),
    };
  }

  /// Drops everything, keeping the mood.
  ///
  /// The mood survives a clear-all because clearing filters is a request to widen
  /// the search, not a change of appetite.
  RestaurantFilters cleared() => RestaurantFilters(mood: mood);

  /// How this constraint currently reads, for the no-match sentence.
  String describe(RestaurantConstraint constraint) {
    return switch (constraint) {
      RestaurantConstraint.budget =>
        'under ${AppFormat.peso(maxCostPerHead ?? 0)} a head',
      RestaurantConstraint.cuisine => _list(
        cuisines.map((Cuisine c) => c.label),
      ),
      RestaurantConstraint.distance =>
        'within ${maxDistance?.phrase ?? 'reach'}',
      RestaurantConstraint.delivery => 'that delivers',
    };
  }

  RestaurantFilters copyWith({
    int? maxCostPerHead,
    Set<Cuisine>? cuisines,
    Proximity? maxDistance,
    bool? mustDeliver,
    Mood? mood,
    bool clearBudget = false,
    bool clearDistance = false,
    bool clearMood = false,
  }) {
    return RestaurantFilters(
      maxCostPerHead: clearBudget
          ? null
          : (maxCostPerHead ?? this.maxCostPerHead),
      cuisines: cuisines ?? this.cuisines,
      maxDistance: clearDistance ? null : (maxDistance ?? this.maxDistance),
      mustDeliver: mustDeliver ?? this.mustDeliver,
      mood: clearMood ? null : (mood ?? this.mood),
    );
  }

  /// `Japanese`, `Japanese or Korean`, `Japanese, Korean or Thai`.
  static String _list(Iterable<String> parts) {
    final List<String> items = parts.toList();
    return switch (items.length) {
      0 => '',
      1 => items.first,
      2 => '${items.first} or ${items[1]}',
      _ => '${items.take(items.length - 1).join(', ')} or ${items.last}',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RestaurantFilters &&
      other.maxCostPerHead == maxCostPerHead &&
      setEquals(other.cuisines, cuisines) &&
      other.maxDistance == maxDistance &&
      other.mustDeliver == mustDeliver &&
      other.mood == mood;

  @override
  int get hashCode => Object.hash(
    maxCostPerHead,
    Object.hashAllUnordered(cuisines),
    maxDistance,
    mustDeliver,
    mood,
  );
}
