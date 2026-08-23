import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/in_memory_restaurant_repository.dart';
import 'package:whats_cooking/features/restaurants/data/repositories/supabase_restaurant_repository.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/domain/repositories/restaurant_repository.dart';

part 'restaurants_controller.g.dart';

/// The restaurants backend.
@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    AppLog.warning(
      'No backend: the restaurant list will not survive a restart.',
      name: 'restaurantRepository',
    );
    return InMemoryRestaurantRepository();
  }

  return SupabaseRestaurantRepository(ref.read(supabaseClientProvider));
}

/// The places we eat out at (Sprint 45).
///
/// **The whole list, in one read, held for the session.** No paging and no search
/// — see the repository for why twenty rows do not need either. That also means
/// Sprint 46's roulette can score over this without a second request, which is the
/// point of keeping it alive.
@Riverpod(keepAlive: true)
class RestaurantsController extends _$RestaurantsController {
  @override
  Future<List<Restaurant>> build() =>
      ref.read(restaurantRepositoryProvider).all();

  /// Writes a new place.
  ///
  /// Returns the failure rather than throwing, so the form can say so without a
  /// try/catch at every call site.
  Future<AppException?> create(RestaurantDraft draft) async {
    try {
      final Restaurant created = await ref
          .read(restaurantRepositoryProvider)
          .create(draft);

      state = AsyncData<List<Restaurant>>(
        _sorted(<Restaurant>[...state.value ?? const <Restaurant>[], created]),
      );
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Rewrites one.
  ///
  /// Named `edit` rather than `update` because Riverpod's `AsyncNotifier` already
  /// has an `update` with a different signature, and shadowing it is a silent trap
  /// for whoever next reaches for the framework method.
  Future<AppException?> edit(String id, RestaurantDraft draft) async {
    try {
      final Restaurant saved = await ref
          .read(restaurantRepositoryProvider)
          .update(id, draft);

      state = AsyncData<List<Restaurant>>(_replacing(saved));
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Takes it off the list.
  ///
  /// Optimistic, unlike the writes above: a delete has nothing to learn from the
  /// server, and the row should go the moment the confirmation is answered.
  Future<AppException?> remove(Restaurant restaurant) async {
    final List<Restaurant> before = state.value ?? const <Restaurant>[];

    state = AsyncData<List<Restaurant>>(<Restaurant>[
      for (final Restaurant existing in before)
        if (existing.id != restaurant.id) existing,
    ]);

    try {
      await ref.read(restaurantRepositoryProvider).remove(restaurant.id);
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<Restaurant>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Marks one as ours, or stops.
  ///
  /// Optimistic. A star that waits for a round trip is a star somebody taps twice
  /// — the same reasoning favourites use for meals.
  Future<AppException?> toggleFavorite(Restaurant restaurant) async {
    final List<Restaurant> before = state.value ?? const <Restaurant>[];
    final bool next = !restaurant.isFavorite;

    state = AsyncData<List<Restaurant>>(
      _sorted(_replacing(restaurant.copyWith(isFavorite: next))),
    );

    try {
      final Restaurant saved = await ref
          .read(restaurantRepositoryProvider)
          .setFavorite(restaurant.id, isFavorite: next);

      state = AsyncData<List<Restaurant>>(_sorted(_replacing(saved)));
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncData<List<Restaurant>>(before);
      return ErrorMapper.map(error, stackTrace);
    }
  }

  /// Re-reads the list, for pull-to-refresh.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(restaurantRepositoryProvider).all(),
    );
  }

  List<Restaurant> _replacing(Restaurant restaurant) => <Restaurant>[
    for (final Restaurant existing in state.value ?? const <Restaurant>[])
      if (existing.id == restaurant.id) restaurant else existing,
  ];

  /// Favourites first, then by name — the order the repository returns, kept in
  /// step here so a newly starred place moves to the top immediately rather than
  /// on the next refresh.
  static List<Restaurant> _sorted(List<Restaurant> items) {
    return List<Restaurant>.of(items)..sort((Restaurant a, Restaurant b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}

/// One place, by id, for the form and the detail row.
///
/// Reads the loaded list rather than fetching: the whole list is already here, and
/// a second request for a row we are holding is a round trip to learn nothing.
@riverpod
Restaurant? restaurantById(Ref ref, String id) {
  final List<Restaurant> all =
      ref.watch(restaurantsControllerProvider).value ?? const <Restaurant>[];

  for (final Restaurant restaurant in all) {
    if (restaurant.id == id) {
      return restaurant;
    }
  }
  return null;
}
