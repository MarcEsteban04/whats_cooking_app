import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';

part 'meals_controller.g.dart';

/// The feed as the screen needs to see it.
@immutable
class MealFeed {
  const MealFeed({
    required this.query,
    required this.meals,
    required this.hasMore,
    int? loadedRowCount,
    this.hiddenSinceLoad = const <String>{},
    this.isReloading = false,
    this.isLoadingMore = false,
    this.loadMoreFailure,
    this.refreshFailure,
    this.cachedAt,
  }) : loadedRowCount = loadedRowCount ?? meals.length;

  final MealQuery query;

  /// Every meal loaded so far, across all pages fetched for [query].
  final List<Meal> meals;
  final bool hasMore;

  /// How many rows the *server* has returned for [query] — which is not
  /// `meals.length` once something has been hidden.
  ///
  /// This is what the next page's offset comes from, and the distinction is the
  /// whole reason it exists. Hiding a meal removes a row from [meals] without
  /// changing what the server would return for the same query, so an offset of
  /// `meals.length` would ask for row 39 when 40 rows have been read — and the
  /// reader would never see meal 40.
  final int loadedRowCount;

  /// Meals hidden since this query was loaded.
  ///
  /// The exclusion in [query] is applied by the server, and it was fixed when
  /// the first page was fetched. Anything hidden after that is dropped here
  /// instead: rows already on screen are removed, and rows still arriving from a
  /// page in flight are filtered out. A page can come back one short as a
  /// result, which is correct — [loadedRowCount] still counts what the server
  /// sent, so nothing is skipped.
  ///
  /// Cleared on every reload, where the server takes the exclusion over again.
  final Set<String> hiddenSinceLoad;

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

  /// Set when reloading the first page failed and this feed is what survived.
  ///
  /// The point of holding it rather than throwing is that the feed on screen is
  /// still a true answer to a query that did succeed — so it stays, with a
  /// banner saying the refresh did not land (Sprint 27). Replacing a working
  /// list with a full-screen "No connection" because a pull-to-refresh failed in
  /// a lift takes away the thing the reader could still use.
  ///
  /// Cleared by the next reload that works.
  final AppException? refreshFailure;

  /// When these meals were stored, if they came off the disk (Sprint 27).
  ///
  /// Null on every live feed. Non-null means the network could not answer and
  /// this is the catalogue the device had — which the screen says out loud,
  /// because a stale list presented as current is the app lying about the one
  /// thing it is for.
  final DateTime? cachedAt;

  bool get isEmpty => meals.isEmpty;

  /// How many meals this user has hidden from the feed.
  ///
  /// For the empty state, which owes the reader an explanation when a search
  /// finds nothing and part of the catalogue is hidden.
  int get hiddenCount => query.excludedMealIds.length + hiddenSinceLoad.length;

  MealFeed copyWith({
    MealQuery? query,
    List<Meal>? meals,
    bool? hasMore,
    int? loadedRowCount,
    Set<String>? hiddenSinceLoad,
    bool? isReloading,
    bool? isLoadingMore,
    AppException? loadMoreFailure,
    AppException? refreshFailure,
    DateTime? cachedAt,
    bool clearLoadMoreFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return MealFeed(
      query: query ?? this.query,
      meals: meals ?? this.meals,
      hasMore: hasMore ?? this.hasMore,
      loadedRowCount: loadedRowCount ?? this.loadedRowCount,
      hiddenSinceLoad: hiddenSinceLoad ?? this.hiddenSinceLoad,
      isReloading: isReloading ?? this.isReloading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : loadMoreFailure ?? this.loadMoreFailure,
      refreshFailure: clearRefreshFailure
          ? null
          : refreshFailure ?? this.refreshFailure,
      cachedAt: cachedAt ?? this.cachedAt,
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
  /// The last query that actually loaded.
  ///
  /// Only advanced on success (Sprint 27). A filter tapped offline used to leave
  /// this pointing at a query the feed had never fetched, so the next
  /// `applyQuery` compared against it, found no change, and did nothing —
  /// leaving the screen stuck until something else moved.
  MealQuery _query = const MealQuery();

  /// Which first-page request is the current one.
  ///
  /// Typing "adobo" fires a request at each debounce boundary, and responses do
  /// not have to come back in the order they were asked for: on a slow
  /// connection the answer for "ad" can land after the answer for "adobo" and
  /// overwrite it, leaving results that do not match the box the user is looking
  /// at. Only the newest request may write, and this is how it knows it is.
  int _requestId = 0;

  @override
  Future<MealFeed> build() async {
    _watchDislikes();

    final MealFeed feed = await _firstPage(_query);
    _query = feed.query;
    return feed;
  }

  /// Replaces the query and reloads from the first page.
  ///
  /// A no-op when nothing changed, which matters more than it looks: the search
  /// field reports the same text when a keystroke is undone within the debounce
  /// window, and re-fetching for it would flicker the list for no reason.
  Future<void> applyQuery(MealQuery query) async {
    if (query == _query) {
      return;
    }

    await _load(query);
  }

  /// Convenience wrappers, so screens do not each rebuild a query object.
  Future<void> search(String term) =>
      applyQuery(_query.copyWith(search: term.trim()));

  Future<void> toggleCuisine(Cuisine cuisine) =>
      applyQuery(_query.toggleCuisine(cuisine));

  Future<void> toggleCategory(MealCategory category) =>
      applyQuery(_query.toggleCategory(category));

  /// Narrows the feed to meals the kitchen already covers, or opens it back up
  /// (Sprint 41).
  ///
  /// Takes the id set rather than reading it, so the screen decides *when* to
  /// consult the pantry and this stays a filter setter like the others.
  Future<void> setCookableOnly(Set<String>? cookable) => applyQuery(
    cookable == null
        ? _query.copyWith(clearCookableOnly: true)
        : _query.copyWith(onlyMealIds: cookable),
  );

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
    if (feed.isReloading) {
      // A first page for a different query is already in flight, and `hasMore`
      // still describes the old one. Appending page two of the previous result
      // set to a feed that is about to be replaced is work thrown away at best,
      // and two result sets interleaved at worst.
      return;
    }

    state = AsyncValue<MealFeed>.data(
      feed.copyWith(isLoadingMore: true, clearLoadMoreFailure: true),
    );

    try {
      final MealPage page = await ref
          .read(mealRepositoryProvider)
          .search(query: feed.query, offset: feed.loadedRowCount);

      // The query may have changed while this was in flight — a filter tapped
      // mid-request. Appending stale rows to a new feed would mix two result
      // sets, so the late answer is dropped instead.
      final MealFeed? current = state.value;
      if (current == null || current.query != feed.query) {
        return;
      }

      state = AsyncValue<MealFeed>.data(
        current.copyWith(
          meals: <Meal>[
            ...current.meals,
            // Anything hidden while this page was in flight is dropped on
            // arrival rather than shown and taken away a frame later.
            ...page.meals.where(
              (Meal meal) => !current.hiddenSinceLoad.contains(meal.id),
            ),
          ],
          // Counted before that filtering, not after: this is the server's
          // offset, and the server does not know about the hiding.
          loadedRowCount: current.loadedRowCount + page.meals.length,
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
  Future<void> refresh() => _load(_query);

  /// Fetches the first page for [query] and installs it, or survives failing to.
  ///
  /// The failure handling is the part worth reading. Three outcomes:
  ///
  /// * **Superseded** — a newer request started while this one was in flight, so
  ///   this answer is dropped. Late results must never win.
  /// * **Failed with a feed on screen** — the old feed stays, with its own query
  ///   intact, and carries the failure as a banner. What is on screen is still a
  ///   true answer to a query that did load; blanking it because a filter tap
  ///   failed offline takes away the only usable thing left. Reverting the query
  ///   too is what keeps the list and the controls honest about each other.
  /// * **Failed with nothing on screen** — there is nothing to preserve, so the
  ///   error goes to the screen and it shows a full error state with a retry.
  Future<void> _load(MealQuery query) async {
    final int requestId = ++_requestId;
    final MealFeed? previous = state.value;

    _markReloading();

    try {
      final MealFeed feed = await _firstPage(query);

      if (requestId != _requestId) {
        return;
      }
      _query = feed.query;
      state = AsyncValue<MealFeed>.data(feed);
    } on Object catch (error, stackTrace) {
      if (requestId != _requestId) {
        return;
      }

      final AppException failure = ErrorMapper.map(error, stackTrace);

      if (previous == null) {
        state = AsyncValue<MealFeed>.error(failure, stackTrace);
        return;
      }

      state = AsyncValue<MealFeed>.data(
        previous.copyWith(isReloading: false, refreshFailure: failure),
      );
    }
  }

  /// Keeps the feed in step with the dislikes, wherever they were changed.
  ///
  /// This is why no screen has to remember to filter. Hiding a meal from the
  /// detail screen, or restoring one from the Hidden list, changes a single set,
  /// and the feed reacts here — once — instead of in every caller. US-B-07
  /// promises a hidden meal is *never* suggested, and a promise kept by
  /// convention at each call site is one that eventually breaks.
  ///
  /// The two directions are deliberately not symmetrical:
  ///
  /// * **Hidden** — the row is removed in place. A reload would also be correct,
  ///   and would also throw away every page after the first and drop the reader
  ///   back at the top of the list.
  /// * **Restored** — the feed reloads, because a meal coming back has to
  ///   reappear in sort order and there is no way to know where that is without
  ///   asking. Restoring happens on the Hidden screen, so the reload sits behind
  ///   another route and is invisible.
  void _watchDislikes() {
    ref.listen(dislikesControllerProvider, (
      AsyncValue<Set<String>>? previous,
      AsyncValue<Set<String>> next,
    ) {
      final Set<String>? before = previous?.value;
      final Set<String>? after = next.value;
      if (before == null || after == null) {
        // The first load, or a failed one. `_firstPage` reads the set directly,
        // so there is nothing to reconcile yet.
        return;
      }

      final Set<String> hidden = after.difference(before);
      if (hidden.isNotEmpty) {
        _hideLocally(hidden);
      }

      // Checked separately rather than as an else: a failed hide rolls the set
      // back, which arrives here as a restore, and the row has to return.
      if (before.difference(after).isNotEmpty) {
        refresh();
      }
    });
  }

  /// Drops [ids] from the loaded list without re-fetching.
  void _hideLocally(Set<String> ids) {
    final MealFeed? feed = state.value;
    if (feed == null) {
      return;
    }

    state = AsyncValue<MealFeed>.data(
      feed.copyWith(
        meals: feed.meals
            .where((Meal meal) => !ids.contains(meal.id))
            .toList(growable: false),
        // Remembered, so a page already in flight does not deliver them anyway.
        hiddenSinceLoad: <String>{...feed.hiddenSinceLoad, ...ids},
      ),
    );
  }

  /// Flags the feed as reloading without discarding what is on screen.
  ///
  /// When there is nothing on screen yet, the state stays loading and the screen
  /// shows its skeleton — which is correct: there is no list to dim.
  void _markReloading() {
    final MealFeed? feed = state.value;
    state = feed == null
        ? const AsyncValue<MealFeed>.loading()
        : AsyncValue<MealFeed>.data(
            // The banner from the last failed attempt goes as soon as a new one
            // starts. Leaving it up beside a spinner says two things at once.
            feed.copyWith(isReloading: true, clearRefreshFailure: true),
          );
  }

  Future<MealFeed> _firstPage(MealQuery query) async {
    // Set here rather than trusted from the caller, so that no screen can drop
    // the exclusion by building a query from scratch. Read rather than watched:
    // rebuilding the feed on every dislike would send the reader back to page
    // one, and `_watchDislikes` handles the change better than a rebuild could.
    //
    // A failed read fails the feed, deliberately. Showing a catalogue that we
    // know might contain hidden meals breaks the one promise this feature makes
    // (US-B-07), and the failure is retryable like any other.
    final Set<String> hidden = await ref.read(
      dislikesControllerProvider.future,
    );

    final MealQuery effective = query.copyWith(excludedMealIds: hidden);

    // `_query` is not assigned here. It advances only once this has returned a
    // page, so a query that failed to load never becomes the one the controller
    // thinks it is showing.
    final MealPage page = await ref
        .read(mealRepositoryProvider)
        .search(query: effective);

    return MealFeed(
      query: effective,
      meals: page.meals,
      hasMore: page.hasMore,
      cachedAt: page.cachedAt,
    );
  }
}
