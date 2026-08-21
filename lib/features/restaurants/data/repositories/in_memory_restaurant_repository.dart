import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/repositories/restaurant_repository.dart';

/// [RestaurantRepository] with no backend behind it.
///
/// So a clone with no Supabase credentials still runs (supabase/README.md). The
/// list does not survive a restart, and the log says so when this is chosen.
///
/// Starts empty, deliberately. Every other in-memory repository in this app seeds
/// something so a screen has shape — but a made-up list of restaurants would be
/// places in a city the reader may not live in, which is the exact thing the real
/// feature refuses to ship.
class InMemoryRestaurantRepository implements RestaurantRepository {
  final List<Restaurant> _restaurants = <Restaurant>[];

  int _nextId = 0;

  @override
  Future<List<Restaurant>> all() async {
    final List<Restaurant> sorted = List<Restaurant>.of(_restaurants)
      ..sort((Restaurant a, Restaurant b) {
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  @override
  Future<Restaurant> create(RestaurantDraft draft) async {
    if (!draft.isComplete) {
      throw const ValidationException(
        message: 'Give it a name and roughly what a meal costs.',
      );
    }

    // The same uniqueness `restaurants_name_unique` enforces.
    final bool duplicate = _restaurants.any(
      (Restaurant existing) =>
          existing.name.toLowerCase() == draft.name.trim().toLowerCase(),
    );
    if (duplicate) {
      throw const ValidationException(
        message: 'That place is already on the list.',
      );
    }

    final Restaurant created = _fromDraft('restaurant-${_nextId++}', draft);
    _restaurants.add(created);
    return created;
  }

  @override
  Future<Restaurant> update(String id, RestaurantDraft draft) async {
    final int index = _indexOf(id);
    return _restaurants[index] = _fromDraft(
      id,
      draft,
      isFavorite: _restaurants[index].isFavorite,
    );
  }

  @override
  Future<void> remove(String id) async {
    _restaurants.removeWhere((Restaurant existing) => existing.id == id);
  }

  @override
  Future<Restaurant> setFavorite(
    String id, {
    required bool isFavorite,
  }) async {
    final int index = _indexOf(id);
    return _restaurants[index] = _restaurants[index].copyWith(
      isFavorite: isFavorite,
    );
  }

  int _indexOf(String id) {
    final int index = _restaurants.indexWhere(
      (Restaurant existing) => existing.id == id,
    );
    if (index < 0) {
      throw const NotFoundException(message: 'That place is no longer here.');
    }
    return index;
  }

  static Restaurant _fromDraft(
    String id,
    RestaurantDraft draft, {
    bool isFavorite = false,
  }) {
    return Restaurant(
      id: id,
      name: draft.name.trim(),
      cuisine: draft.cuisine,
      costPerHead: draft.costPerHead ?? 0,
      proximity: draft.proximity,
      delivers: draft.delivers,
      notes: draft.notes.trim().isEmpty ? null : draft.notes.trim(),
      goToOrder: draft.goToOrder.trim().isEmpty ? null : draft.goToOrder.trim(),
      tags: draft.tags,
      isFavorite: isFavorite,
    );
  }
}
