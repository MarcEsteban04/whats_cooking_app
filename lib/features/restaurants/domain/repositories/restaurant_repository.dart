import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';

/// The places we eat out at (Sprint 45).
///
/// Household-scoped throughout, and no method takes a household id — the
/// repository resolves it from the session, and RLS refuses anything else, so the
/// two agree.
///
/// **No search and no pagination**, unlike meals. This list is places two people
/// actually go: a dozen, maybe twenty. Paging twenty rows is machinery for a
/// problem that does not exist, and a search field over a list you can see all of
/// is a control that makes the screen look bigger than it is. Revisit if it ever
/// passes a hundred, which is a measurement rather than a guess to make now.
abstract interface class RestaurantRepository {
  /// Everything, favourites first and then by name.
  Future<List<Restaurant>> all();

  /// Writes a new one.
  Future<Restaurant> create(RestaurantDraft draft);

  /// Rewrites an existing one.
  Future<Restaurant> update(String id, RestaurantDraft draft);

  /// Removes it.
  ///
  /// A real delete, unlike a meal's. Hiding exists for meals because the
  /// catalogue is public and cannot be deleted; every row here is one we wrote, so
  /// deleting it is available and honest — and a flag meaning "deleted but not
  /// really" is a flag somebody has to remember the rules of.
  Future<void> remove(String id);

  /// Marks it as one of ours, or stops.
  Future<Restaurant> setFavorite(String id, {required bool isFavorite});
}
