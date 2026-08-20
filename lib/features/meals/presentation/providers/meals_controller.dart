import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';

part 'meals_controller.g.dart';

/// The feed as the screen needs to see it.
@immutable
class MealFeed {
  const MealFeed({
    required this.query,
    required this.meals,
    required this.hasMore,
    this.isReloading = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final MealQuery query;

  /// Every meal loaded so far, across all pages fetched for [query].
  final List<Meal> meals;
  final bool hasMore;

  /// The first page is being fetched again for a changed query.
  ///
  /// Held here rather than as an `AsyncValue.loading` around this object,
  /// because loading and having-data are both true at once and `AsyncValue`
  /// cannot say so without Riverpod's internal `copyWithPrevious`. The screen
  /// dims the list it already has instead of replacing it with a skeleton: a
  /// search that blanks the screen between every result set reads as broken.
  final bool isReloading;

  /// A page after the first is in flight.
  ///
  /// Separate from the `AsyncValue` around this object on purpose. Appending a
  /// page is not the same event as replacing the feed: putting the whole
  /// provider into a loading state would blank a screen the reader is part-way
  /// down, which is the most annoying possible response to reaching the bottom
  /// of a list.
  final bool isLoadingMore;

  /// Set when appending a page failed.
  ///
  /// Held here rather than thrown, for the same reason: a failed *third* page
  /// must not discard the two that loaded. The screen shows a retry at the foot
  /// of the list it already has.
  final AppException? loadMoreFailure;

  bool get isEmpty => meals.isEmpty;

  MealFeed copyWith({
    MealQuery? query,
    List<Meal>? meals,
    bool? hasMore,
    bool? isReloading,
    bool? isLoadingMore,
    AppException? loadMoreFailure,
    bool clearLoadMoreFailure = false,
  }) {
    return MealFeed(
      query: query ?? this.query,
      meals: meals ?? this.meals,
      hasMore: hasMore ?? this.hasMore,
      isReloading: isReloading ?? this.isReloading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : loadMoreFailure ?? this.loadMoreFailure,
    );
  }
}

/// Drives the Meals tab (docs/USER_FLOWS.md §7).
///
/// Holds the query and the pages fetched for it. `keepAlive`, so switching to
/// another tab and back does not throw away a scrolled feed and re-fetch it —
/// docs/NAVIGATION_MAP.md §8 requires the tab to keep its place, and the
/// `IndexedStack` preserves the scroll offset only if the list under it still
/// has the same items.
@Riverpod(keepAlive: true)
class MealsController extends _$MealsController {
  MealQuery _query = const MealQuery();

  @override
  Future<MealFeed> build() => _firstPage(_query);

  /// Replaces the query and reloads from the first page.
  ///
  /// A no-op when nothing changed, which matters more than it looks: the search
  /// field reports the same text when a keystroke is undone within the debounce
  /// window, and re-fetching for it would flicker the list for no reason.
  Future<void> applyQuery(MealQuery query) async {
    if (query == _query) {
      return;
    }
    _query = query;

    _markReloading();
    state = await AsyncValue.guard(() => _firstPage(query));
  }

  /// Convenience wrappers, so screens do not each rebuild a query object.
  Future<void> search(String term) =>
      applyQuery(_query.copyWith(search: term.trim()));

  Future<void> toggleCuisine(Cuisine cuisine) =>
      applyQuery(_query.toggleCuisine(cuisine));

  Future<void> toggleCategory(MealCategory category) =>
      applyQuery(_query.toggleCategory(category));

  Future<void> clearFilters() => applyQuery(_query.cleared());

  /// Appends the next page.
  ///
  /// Guarded three ways: nothing loaded yet, a page already in flight, or no
  /// further page. The scroll listener fires on every frame near the bottom, so
  /// without those guards reaching the end of the list starts a dozen requests.
  Future<void> loadMore() async {
    final MealFeed? feed = state.value;
    if (feed == null || feed.isLoadingMore || !feed.hasMore) {
      return;
    }

    state = AsyncValue<MealFeed>.data(
      feed.copyWith(isLoadingMore: true, clearLoadMoreFailure: true),
    );

    try {
      final MealPage page = await ref
          .read(mealRepositoryProvider)
          .search(query: feed.query, offset: feed.meals.length);

      // The query may have changed while this was in flight — a filter tapped
      // mid-request. Appending stale rows to a new feed would mix two result
      // sets, so the late answer is dropped instead.
      final MealFeed? current = state.value;
      if (current == null || current.query != feed.query) {
        return;
      }

      state = AsyncValue<MealFeed>.data(
        current.copyWith(
          meals: <Meal>[...current.meals, ...page.meals],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      final MealFeed? current = state.value;
      if (current == null) {
        return;
      }
      state = AsyncValue<MealFeed>.data(
        current.copyWith(
          isLoadingMore: false,
          loadMoreFailure: ErrorMapper.map(error, stackTrace),
        ),
      );
    }
  }

  /// Reloads the current query from the first page.
  Future<void> refresh() async {
    _markReloading();
    state = await AsyncValue.guard(() => _firstPage(_query));
  }

  /// Flags the feed as reloading without discarding what is on screen.
  ///
  /// When there is nothing on screen yet, the state stays loading and the screen
  /// shows its skeleton — which is correct: there is no list to dim.
  void _markReloading() {
    final MealFeed? feed = state.value;
    state = feed == null
        ? const AsyncValue<MealFeed>.loading()
        : AsyncValue<MealFeed>.data(feed.copyWith(isReloading: true));
  }

  Future<MealFeed> _firstPage(MealQuery query) async {
    final MealPage page = await ref
        .read(mealRepositoryProvider)
        .search(query: query);

    return MealFeed(query: query, meals: page.meals, hasMore: page.hasMore);
  }
}
