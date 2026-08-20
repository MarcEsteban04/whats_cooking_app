import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/search_field.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';

/// The Meals tab, built in the dashboard language of
/// `docs/reference_design/dashboards_ref.webp`.
///
/// The previous version was a browse feed: a title, a search box, rows of pills
/// and a stack of white cards. It worked and it looked like every generated
/// list screen. The reference reads completely differently, and the reason is
/// structural rather than decorative — it leads with a **figure**, explains it
/// with **tiny caps labels and thin bars**, and puts its rows in a **hairline
/// table** instead of separate cards.
///
/// So this screen is now composed of the reference's own blocks:
///
/// * a **header** — the mark, the name, a tappable count line, circular actions;
/// * a **hero panel** — how many meals match, set in display type, with a
///   three-column stat trio underneath whose bars show what share of the
///   catalogue is quick, cheap, or yours. The columns are tappable, so the
///   summary doubles as the filter it describes;
/// * a **segmented control** for the meal category, exactly as the reference
///   switches Daily / Weekly / Monthly;
/// * a **table panel** of meals — hairline-divided rows, the name with its
///   cuisine in caps beneath, and the cost right-aligned as the figure with
///   "a head" as its unit. The reference's country rows, with food in them.
///
/// What is *not* borrowed: the donut, the cohort heatmap and the time series.
/// A meal list has no time axis and no segments to divide, and drawing one
/// anyway would be the reference's shape without its meaning.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({this.autofocusSearch = false, super.key});

  /// Set for `/meals/search`, which exists so Home's search affordance lands
  /// here with the keyboard already up (docs/USER_FLOWS.md §6).
  final bool autofocusSearch;

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  final ScrollController _scroll = ScrollController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _isSearching = widget.autofocusSearch;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Asks for the next page while there is still a screenful left to read.
  ///
  /// A scroll listener rather than fetching when a sentinel widget builds:
  /// starting a request from `build` is a state change during build, which
  /// Riverpod refuses. The controller guards re-entry, so firing on every frame
  /// near the bottom is harmless.
  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.extentAfter < _prefetchExtent) {
      ref.read(mealsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MealFeed> feed = ref.watch(mealsControllerProvider);
    final MealsController controller = ref.read(
      mealsControllerProvider.notifier,
    );

    // `feed.value` rather than `feed.when`: the controls keep rendering the
    // current query while the next page is in flight. Blanking the control you
    // just used is how a fast filter starts to feel slow.
    final MealFeed? current = feed.value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.screenMargin,
                      AppSpacing.space4,
                      AppLayout.screenMargin,
                      0,
                    ),
                    sliver: SliverList.list(
                      children: <Widget>[
                        DashboardHeader(
                          initials: 'wc',
                          title: 'Meals',
                          subtitle: _countLine(current),
                          onSubtitleTap: (current?.query.hasFilters ?? false)
                              ? controller.clearFilters
                              : null,
                          actions: <Widget>[
                            _CircleAction(
                              icon: _isSearching
                                  ? AppIcons.clear
                                  : AppIcons.search,
                              label: _isSearching
                                  ? 'Close search'
                                  : 'Search meals',
                              onPressed: () {
                                setState(() => _isSearching = !_isSearching);
                                if (!_isSearching) {
                                  controller.search('');
                                }
                              },
                            ),
                            _CircleAction(
                              icon: AppIcons.add,
                              label: 'Write a meal of your own',
                              onPressed: () => context.pushNamed(
                                AppRoute.mealCreate.routeName,
                              ),
                            ),
                          ],
                        ),
                        if (_isSearching) ...<Widget>[
                          const SizedBox(height: AppSpacing.space4),
                          SearchField(
                            autofocus: true,
                            hint: 'Search meals',
                            // Debounced at 300 ms inside the field itself.
                            onSearch: controller.search,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.space5),
                        if (current != null) ...<Widget>[
                          _SummaryPanel(
                            feed: current,
                            onChanged: controller.applyQuery,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          _CategoryControl(
                            query: current.query,
                            onChanged: controller.applyQuery,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                        ],
                      ],
                    ),
                  ),
                  ..._feedSlivers(feed, current, controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The header's second line: how many, and what is narrowing it.
  String? _countLine(MealFeed? feed) {
    if (feed == null) {
      return null;
    }
    if (!feed.query.hasFilters) {
      return 'the catalogue and yours';
    }
    return 'filtered — tap to clear';
  }

  List<Widget> _feedSlivers(
    AsyncValue<MealFeed> feed,
    MealFeed? current,
    MealsController controller,
  ) {
    if (current == null) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenMargin,
          ),
          sliver: SliverToBoxAdapter(
            child: feed is AsyncError<MealFeed>
                ? _FeedError(
                    failure: feed.error is AppException
                        ? feed.error as AppException
                        : const UnknownException(),
                    onRetry: controller.refresh,
                  )
                : const _TableSkeleton(),
          ),
        ),
      ];
    }

    if (current.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenMargin,
          ),
          sliver: SliverToBoxAdapter(
            child: _FeedEmpty(
              feed: current,
              onClearFilters: controller.clearFilters,
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.only(
          left: AppLayout.screenMargin,
          right: AppLayout.screenMargin,
          // Clears the floating navigation (docs/COMPONENTS.md §8).
          bottom: AppLayout.scrollBottomPadding,
        ),
        sliver: SliverToBoxAdapter(
          child: Opacity(
            // Dimmed, not replaced. Swapping the table for a skeleton on every
            // filter tap makes an instant interaction feel like a page load.
            opacity: current.isReloading ? _reloadingOpacity : 1,
            child: _MealTable(
              feed: current,
              onSortChanged: (MealSort sort) =>
                  controller.applyQuery(current.query.copyWith(sort: sort)),
              onRetryPage: controller.loadMore,
            ),
          ),
        ),
      ),
    ];
  }

  /// Start fetching about two screens before the end.
  static const double _prefetchExtent = 600;
  static const double _reloadingOpacity = 0.45;
}

/// A circular header action, as the reference draws its settings and member
/// buttons.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outline),
      ),
      child: AppIconButton(
        icon: icon,
        semanticLabel: label,
        iconSize: AppIconSize.sm,
        onPressed: onPressed,
      ),
    );
  }
}

/// The hero panel: the match count, then three shares of the catalogue.
///
/// The stat columns are the reference's `Ducktiket / Seevent / Ticketing` block,
/// and here they do double duty — each one both reports a share and applies the
/// filter it describes. A summary you can act on beats a summary you can only
/// read.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.feed, required this.onChanged});

  final MealFeed feed;
  final ValueChanged<MealQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final MealQuery query = feed.query;

    final int loaded = feed.meals.length;
    final int quick = feed.meals
        .where((Meal meal) => meal.cookingTimeMinutes <= _quickMinutes)
        .length;
    final int cheap = feed.meals
        .where((Meal meal) => meal.costPerServing <= _budgetPerHead)
        .length;
    final int mine = feed.meals.where((Meal meal) => meal.isMine).length;

    double share(int count) => loaded == 0 ? 0 : count / loaded;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BigFigure(
            label: query.hasFilters ? 'Matching now' : 'On the menu',
            value: '$loaded${feed.hasMore ? '+' : ''}',
            unit: loaded == 1 ? 'meal' : 'meals',
          ),
          const SizedBox(height: AppSpacing.space5),
          StatTrio(
            columns: <StatColumnData>[
              StatColumnData(
                label: 'Under $_quickMinutes min',
                value: '$quick',
                fraction: share(quick),
                color: colors.series1,
                onTap: () => onChanged(
                  query.maxCookingTimeMinutes == null
                      ? query.copyWith(maxCookingTimeMinutes: _quickMinutes)
                      : query.copyWith(clearMaxCookingTime: true),
                ),
              ),
              StatColumnData(
                label: 'Under ${AppFormat.peso(_budgetPerHead)}',
                value: '$cheap',
                fraction: share(cheap),
                color: colors.series2,
                onTap: () => onChanged(
                  query.maxCostPerServing == null
                      ? query.copyWith(maxCostPerServing: _budgetPerHead)
                      : query.copyWith(clearMaxCost: true),
                ),
              ),
              StatColumnData(
                label: 'Yours',
                value: '$mine',
                fraction: share(mine),
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space4),
          _CuisineRow(query: query, onChanged: onChanged),
        ],
      ),
    );
  }

  /// The thresholds the seed's own verification guarantees are populated, so a
  /// column can never report a filter that lands on nothing.
  static const int _quickMinutes = 30;
  static const int _budgetPerHead = 100;
}

/// Cuisine as a menu, in the reference's `by Platform:` position.
class _CuisineRow extends StatelessWidget {
  const _CuisineRow({required this.query, required this.onChanged});

  final MealQuery query;
  final ValueChanged<MealQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Row(
      children: <Widget>[
        Text('BY CUISINE', style: context.text.overline),
        const Spacer(),
        PopupMenuButton<Cuisine?>(
          onSelected: (Cuisine? cuisine) => onChanged(
            query.copyWith(
              cuisines: cuisine == null
                  ? const <Cuisine>{}
                  : <Cuisine>{cuisine},
            ),
          ),
          position: PopupMenuPosition.under,
          borderRadius: AppRadius.borderLg,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Cuisine?>>[
            CheckedPopupMenuItem<Cuisine?>(
              checked: query.cuisines.isEmpty,
              child: const Text('Every cuisine'),
            ),
            for (final Cuisine cuisine in offeredCuisines)
              CheckedPopupMenuItem<Cuisine?>(
                value: cuisine,
                checked: query.cuisines.contains(cuisine),
                child: Text(cuisine.label),
              ),
          ],
          child: Semantics(
            button: true,
            label: '${_label(query)}. Tap to change the cuisine',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _label(query),
                  style: context.text.labelSmall.copyWith(
                    color: query.cuisines.isEmpty
                        ? colors.textSecondary
                        : colors.series1,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: AppIconSize.xs,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _label(MealQuery query) => switch (query.cuisines.length) {
    0 => 'Every cuisine',
    1 => query.cuisines.single.label,
    final int count => '$count cuisines',
  };

  /// The cuisines the catalogue actually holds. `Cuisine.values` has twelve and
  /// the seed fills seven; offering Thai as a filter that always returns nothing
  /// teaches people not to trust the filters.
  static const List<Cuisine> offeredCuisines = <Cuisine>[
    Cuisine.filipino,
    Cuisine.japanese,
    Cuisine.korean,
    Cuisine.chinese,
    Cuisine.italian,
    Cuisine.mexican,
    Cuisine.american,
  ];
}

/// The meal category, as the reference's Daily / Weekly / Monthly control.
///
/// Single-valued here, unlike the multi-select pill row it replaces. That is a
/// deliberate narrowing: nobody browses "breakfast and desserts but nothing
/// else", and a segmented control that can show two selections at once is not a
/// segmented control.
class _CategoryControl extends StatelessWidget {
  const _CategoryControl({required this.query, required this.onChanged});

  final MealQuery query;
  final ValueChanged<MealQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<MealCategory?>(
      selected: query.categories.length == 1 ? query.categories.single : null,
      options: <(MealCategory?, String)>[
        (null, 'All'),
        for (final MealCategory category in MealCategory.values)
          (category, category.label),
      ],
      onSelected: (MealCategory? category) => onChanged(
        query.copyWith(
          categories: category == null
              ? const <MealCategory>{}
              : <MealCategory>{category},
        ),
      ),
    );
  }
}

/// The feed, as one hairline-divided table.
///
/// The reference's country table rather than a card each: rows separated by a
/// one-pixel rule inside a single panel. It is denser, it scans down the cost
/// column, and it is the reason the screen no longer reads as a list of
/// identical boxes.
class _MealTable extends StatelessWidget {
  const _MealTable({
    required this.feed,
    required this.onSortChanged,
    required this.onRetryPage,
  });

  final MealFeed feed;
  final ValueChanged<MealSort> onSortChanged;
  final Future<void> Function() onRetryPage;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      title: 'All meals',
      icon: AppIcons.meals,
      trailing: PopupMenuButton<MealSort>(
        onSelected: onSortChanged,
        position: PopupMenuPosition.under,
        borderRadius: AppRadius.borderLg,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<MealSort>>[
          for (final MealSort sort in MealSort.values)
            CheckedPopupMenuItem<MealSort>(
              value: sort,
              checked: sort == feed.query.sort,
              child: Text(sort.label),
            ),
        ],
        child: Semantics(
          button: true,
          label: 'Sorted by ${feed.query.sort.label}. Tap to change',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                feed.query.sort.label,
                style: context.text.labelSmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: AppIconSize.xs,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _TableHead(),
          for (final (int index, Meal meal) in feed.meals.indexed) ...<Widget>[
            DashboardRule(inset: index == 0 ? 0 : _dotColumn),
            DashboardRow(
              leading: _SeriesDot(
                color: context.colors.accentFor(meal.cuisine.label).foreground,
              ),
              title: meal.name,
              subtitle: AppFormat.metadata(<String?>[
                meal.cuisine.label,
                AppFormat.cookingTime(meal.cookingTimeMinutes),
                meal.difficulty.label,
              ]),
              value: AppFormat.peso(meal.costPerServing),
              unit: 'a head',
              trailing: meal.isMine
                  ? const DeltaBadge(label: 'YOURS', isPositive: true)
                  : Icon(
                      AppIcons.forward,
                      size: AppIconSize.xs,
                      color: colors.textTertiary,
                    ),
              onTap: () => context.goNamed(
                AppRoute.mealDetail.routeName,
                pathParameters: <String, String>{'id': meal.id},
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space4),
          _TableFoot(feed: feed, onRetry: onRetryPage),
        ],
      ),
    );
  }

  /// Where the rule starts, so it runs under the text rather than through the
  /// series dot.
  static const double _dotColumn = _SeriesDot.diameter + AppSpacing.space3;
}

/// The table's column headings, in the reference's tiny grey caps.
class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('MEAL', style: context.text.overline)),
          Text('COST', style: context.text.overline),
          const SizedBox(width: AppSpacing.space5),
        ],
      ),
    );
  }
}

/// A small coloured dot standing for the cuisine.
///
/// The reference marks each row of a series with one. It carries the same
/// meaning the old card's rail did — same cuisine, same colour, every time —
/// in a tenth of the space.
class _SeriesDot extends StatelessWidget {
  const _SeriesDot({required this.color});

  final Color color;

  static const double diameter = 8;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: diameter),
    );
  }
}

/// What sits at the foot of the table.
class _TableFoot extends StatelessWidget {
  const _TableFoot({required this.feed, required this.onRetry});

  final MealFeed feed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (feed.loadMoreFailure case final AppException failure) {
      // The pages already loaded stay on screen. Only the page that failed is
      // retried.
      return InlineErrorBanner(
        message: failure.displayMessage ?? failure.message,
        onRetry: onRetry,
      );
    }

    if (feed.isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    return Text(
      feed.hasMore
          ? 'Keep scrolling for more'
          : 'That is all ${feed.meals.length} of them',
      style: context.text.overline,
      textAlign: TextAlign.center,
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
    // filter." Naming which one is the difference between a dead end and one tap
    // out of it.
    if (narrowest != null) {
      return EmptyState(
        title: 'Nothing matches',
        body: 'Try relaxing $narrowest.',
        emoji: '🔍',
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
      );
    }

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

/// The first-load placeholder: the table's own shape, in outline.
class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppSkeleton.textLine(widthFactor: 0.35),
          const SizedBox(height: AppSpacing.space5),
          for (int index = 0; index < _rows; index++) ...<Widget>[
            if (index > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.space3),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space3),
            ],
            const Row(
              children: <Widget>[
                AppSkeleton.circle(diameter: _SeriesDot.diameter),
                SizedBox(width: AppSpacing.space3),
                Expanded(child: AppSkeleton.textLine(widthFactor: 0.7)),
                SizedBox(width: AppSpacing.space3),
                SizedBox(width: 48, child: AppSkeleton.textLine()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const int _rows = 6;
}
