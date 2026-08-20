import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/meal_card.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/search_field.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_filter_bar.dart';

/// The Meals tab (docs/design_ui.md §15, docs/USER_FLOWS.md §7).
///
/// A premium food discovery feed: search, two rows of filter pills, then large
/// cards. Every state §7 lists is rendered — skeleton, friendly retry, an empty
/// result that offers a way out, and the feed itself with pagination.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({this.autofocusSearch = false, super.key});

  /// Set for `/meals/search`, which exists so Home's search affordance lands on
  /// this screen with the keyboard already up (docs/USER_FLOWS.md §6).
  final bool autofocusSearch;

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<MealFeed> feed = ref.watch(mealsControllerProvider);
    final MealsController controller = ref.read(
      mealsControllerProvider.notifier,
    );

    // `feed.value` rather than `feed.when`: the filter bar has to keep rendering
    // the current query while the next page is in flight. Blanking the controls
    // you just used, for as long as the request takes, is how a fast filter
    // starts to feel slow.
    final MealFeed? current = feed.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              filterCount: current?.query.filterCount ?? 0,
              onClear: current?.query.hasFilters ?? false
                  ? controller.clearFilters
                  : null,
              onAdd: () => context.pushNamed(AppRoute.mealCreate.routeName),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.screenMargin,
              ),
              child: SearchField(
                autofocus: widget.autofocusSearch,
                hint: 'Search meals',
                // Debounced at 300 ms inside the field itself
                // (docs/USER_FLOWS.md §7).
                onSearch: controller.search,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            if (current != null)
              MealFilterBar(
                query: current.query,
                onCategoryToggled: controller.toggleCategory,
                onCuisineToggled: controller.toggleCuisine,
                onCategoriesCleared: () => controller.applyQuery(
                  current.query.copyWith(categories: const <MealCategory>{}),
                ),
                onCuisinesCleared: () => controller.applyQuery(
                  current.query.copyWith(cuisines: const <Cuisine>{}),
                ),
              ),
            const SizedBox(height: AppSpacing.space4),
            Expanded(
              child: switch (feed) {
                // Only when there is nothing to show yet. A reload that already
                // has meals keeps them on screen — see `_Feed`.
                AsyncLoading<MealFeed>() when current == null =>
                  const _FeedSkeleton(),
                AsyncError<MealFeed>(:final Object error)
                    when current == null =>
                  _FeedError(
                    failure: error is AppException
                        ? error
                        : const UnknownException(),
                    onRetry: controller.refresh,
                  ),
                _ => _Feed(
                  feed: current!,
                  onLoadMore: controller.loadMore,
                  onRefresh: controller.refresh,
                  onClearFilters: controller.clearFilters,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The title row, with a clear-all that appears only when there is something to
/// clear.
class _Header extends StatelessWidget {
  const _Header({
    required this.filterCount,
    required this.onClear,
    required this.onAdd,
  });

  final int filterCount;
  final VoidCallback? onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenMargin,
        AppSpacing.space4,
        AppLayout.screenMargin,
        AppSpacing.space4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('Meals', style: context.text.headlineLarge)),
          if (onClear != null)
            AppButton.tertiary(
              label: filterCount > 0 ? 'Clear ($filterCount)' : 'Clear',
              size: AppButtonSize.small,
              onPressed: onClear,
            ),
          const SizedBox(width: AppSpacing.space2),
          // The catalogue is sixty meals somebody else chose. This is where a
          // household's own food gets in.
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              boxShadow: context.shadows.xs,
            ),
            child: AppIconButton(
              icon: AppIcons.add,
              semanticLabel: 'Add a meal of your own',
              iconSize: AppIconSize.sm,
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

/// The list, its footer, and pull-to-refresh.
class _Feed extends StatefulWidget {
  const _Feed({
    required this.feed,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final MealFeed feed;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onClearFilters;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Asks for the next page while there is still a screenful to read.
  ///
  /// A scroll listener rather than fetching when a sentinel widget builds:
  /// starting a request from `build` is a state change during build, which
  /// Riverpod refuses. The controller guards re-entry, so the fact that this
  /// fires on every frame near the bottom is harmless.
  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.extentAfter < _prefetchExtent) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MealFeed feed = widget.feed;

    if (feed.isEmpty) {
      // Scrollable, and that is not defensive padding. The empty state appears
      // most often right after a search, which is exactly when the keyboard has
      // taken half the screen — and an empty state that overflows is a worse
      // answer than the no results it is reporting.
      //
      // Making it a scroll view also keeps pull-to-refresh working here, which a
      // `RefreshIndicator` cannot do around a non-scrolling child.
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _FeedEmpty(
                  feed: feed,
                  onClearFilters: widget.onClearFilters,
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Opacity(
        // Dimmed, not replaced. A filter change re-queries the catalogue, and
        // swapping the list for a skeleton every time somebody taps a pill makes
        // an instant interaction feel like a page load.
        opacity: feed.isReloading ? _reloadingOpacity : 1,
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.only(
            left: AppLayout.screenMargin,
            right: AppLayout.screenMargin,
            // Clears the floating navigation (docs/COMPONENTS.md §8).
            bottom: AppLayout.scrollBottomPadding,
          ),
          itemCount: feed.meals.length + 1,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: AppLayout.gridGap),
          itemBuilder: (BuildContext context, int index) {
            if (index == feed.meals.length) {
              return _FeedFooter(feed: feed, onRetry: widget.onLoadMore);
            }

            final Meal meal = feed.meals[index];

            return MealCard(
              meal: MealCardData(
                id: meal.id,
                name: meal.name,
                description: meal.description,
                cuisine: meal.cuisine.label,
                category: meal.category.label,
                difficulty: meal.difficulty.label,
                cookingTimeMinutes: meal.cookingTimeMinutes,
                estimatedCost: meal.estimatedCost,
                servings: meal.servings,
                isMine: meal.isMine,
              ),
              // Favouriting arrives with the favourites feature (Sprint 24).
              // The heart is hidden rather than shown-and-inert: a heart that
              // does nothing when tapped is worse than no heart.
              onTap: () => context.goNamed(
                AppRoute.mealDetail.routeName,
                pathParameters: <String, String>{'id': meal.id},
              ),
            );
          },
        ),
      ),
    );
  }

  /// Start fetching about two cards before the end.
  static const double _prefetchExtent = 600;
  static const double _reloadingOpacity = 0.45;
}

/// What sits under the last card.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.feed, required this.onRetry});

  final MealFeed feed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (feed.loadMoreFailure case final AppException failure) {
      // The pages already loaded stay on screen. Only the page that failed is
      // retried.
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space4),
        child: InlineErrorBanner(
          message: failure.displayMessage ?? failure.message,
          onRetry: onRetry,
        ),
      );
    }

    if (feed.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space6),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (feed.hasMore) {
      return const SizedBox(height: AppSpacing.space6);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space6),
      child: Text(
        // Says the list ended, rather than leaving the reader to wonder whether
        // it is still loading. The count is the honest version of "that is all".
        'That is all ${feed.meals.length} of them',
        style: context.text.metadata,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// No results — with a way out.
class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.feed, required this.onClearFilters});

  final MealFeed feed;
  final Future<void> Function() onClearFilters;

  @override
  Widget build(BuildContext context) {
    final String? narrowest = feed.query.narrowestFilterLabel;

    // docs/USER_FLOWS.md §7: "An empty result set offers to relax the narrowest
    // filter." Naming which one is the difference between a dead end and one
    // tap out of it.
    if (narrowest != null) {
      return EmptyState(
        title: 'Nothing matches',
        body: 'Try relaxing $narrowest.',
        emoji: '🔍',
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
      );
    }

    // No filters and still nothing: the catalogue itself is empty, which in
    // practice means the seed has not been applied to this project.
    return const EmptyState(
      title: 'No meals yet',
      body: 'The catalogue is empty. Nothing to browse just yet.',
      emoji: '🍽️',
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.failure, required this.onRetry});

  final AppException failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      kind: failure.errorStateKind,
      body: failure.displayMessage,
      errorCode: failure.supportCode,
      onRetry: failure.shouldOfferRetry ? onRetry : null,
    );
  }
}

/// The first-load placeholder (docs/COMPONENTS.md §11).
///
/// Card-shaped skeletons rather than a spinner, so the screen that arrives is
/// the shape of the screen that was promised.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenMargin),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _count,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppLayout.gridGap),
      itemBuilder: (BuildContext context, int index) =>
          const _MealCardSkeleton(),
    );
  }

  static const int _count = 3;
}

/// One feed card, in outline.
///
/// The same proportions as `MealCard.feed` — a 4:3 block, a title line, a
/// shorter metadata line — because docs/COMPONENTS.md §11's point is that the
/// placeholder should be the shape of what arrives. A spinner tells you to wait;
/// this tells you what for.
///
/// Local to this screen rather than in `core/`: the roulette and the favourites
/// list will want their own shapes, and one shared skeleton with three variants
/// is a component built before anyone asked for it.
class _MealCardSkeleton extends StatelessWidget {
  const _MealCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.borderXl,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: _imageAspect,
            child: AppSkeleton(borderRadius: AppRadius.borderXl),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppSkeleton.textLine(widthFactor: 0.7),
                SizedBox(height: AppSpacing.space2),
                AppSkeleton.textLine(widthFactor: 0.4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _imageAspect = 4 / 3;
}
