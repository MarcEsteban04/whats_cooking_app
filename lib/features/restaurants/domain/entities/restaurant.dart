import 'package:flutter/foundation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// How far away, as a decision rather than a distance (Sprint 45).
///
/// **Three values, and no kilometres.** A distance would need a location
/// permission, a maps provider and a coordinate per row, to produce a number
/// nobody uses — at seven in the evening the real question is *can we walk, do we
/// have to ride, or is it a trip*. These are the answers, and they cost nothing.
///
/// Ordered nearest first, so a list sorted on `index` puts the easy options at the
/// top without a comparator that has to be kept in step with this.
enum Proximity {
  walk('Walk', 'walking distance'),
  shortRide('Short ride', 'a short ride'),
  worthTheTrip('Worth the trip', 'a proper trip');

  const Proximity(this.label, this.phrase);

  /// On a chip or a filter.
  final String label;

  /// Mid-sentence, for the no-match line: "nothing within walking distance".
  final String phrase;

  /// Snake case, matching the `proximity` enum in Postgres.
  String get value => switch (this) {
    Proximity.walk => 'walk',
    Proximity.shortRide => 'short_ride',
    Proximity.worthTheTrip => 'worth_the_trip',
  };

  static Proximity fromValue(String? value) {
    for (final Proximity option in Proximity.values) {
      if (option.value == value) {
        return option;
      }
    }
    // A middle default rather than throwing. A proximity added to the database
    // ahead of the app should not make the list unopenable, and "a short ride" is
    // the least wrong guess.
    return Proximity.shortRide;
  }
}

/// A place we eat out at (docs/DATABASE.md §4.15).
///
/// **Ours, always.** Unlike a meal there is no public catalogue and no
/// `is_public` — a seeded list of places somebody else likes in a city we may not
/// live in is worse than an empty screen, because an empty screen at least asks
/// the right question.
///
/// The most valuable field is [goToOrder], and it is the reason this is a list
/// kept by hand rather than a maps integration: no API returns what we get there.
@immutable
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.costPerHead,
    this.proximity = Proximity.shortRide,
    this.delivers = false,
    this.notes,
    this.goToOrder,
    this.tags = const <String>[],
    this.isFavorite = false,
  });

  factory Restaurant.fromRow(Map<String, dynamic> row) {
    return Restaurant(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      // Unrecognised cuisines fall back rather than throwing: one retired from
      // the app should not make the screen unopenable for whoever picked it.
      cuisine:
          Cuisine.fromValue(row['cuisine'] as String? ?? '') ?? Cuisine.other,
      costPerHead: (row['cost_per_head'] as num?)?.toDouble() ?? 0,
      proximity: Proximity.fromValue(row['proximity'] as String?),
      delivers: row['delivers'] as bool? ?? false,
      notes: row['notes'] as String?,
      goToOrder: row['go_to_order'] as String?,
      tags: <String>[
        for (final Object? tag
            in (row['tags'] as List<Object?>?) ?? const <Object?>[])
          if (tag is String) tag,
      ],
      isFavorite: row['is_favorite'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final Cuisine cuisine;

  /// Pesos a head, not a bill. The number both roulettes filter on, and the one
  /// two people actually think in.
  final double costPerHead;

  final Proximity proximity;
  final bool delivers;

  final String? notes;

  /// What we get there.
  final String? goToOrder;

  /// The same vocabulary `meals.tags` uses, so the moods work here too.
  final List<String> tags;

  /// A boolean rather than a join table, unlike `favorite_meals`.
  ///
  /// That table exists because meals are shared and public while a favourite is
  /// one person's opinion. These rows are household-private and written by the
  /// only person who edits them, so a per-user join would be a second table and a
  /// join for nothing.
  final bool isFavorite;

  /// Enough to tell two places apart in a list: cuisine, cost, how far.
  String get summary => <String>[
    cuisine.label,
    '₱${costPerHead.round()} a head',
    proximity.label.toLowerCase(),
    if (delivers) 'delivers',
  ].join(' · ');

  Restaurant copyWith({bool? isFavorite}) {
    return Restaurant(
      id: id,
      name: name,
      cuisine: cuisine,
      costPerHead: costPerHead,
      proximity: proximity,
      delivers: delivers,
      notes: notes,
      goToOrder: goToOrder,
      tags: tags,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Restaurant &&
      other.id == id &&
      other.name == name &&
      other.cuisine == cuisine &&
      other.costPerHead == costPerHead &&
      other.proximity == proximity &&
      other.delivers == delivers &&
      other.notes == notes &&
      other.goToOrder == goToOrder &&
      other.isFavorite == isFavorite &&
      other.tags.length == tags.length;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cuisine,
    costPerHead,
    proximity,
    delivers,
    notes,
    goToOrder,
    isFavorite,
    tags.length,
  );

  @override
  String toString() => 'Restaurant($name, $summary)';
}

/// A restaurant being written or rewritten.
///
/// Separate from [Restaurant] because a draft has no id and may be incomplete —
/// the same split `MealDraft` makes, and for the same reason: a form's state is
/// not a saved thing, and letting one type be both means every field has to be
/// nullable for the benefit of the half hour it spends being typed.
@immutable
class RestaurantDraft {
  const RestaurantDraft({
    this.name = '',
    this.cuisine = Cuisine.filipino,
    this.costPerHead,
    this.proximity = Proximity.shortRide,
    this.delivers = false,
    this.notes = '',
    this.goToOrder = '',
    this.tags = const <String>[],
  });

  /// A draft that would save [restaurant] unchanged.
  factory RestaurantDraft.from(Restaurant restaurant) => RestaurantDraft(
    name: restaurant.name,
    cuisine: restaurant.cuisine,
    costPerHead: restaurant.costPerHead,
    proximity: restaurant.proximity,
    delivers: restaurant.delivers,
    notes: restaurant.notes ?? '',
    goToOrder: restaurant.goToOrder ?? '',
    tags: restaurant.tags,
  );

  final String name;
  final Cuisine cuisine;

  /// Null while nothing has been typed. The column is `not null`, so saving
  /// requires it — but a form that shows "0" before anybody has answered is a form
  /// that has answered for them.
  final double? costPerHead;

  final Proximity proximity;
  final bool delivers;
  final String notes;
  final String goToOrder;
  final List<String> tags;

  /// Whether this is enough to save.
  ///
  /// A name and a cost. Everything else has a defensible default, and a form that
  /// demands notes before it will accept "Ramen Nagi, ₱450" is a form somebody
  /// abandons at the third field.
  bool get isComplete => name.trim().isNotEmpty && (costPerHead ?? 0) > 0;

  RestaurantDraft copyWith({
    String? name,
    Cuisine? cuisine,
    double? costPerHead,
    Proximity? proximity,
    bool? delivers,
    String? notes,
    String? goToOrder,
    List<String>? tags,
  }) {
    return RestaurantDraft(
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      costPerHead: costPerHead ?? this.costPerHead,
      proximity: proximity ?? this.proximity,
      delivers: delivers ?? this.delivers,
      notes: notes ?? this.notes,
      goToOrder: goToOrder ?? this.goToOrder,
      tags: tags ?? this.tags,
    );
  }

  /// The row this draft writes.
  ///
  /// `household_id` and `created_by` are absent deliberately: they are not the
  /// caller's to choose, the repository fills them from the session, and the RLS
  /// policy checks the same thing.
  Map<String, Object?> toRow() => <String, Object?>{
    'name': name.trim(),
    'cuisine': cuisine.value,
    'cost_per_head': costPerHead,
    'proximity': proximity.value,
    'delivers': delivers,
    // Empty strings become null. A column holding '' and a column holding null
    // are the same fact stored two ways, and the second one is the one every
    // `case final String` check in the app already handles.
    'notes': notes.trim().isEmpty ? null : notes.trim(),
    'go_to_order': goToOrder.trim().isEmpty ? null : goToOrder.trim(),
    'tags': tags,
  };
}
