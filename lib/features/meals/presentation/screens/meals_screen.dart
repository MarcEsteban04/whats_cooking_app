import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_select.dart';
import 'package:whats_cooking/core/widgets/inputs/search_field.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/my_meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/selectable_meal_row.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/restaurants/presentation/screens/restaurants_screen.dart';

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
/// * a **header** — the mark, the name, a tappable count line, and search;
/// * a **hero panel** — how many meals match, set in display type, with a
///   three-column stat trio underneath whose bars show what share of the
///   catalogue is quick, cheap, or yours. The columns are tappable, so the
///   summary doubles as the filter it describes;
/// * an **action row** across the foot of that panel — Saved, Hidden, Yours,
///   New meal. The reference's own `Billing & Transactions | …` block, and the
///   right home for everything that is not the feed: they are destinations, and
///   a labelled tile says where it goes in a way a bare circle in the header did
///   not;
/// * a **segmented control** for the meal category, exactly as the reference
///   switches Daily / Weekly / Monthly;
/// * a **table panel** of meals — hairline-divided rows, the name with its
///   cuisine in caps beneath, and the cost right-aligned as the figure with
///   "a head" as its unit. The reference's country rows, with food in them.
///
/// What is *not* borrowed: the donut, the cohort heatmap and the time series.
/// A meal list has no time axis and no segments to divide, and drawing one
/// anyway would be the reference's shape without its meaning.
/// Which library the Meals tab is showing (Sprint 47b).
enum MealsLibrary {
  cook('Cook'),
  eatOut('Eat out');

  const MealsLibrary(this.label);

  final String label;
}

/// The Meals tab: **one tab, two libraries** (Sprint 47b).
///
/// Eating out used to be a shortcut on Home. It is a segment here instead,
/// because it is not a different *place* — it is the other answer to the same
/// question, and the food we know about is the food we know about whether we cook
/// it or go to it. A tab called Meals that excludes half of what a household eats
/// was a filing decision pretending to be a product one.
///
/// The segment sits **inside** the scroll view rather than in a fixed bar, so it
/// travels with the content it switches. A control pinned above a scrolling header
/// reads as chrome; one under the header reads as part of the screen.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({this.autofocusSearch = false, super.key});

  /// Set for `/meals/search`, which exists so Home's search affordance lands
  /// here with the keyboard already up (docs/USER_FLOWS.md §6).
  final bool autofocusSearch;

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  MealsLibrary _library = MealsLibrary.cook;

  /// The ids picked out for a bulk action, or empty when not selecting.
  ///
  /// **On the whole feed, catalogue rows included** (Sprint 53f). It started on
  /// "Yours" only, because `delete own meals` was author-scoped and the sixty
  /// seeded rows carry no author — so offering it here would have been offering
  /// an action the server refuses. Migration 0028 widened the policy, on the
  /// grounds that a catalogue you can only add to fills up with food this
  /// household does not eat and the sixty are a starting point rather than a
  /// canon.
  ///
  /// One refusal survives and is not a bug: `meal_history.meal_id` is
  /// `on delete restrict`, so a meal that has been eaten cannot be deleted by
  /// anybody. [_deleteSelected] counts those separately and says so.
  final Set<String> _selected = <String>{};

  bool _isDeleting = false;

  /// The header controls when nothing is selected.
  List<Widget> _browseActions(MealsController controller) => <Widget>[
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
          // The one exception to "everything else lives in the
          // panel's action row": the assistant.
          //
          // It belongs here because this is the screen where
          // somebody runs out of ideas — scrolling a catalogue
          // and not finding it is exactly when asking in words
          // beats another filter. And it gives Ask a second way
          // in: Home is the only other one, which for a feature
          // this new is one route too few.
          _CircleAction(
            icon: AppIcons.assistant,
            label: 'Ask about dinner',
            onPressed: () => context.pushNamed(
              AppRoute.assistant.routeName,
            ),
          ),
          // **Two circles, not three.** Sprint 48 put an
          // "Invent a meal" circle here on the argument that
          // the row had room. It did not: the logo, three
          // 40-pixel circles and their gaps leave about 124dp
          // for the title and the context line on a normal
          // phone, and "the catalogue and yours" needs more —
          // so the subtitle ran under the buttons. Fixing the
          // constraint in `DashboardHeader` stops the overlap
          // and turns it into a truncation, which is correct
          // and still not worth reading.
          //
          // Inventing a meal keeps its labelled tile on the
          // Kitchen action row, which was always the stronger
          // entry point anyway — "what do I do with these three
          // things" is a question you ask in front of the three
          // things.
  ];

  /// The header controls while selecting.
  ///
  /// Replacing the browse controls rather than joining them: search and Ask
  /// are not what somebody is doing mid-selection, and four circles is the
  /// width that broke this header once already.
  List<Widget> _selectionActions() => <Widget>[
    // Coloured, because these two are the whole point of the selection mode and
    // a row of identical grey circles gives no clue which one is destructive.
    // The tones match the swipe panels on the kitchen and shopping lists, so
    // "blue means change it, red means it goes" holds across the app.
    if (_selected.length == 1)
      _CircleAction(
        icon: AppIcons.edit,
        label: 'Edit this meal',
        tint: context.colors.info.color,
        onPressed: _isDeleting ? null : _editSelected,
      ),
    _CircleAction(
      icon: AppIcons.delete,
      label: _selected.length == 1
          ? 'Delete this meal'
          : 'Delete ${_selected.length} meals',
      tint: context.colors.error.color,
      onPressed: _isDeleting ? null : _deleteSelected,
    ),
    _CircleAction(
      icon: AppIcons.clear,
      label: 'Stop selecting',
      onPressed: _isDeleting ? null : () => setState(_selected.clear),
    ),
  ];

  /// Picks a meal out, or puts it back.
  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) {
      _selected.add(id);
    }
  });

  /// A swipe right on one row.
  void _editOne(String id) => context.pushNamed(
    AppRoute.mealEdit.routeName,
    pathParameters: <String, String>{'id': id},
  );

  /// A swipe left on one row.
  ///
  /// **Routed through the batch path deliberately.** A single delete gets the same
  /// confirmation and the same "you have eaten that one, so it stays" reporting
  /// as five — one code path, one set of sentences, and no second place for the
  /// `meal_history` refusal to be handled differently.
  Future<void> _deleteOne(String id) async {
    setState(() {
      _selected
        ..clear()
        ..add(id);
    });
    await _deleteSelected();
  }

  /// Opens the one selected meal in the form.
  void _editSelected() {
    final String id = _selected.first;
    setState(_selected.clear);
    context.pushNamed(
      AppRoute.mealEdit.routeName,
      pathParameters: <String, String>{'id': id},
    );
  }

  /// Deletes everything picked out.
  ///
  /// **Three outcomes, not two.** A meal that has been eaten is refused by
  /// `meal_history`'s `on delete restrict`, which is correct and permanent —
  /// history is a record of what happened, and a recipe going should not rewrite
  /// the nights it was cooked. Counting those as "failures" alongside a real
  /// error would make a working constraint look like a broken app, so they are
  /// counted apart and named.
  Future<void> _deleteSelected() async {
    final int count = _selected.length;

    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: count == 1 ? 'Delete this meal?' : 'Delete $count meals?',
      body: 'The recipe goes. Anything you have already eaten stays in your '
          'history — and those meals cannot be deleted at all.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep them',
      isDestructive: true,
      icon: AppIcons.delete,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);

    int gone = 0;
    int eaten = 0;
    AppException? failure;

    for (final String id in _selected.toList()) {
      try {
        await ref.read(mealRepositoryProvider).delete(id);
        gone += 1;
      } on Object catch (error, stackTrace) {
        final AppException mapped = ErrorMapper.map(error, stackTrace);
        // `23503` foreign key, which here can only be `meal_history`.
        if (mapped is ValidationException) {
          eaten += 1;
        } else {
          failure ??= mapped;
        }
      }
    }

    ref.invalidate(myMealsProvider);
    await ref.read(mealsControllerProvider.notifier).refresh();

    if (!mounted) {
      return;
    }

    setState(() {
      _selected.clear();
      _isDeleting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch ((gone, eaten, failure)) {
            (0, 0, final AppException e) => e.displayMessage ?? e.message,
            (0, final int n, _) when n > 0 =>
              n == 1
                  ? 'You have eaten that one, so it stays.'
                  : 'You have eaten those $n, so they stay.',
            (0, _, _) => 'Nothing was deleted.',
            (final int n, 0, null) =>
              n == 1 ? 'The meal is gone.' : '$n meals are gone.',
            (final int n, final int kept, _) when kept > 0 =>
              '$n gone — $kept you have eaten stay.',
            (final int n, _, _) => '$n gone — the rest could not be.',
          },
        ),
      ),
    );
  }

  /// The switch, handed to whichever library is showing so it can place it under
  /// its own header.
  Widget get _switcher => AppSegmentedControl<MealsLibrary>(
    selected: _library,
    options: <(MealsLibrary, String)>[
      for (final MealsLibrary option in MealsLibrary.values)
        (option, option.label),
    ],
    onSelected: (MealsLibrary picked) =>
        setState(() => _library = picked),
  );

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

    if (_library == MealsLibrary.eatOut) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: RestaurantLibraryView(aboveContent: _switcher),
        ),
      );
    }

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
                          // The count takes over the title while selecting,
                          // rather than sitting beside it — two headlines
                          // competing is how a selection mode ends up looking
                          // like a different screen.
                          title: _selected.isEmpty
                              ? 'Meals'
                              : '${_selected.length} selected',
                          subtitle: _selected.isEmpty
                              ? _countLine(current)
                              : 'Long-press a row to pick more',
                          onSubtitleTap:
                              _selected.isEmpty &&
                                  (current?.query.hasFilters ?? false)
                              ? controller.clearFilters
                              : null,
                          actions: _selected.isEmpty
                              ? _browseActions(controller)
                              : _selectionActions(),
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        _switcher,

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
                        if (current?.cachedAt
                            case final DateTime storedAt) ...<Widget>[
                          // Said out loud, because the alternative is the app
                          // presenting yesterday's catalogue as today's. Not
                          // an error — there is a usable list below it — so it
                          // reads as a note with a retry rather than a
                          // failure.
                          _OfflineNotice(
                            storedAt: storedAt,
                            onRetry: controller.refresh,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                        ],
                        if (current?.refreshFailure
                            case final AppException f) ...<Widget>[
                          // The list below is still a true answer to a query
                          // that did load, so it stays and this says what
                          // failed (Sprint 27). Above the summary, because the
                          // figures in it are the ones that did not update.
                          InlineErrorBanner(
                            message: f.displayMessage ?? f.message,
                            onRetry: controller.refresh,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                        ],
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
                          const SizedBox(height: AppSpacing.space3),
                          _CookableToggle(query: current.query),
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
              selected: _selected,
              isBusy: _isDeleting,
              onToggle: _toggle,
              onEdit: _editOne,
              onDelete: _deleteOne,
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

/// "You are offline — this is the catalogue we had" (Sprint 27).
///
/// A note rather than an error, and the distinction is the point: there is a
/// working list underneath it. `ErrorState` would replace that list with an
/// apology, and `InlineErrorBanner` would paint it in the error colour, which
/// says something went wrong when what actually happened is the app coping.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.storedAt, required this.onRetry});

  final DateTime storedAt;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: colors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.wifi_off_rounded,
                size: AppIconSize.sm,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  'No connection. Showing the meals saved '
                  '${AppFormat.relativeTime(storedAt)}.',
                  style: context.text.bodySmall,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              AppButton.tertiary(
                label: 'Retry',
                size: AppButtonSize.small,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular header action, as the reference draws its settings and member
/// buttons.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint,
  });

  final IconData icon;
  final String label;

  /// Colours the glyph and its ring.
  ///
  /// Null for the browse controls, which are meant to be quiet. Set for the
  /// selection controls, where a row of identical grey circles gives no clue
  /// which one is destructive.
  final Color? tint;

  /// Null disables it — which the selection controls need while a delete is in
  /// flight, so a second tap cannot start the batch twice.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        // The ring picks up the tint at low alpha rather than at full strength: a
        // solid red circle on a white header is a warning, and these are controls
        // somebody is meant to use.
        border: Border.all(
          color: tint?.withValues(alpha: _tintedRing) ?? colors.outline,
        ),
      ),
      child: AppIconButton(
        icon: icon,
        semanticLabel: label,
        iconSize: AppIconSize.sm,
        color: tint,
        onPressed: onPressed,
      ),
    );
  }

  /// Enough to read as coloured without becoming a badge.
  static const double _tintedRing = 0.45;
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
          // **Ours leads once there are any** (Sprint 37).
          //
          // The catalogue count was the figure here, and it was the wrong one to
          // set huge: sixty is a number somebody else chose, it never moves, and a
          // panel whose headline is constant stops being read. The size of our own
          // library is the number that grows, the number worth growing, and the one
          // the roulette's quality actually tracks.
          //
          // Not while it is zero, though. A display-sized `0` on the first run is
          // an accusation, and the catalogue count is a genuinely useful thing to
          // lead with until there is something of ours to count. Filters take
          // precedence over both — mid-search, what matches is the only figure
          // anybody wants.
          if (query.hasFilters)
            BigFigure(
              label: 'Matching now',
              value: '$loaded${feed.hasMore ? '+' : ''}',
              unit: loaded == 1 ? 'meal' : 'meals',
            )
          else if (mine > 0)
            BigFigure(
              label: 'Your own meals',
              value: '$mine',
              unit: mine == 1 ? 'meal' : 'meals',
            )
          else
            BigFigure(
              label: 'On the menu',
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
              // Swaps with the headline: whichever of the two is *not* set huge
              // above appears here, so neither number is ever missing and neither
              // is ever printed twice.
              if (!query.hasFilters && mine > 0)
                StatColumnData(
                  label: 'On the menu',
                  value: '$loaded${feed.hasMore ? '+' : ''}',
                  fraction: 1,
                  color: colors.primary,
                )
              else
                StatColumnData(
                  label: 'Yours',
                  value: '$mine',
                  fraction: share(mine),
                  color: colors.primary,
                  onTap: () =>
                      context.pushNamed(AppRoute.myMeals.routeName),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space4),
          _CuisineRow(query: query, onChanged: onChanged),
          const SizedBox(height: AppSpacing.space4),
          const DashboardRule(),
          // The reference's `Billing & Transactions | Top Performing Countries |
          // Target Sales Breakdown` — three labelled ways out of the panel. This
          // is where the three lists that are not the feed belong: they are
          // destinations, and a labelled tile says where it goes in a way a bare
          // circle in the header never did.
          DashboardActionRow(
            actions: <DashboardAction>[
              DashboardAction(
                label: 'Saved',
                icon: AppIcons.favoriteActive,
                onTap: () => context.pushNamed(AppRoute.favorites.routeName),
              ),
              DashboardAction(
                label: 'Hidden',
                icon: AppIcons.dislike,
                onTap: () =>
                    context.pushNamed(AppRoute.dislikedMeals.routeName),
              ),
              DashboardAction(
                label: 'Yours',
                icon: AppIcons.meals,
                onTap: () => context.pushNamed(AppRoute.myMeals.routeName),
              ),
              DashboardAction(
                label: 'New meal',
                icon: AppIcons.add,
                onTap: () => context.pushNamed(AppRoute.mealCreate.routeName),
              ),
            ],
          ),
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
        // A sheet rather than a `PopupMenuButton` (Sprint 49b). The stock menu
        // opened as a floating white panel with its own type scale, covering the
        // very list it was filtering — see [AppSelect].
        AppSelect<Cuisine>(
          title: 'Cuisine',
          value: query.cuisines.length == 1 ? query.cuisines.first : null,
          labelOverride: _label(query),
          // The accent when a filter is on, so the control says so without a
          // badge. Null keeps the quiet default.
          labelColor: query.cuisines.isEmpty ? null : colors.series1,
          options: <AppSelectOption<Cuisine>>[
            const AppSelectOption<Cuisine>(value: null, label: 'Every cuisine'),
            for (final Cuisine cuisine in offeredCuisines)
              AppSelectOption<Cuisine>(value: cuisine, label: cuisine.label),
          ],
          onSelected: (Cuisine? cuisine) => onChanged(
            query.copyWith(
              cuisines: cuisine == null
                  ? const <Cuisine>{}
                  : <Cuisine>{cuisine},
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
/// "Can cook now" — the feed narrowed to what the kitchen already covers
/// (Sprint 41).
///
/// **Absent until the pantry has something in it.** A filter that can only ever
/// return nothing is a filter that teaches somebody the feature is broken, and on
/// a fresh install that is exactly what this would be. Once there is a pantry it
/// appears, and it says how many qualify before it is pressed — which is the
/// difference between a filter and a gamble.
///
/// The ids come from `pantry_match()` and are handed to the *query*, so the feed
/// stays paged and server-filtered. Sifting a page in Dart would leave the server
/// counting twenty rows where the reader sees nineteen.
class _CookableToggle extends ConsumerWidget {
  const _CookableToggle({required this.query});

  final MealQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, PantryMatch> matches =
        ref.watch(pantryMatchesProvider).value ?? const <String, PantryMatch>{};

    final Set<String> cookable = <String>{
      for (final MapEntry<String, PantryMatch> entry in matches.entries)
        if (entry.value.isComplete) entry.key,
    };

    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AppFilterChip(
        label: query.isCookableOnly
            ? 'Everything'
            : 'Can cook now',
        icon: AppIcons.pantry,
        count: query.isCookableOnly ? null : cookable.length,
        isSelected: query.isCookableOnly,
        onSelected: (_) => ref
            .read(mealsControllerProvider.notifier)
            .setCookableOnly(query.isCookableOnly ? null : cookable),
      ),
    );
  }
}

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
    required this.selected,
    required this.isBusy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MealFeed feed;
  final ValueChanged<MealSort> onSortChanged;
  final Future<void> Function() onRetryPage;

  /// The ids picked out for a bulk action, or empty when not selecting.
  final Set<String> selected;
  final bool isBusy;
  final ValueChanged<String> onToggle;

  /// Swipe right, swipe left. Both go through the screen so a single-row action
  /// gets the same confirmation and the same "you have eaten that one" reporting
  /// as a batch — one code path, one set of messages.
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {

    return DashboardPanel(
      title: 'All meals',
      icon: AppIcons.meals,
      trailing: AppSelect<MealSort>(
        title: 'Sort by',
        value: feed.query.sort,
        options: <AppSelectOption<MealSort>>[
          for (final MealSort sort in MealSort.values)
            AppSelectOption<MealSort>(value: sort, label: sort.label),
        ],
        // Never null: every option carries a value, so the sheet cannot return
        // one. Falling back to the current sort rather than to a default, because
        // a dismissed sheet must not quietly reorder the list.
        onSelected: (MealSort? sort) => onSortChanged(sort ?? feed.query.sort),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _TableHead(),
          for (final (int index, Meal meal) in feed.meals.indexed) ...<Widget>[
            DashboardRule(inset: index == 0 ? 0 : MealTableRow.ruleInset),
            SelectableMealRow(
              key: ValueKey<String>(meal.id),
              meal: meal,
              isSelected: selected.contains(meal.id),
              isSelecting: selected.isNotEmpty,
              isBusy: isBusy,
              onToggle: () => onToggle(meal.id),
              onEdit: () => onEdit(meal.id),
              onDelete: () => onDelete(meal.id),
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
    final int hidden = feed.hiddenCount;

    // docs/USER_FLOWS.md §7: "An empty result set offers to relax the narrowest
    // filter." Naming which one is the difference between a dead end and one tap
    // out of it.
    if (narrowest != null) {
      return EmptyState(
        title: 'Nothing matches',
        body: <String>[
          'Try relaxing $narrowest.',
          // Said out loud, because the exclusion is silent everywhere else and
          // a search that cannot find a meal you know exists is otherwise a bug
          // as far as the reader can tell.
          if (hidden > 0) _hiddenNote(hidden),
        ].join(' '),
        icon: AppIcons.search,
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
      );
    }

    if (hidden > 0) {
      // Nothing narrowing the feed and nothing in it: the hiding is the whole
      // explanation, so the way out is the hidden list rather than the filters.
      return EmptyState(
        title: 'Nothing left to show',
        body: hidden == 1
            ? 'The one meal here is hidden.'
            : 'All $hidden meals here are hidden.',
        icon: AppIcons.dislike,
        actionLabel: 'Hidden meals',
        onAction: () => context.pushNamed(AppRoute.dislikedMeals.routeName),
      );
    }

    return const EmptyState(
      title: 'No meals yet',
      body: 'The catalogue is empty. Nothing to browse just yet.',
      icon: AppIcons.meals,
    );
  }

  static String _hiddenNote(int hidden) {
    final String count = hidden == 1 ? 'one is' : '$hidden are';
    return 'Hidden meals stay out whatever you search — $count hidden.';
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
                AppSkeleton.circle(diameter: 8),
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
