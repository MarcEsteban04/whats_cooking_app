import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/circle_action.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// What is in the kitchen (Sprint 39–40, docs/USER_FLOWS.md §12).
///
/// The dashboard language, like Home and Meals: one figure set huge, tiny caps
/// labels, hairline rules instead of nested boxes.
///
/// **Grouped by aisle, not alphabetically.** `protein, vegetables, dairy` is a
/// list you can walk; A-to-Z sends the eye between the fridge and the spice rack
/// four times. That ordering is the whole reason `ingredients.category` is read
/// here at all, and it is why each aisle carries a glyph — at a glance, the shape
/// of the list says what kind of kitchen this is.
///
/// **Both filters come out of the panel.** The aisle figures are tappable and the
/// "needs using" callout is a toggle, so the numbers a reader would want to act on
/// *are* the controls. That is what the reference means by stat columns doubling
/// as filters, and it is why this screen has no filter bar.
///
/// **Tap a row to change the amount, swipe to remove.** Removing is the
/// destructive one and gets the gesture that cannot be triggered by a mis-tap
/// while scrolling a list at the fridge door.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final TextEditingController _search = TextEditingController();

  bool _isSearching = false;

  /// Narrowed to what wants eating soon.
  bool _onlyUrgent = false;

  /// Narrowed to one aisle, or null for all of them.
  IngredientCategory? _aisle;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PantryItem>> pantry = ref.watch(
      pantryControllerProvider,
    );
    final PantryController controller = ref.read(
      pantryControllerProvider.notifier,
    );

    // One clock for the whole build. Reading `DateTime.now()` per row would let a
    // list rendered across midnight disagree with itself about what day it is.
    final DateTime now = DateTime.now();
    final List<PantryItem> all = pantry.value ?? const <PantryItem>[];

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
                          title: 'Kitchen',
                          subtitle: _subtitle(all, now),
                          onSubtitleTap: _hasFilter ? _clearFilters : null,
                          actions: <Widget>[
                            AppCircleAction(
                              icon: _isSearching
                                  ? AppIcons.clear
                                  : AppIcons.search,
                              label: _isSearching
                                  ? 'Close search'
                                  : 'Search the kitchen',
                              onTap: _toggleSearch,
                            ),
                            // Reading the fridge (Sprint 49). A circle here
                            // rather than a fifth tile in the action row below:
                            // that row already carries four labels, and this is
                            // the header you are looking at while standing in
                            // front of the thing being photographed.
                            AppCircleAction(
                              icon: AppIcons.camera,
                              label: 'Read the fridge from a photo',
                              onTap: () => context.pushNamed(
                                AppRoute.pantryScan.routeName,
                              ),
                            ),
                            AppCircleAction(
                              icon: AppIcons.add,
                              label: 'Add an ingredient',
                              onTap: () => context.pushNamed(
                                AppRoute.pantryAdd.routeName,
                              ),
                            ),
                          ],
                        ),

                        if (_isSearching) ...<Widget>[
                          const SizedBox(height: AppSpacing.space4),
                          AppTextField(
                            controller: _search,
                            hint: 'Search the kitchen',
                            autofocus: true,
                            prefixIcon: AppIcons.search,
                            textCapitalization: TextCapitalization.none,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.space5),

                        switch (pantry) {
                          AsyncError<List<PantryItem>>(:final Object error) =>
                            ErrorState(
                              kind: error is AppException
                                  ? error.errorStateKind
                                  : ErrorStateKind.unknown,
                              body: error is AppException
                                  ? error.displayMessage
                                  : null,
                              onRetry: controller.refresh,
                            ),
                          AsyncValue<List<PantryItem>>(
                            :final List<PantryItem> value,
                          ) =>
                            value.isEmpty
                                ? const _Empty()
                                : _Loaded(
                                    all: value,
                                    visible: _visible(value, now),
                                    now: now,
                                    onlyUrgent: _onlyUrgent,
                                    aisle: _aisle,
                                    hasQuery: _query.isNotEmpty,
                                    onToggleUrgent: () => setState(
                                      () => _onlyUrgent = !_onlyUrgent,
                                    ),
                                    onAisle: (IngredientCategory picked) =>
                                        setState(
                                          () => _aisle = _aisle == picked
                                              ? null
                                              : picked,
                                        ),
                                    onClearFilters: _clearFilters,
                                  ),
                          _ => const _Loading(),
                        },

                        const SizedBox(
                          height: AppLayout.scrollBottomPadding,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _query => _search.text.trim().toLowerCase();

  bool get _hasFilter => _onlyUrgent || _aisle != null || _query.isNotEmpty;

  /// Everything that survives the search and the two filters.
  ///
  /// Applied here rather than in the query. The whole pantry arrives in one
  /// request and is a few dozen rows at the outside, so filtering in Dart buys the
  /// same thing the spin's filters buy: exact counts for every filter at once,
  /// out of one fetch.
  List<PantryItem> _visible(List<PantryItem> items, DateTime now) {
    final String query = _query;

    return <PantryItem>[
      for (final PantryItem item in items)
        if (query.isEmpty || item.name.contains(query))
          if (_aisle == null || item.category == _aisle)
            if (!_onlyUrgent || item.statusAsOf(now).needsAttention) item,
    ];
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _search.clear();
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _onlyUrgent = false;
      _aisle = null;
      _search.clear();
      _isSearching = false;
    });
  }

  /// The context line under the title.
  ///
  /// Says what is being *looked at* while something is filtering, and what is in
  /// the kitchen otherwise — the same rule the Meals header follows, so a narrowed
  /// list never reads as a shrunken one.
  String _subtitle(List<PantryItem> items, DateTime now) {
    if (_hasFilter) {
      return '${_visible(items, now).length} of ${items.length} · tap to clear';
    }
    if (items.isEmpty) {
      return 'nothing in yet';
    }
    final int aisles = items
        .map((PantryItem item) => item.category)
        .toSet()
        .length;
    return '${items.length} ${items.length == 1 ? 'thing' : 'things'} '
        'across $aisles ${aisles == 1 ? 'aisle' : 'aisles'}';
  }
}

/// The pantry, with something in it.
class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.all,
    required this.visible,
    required this.now,
    required this.onlyUrgent,
    required this.aisle,
    required this.hasQuery,
    required this.onToggleUrgent,
    required this.onAisle,
    required this.onClearFilters,
  });

  /// Everything in the kitchen.
  ///
  /// The panel's figures count this rather than [visible]: a filter narrows the
  /// list, and a headline that shrank with it would make filtering look like
  /// losing stock.
  final List<PantryItem> all;

  /// What survives the search and the filters.
  final List<PantryItem> visible;

  final DateTime now;
  final bool onlyUrgent;
  final IngredientCategory? aisle;
  final bool hasQuery;
  final VoidCallback onToggleUrgent;
  final ValueChanged<IngredientCategory> onAisle;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;

    final int urgent = all
        .where((PantryItem item) => item.statusAsOf(now).needsAttention)
        .length;

    // The aisles that actually have something in them, biggest first. This is the
    // reference's `Top Performing Countries` block: three real figures with real
    // bars, rather than a fixed trio whose third column reads "0" most of the
    // time — which is what "Staples 0" was doing.
    final Map<IngredientCategory, int> counts = <IngredientCategory, int>{};
    for (final PantryItem item in all) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    final List<IngredientCategory> top = counts.keys.toList()
      ..sort((IngredientCategory a, IngredientCategory b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        // Ties broken by aisle order rather than by map order, so the panel does
        // not reshuffle itself between two refreshes that changed nothing.
        return byCount != 0 ? byCount : a.index.compareTo(b.index);
      });

    // Grouped in one pass. The list arrives already sorted by category then name,
    // so this only has to notice where one group ends.
    final Map<IngredientCategory, List<PantryItem>> byAisle =
        <IngredientCategory, List<PantryItem>>{};
    for (final PantryItem item in visible) {
      byAisle.putIfAbsent(item.category, () => <PantryItem>[]).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'In the kitchen',
                value: '${all.length}',
                unit: all.length == 1 ? 'thing' : 'things',
              ),

              // The one thing on this screen worth acting on tonight, and a
              // control rather than a read-out. Absent entirely at zero: a
              // permanent row reading "0 to use up" is a warning somebody learns
              // to stop seeing.
              if (urgent > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                _UrgentCallout(
                  count: urgent,
                  isActive: onlyUrgent,
                  onTap: onToggleUrgent,
                ),
              ],

              const SizedBox(height: AppSpacing.space5),

              // **The breakdown only earns its place with something to break
              // down.** With one aisle it printed "Everything else / 1" directly
              // above a section heading reading "Everything else / 1" — the same
              // fact twice, in the panel's most prominent row. So below two
              // aisles the space goes to the thing a nearly-empty pantry actually
              // needs, which is a reason to fill it in.
              if (top.length >= 2)
                StatTrio(
                  columns: <StatColumnData>[
                    for (final (int index, IngredientCategory group)
                        in top.take(3).indexed)
                      StatColumnData(
                        label: group.label,
                        value: '${counts[group]}',
                        fraction: counts[group]! / all.length,
                        color: switch (index) {
                          0 => colors.series1,
                          1 => colors.series2,
                          _ => colors.primary,
                        },
                        // Tapping a figure filters to it; tapping again clears.
                        onTap: () => onAisle(group),
                      ),
                  ],
                )
              else
                const _GettingStarted(),

              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space4),
              DashboardActionRow(
                actions: <DashboardAction>[
                  DashboardAction(
                    label: 'Add',
                    icon: AppIcons.add,
                    onTap: () =>
                        context.pushNamed(AppRoute.pantryAdd.routeName),
                  ),
                  // The strongest entry point this feature has (Sprint 48). It
                  // belongs on the pantry rather than only on Meals, because
                  // "what do I do with these three things" is a question you ask
                  // while looking at the three things.
                  DashboardAction(
                    label: 'Invent',
                    icon: AppIcons.invent,
                    onTap: () =>
                        context.pushNamed(AppRoute.inventMeal.routeName),
                  ),
                  DashboardAction(
                    label: 'Cook',
                    icon: AppIcons.spin,
                    onTap: () => context.goNamed(AppRoute.home.routeName),
                  ),
                  DashboardAction(
                    label: 'Buy',
                    icon: AppIcons.grocery,
                    onTap: () => context.goNamed(AppRoute.grocery.routeName),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (visible.isEmpty)
          _NothingMatched(
            onlyUrgent: onlyUrgent,
            hasQuery: hasQuery,
            onClear: onClearFilters,
          )
        else
          // **One card per aisle.** The first version put bare rows straight onto
          // the page background under a caps heading, and they read as loose text
          // rather than as a list — nothing in this app sits on the background
          // except the header. A panel per aisle gives the group edges, puts its
          // name and count in a panel header the way every other panel in the app
          // does, and turns the aisle into an object you can point at.
          for (final IngredientCategory group in IngredientCategory.values)
            if (byAisle[group] case final List<PantryItem> rows) ...<Widget>[
              const SizedBox(height: AppSpacing.space4),
              DashboardPanel(
                title: group.label,
                icon: _aisleIcon(group),
                trailing: _AisleCount(
                  count: rows.length,
                  isActive: aisle == group,
                  onTap: () => onAisle(group),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final (int index, PantryItem item) in rows.indexed)
                      ...<Widget>[
                        // A hairline between rows, not a box around each. Inside
                        // one card the reference divides with a single pixel.
                        if (index > 0) const DashboardRule(),
                        _PantryRow(
                          item: item,
                          now: now,
                          key: ValueKey<String>(item.id),
                        ),
                      ],
                  ],
                ),
              ),
            ],
      ],
    );
  }
}

/// "3 things need using" — a warning that is also a filter.
class _UrgentCallout extends StatelessWidget {
  const _UrgentCallout({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColor warning = context.colors.warning;
    final Color ink = isActive ? warning.onColor : warning.onSurface;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: '$count things need using',
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The tinted container until it is switched on, not the full-strength
          // colour: this is a nudge sitting inside a white panel, and a solid
          // amber block would outshout the figure above it.
          color: isActive ? warning.color : warning.surface,
          borderRadius: AppRadius.borderMd,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: <Widget>[
              Icon(AppIcons.expiring, size: AppIconSize.xs, color: ink),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 thing needs using'
                      : '$count things need using',
                  style: context.text.labelSmall.copyWith(color: ink),
                ),
              ),
              Text(
                // Says what the tap does. A coloured row that filters is not
                // obviously a control, and a control nobody presses is decoration.
                isActive ? 'Show all' : 'Show these',
                style: context.text.metadata.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many are in one aisle, and the tap that filters to it.
///
/// Sits in the panel header's `trailing` slot, which is where every other panel
/// in the app puts its one control. A count that is also the filter means an
/// aisle needs no separate chip and no extra row.
class _AisleCount extends StatelessWidget {
  const _AisleCount({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: isActive ? 'Show every aisle' : 'Show only this aisle',
      expandTouchTarget: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? colors.surfaceInverse : colors.surfaceMuted,
          borderRadius: AppRadius.borderFull,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: AppSpacing.space1,
          ),
          child: Text(
            '$count',
            style: context.text.labelSmall.copyWith(
              color: isActive ? colors.textOnInverse : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// What a nearly-empty pantry gets instead of a breakdown.
///
/// Dead space on a screen with one thing on it is worse than a prompt, and this
/// is the one prompt worth making: a pantry is not a list for its own sake, it is
/// the input to "what can we cook right now". Nobody fills in a fridge inventory
/// for fun, and until the app has said what it is *for*, an empty one looks like
/// homework.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Row(
          children: <Widget>[
            Icon(
              AppIcons.spin,
              size: AppIconSize.sm,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                'Add a few more things and the roulette can start offering '
                'meals you already have the ingredients for.',
                style: context.text.metadata,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One thing in the kitchen.
/// One thing in the kitchen.
///
/// A row rather than a card, per the dashboard language: hairline division, the
/// name leading, the amount right-aligned as the figure.
class _PantryRow extends ConsumerWidget {
  const _PantryRow({required this.item, required this.now, super.key});

  final PantryItem item;

  /// Passed in rather than read here, so every row in one build agrees about what
  /// day it is.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ExpiryStatus status = item.statusAsOf(now);
    final String? warning = item.expiryLabel(now);

    return Dismissible(
      key: ValueKey<String>('dismiss-${item.id}'),
      // One direction only. A list you can flick either way is a list where a
      // horizontal scroll gesture deletes your dinner plans.
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.error.color,
          borderRadius: AppRadius.borderMd,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space4),
            child: Icon(
              AppIcons.delete,
              color: context.colors.error.onColor,
              size: AppIconSize.sm,
            ),
          ),
        ),
      ),
      onDismissed: (_) async {
        final AppException? failure = await ref
            .read(pantryControllerProvider.notifier)
            .remove(item);

        if (!context.mounted) {
          return;
        }

        // The row has already gone or already come back — the controller rolled
        // its own state. All that is left is to say which happened.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure == null
                  ? '${AppFormat.sentenceCase(item.name)} is out of the kitchen.'
                  : failure.displayMessage ?? failure.message,
            ),
          ),
        );
      },
      child: PressFeedback(
        onTap: () =>
            context.pushNamed(AppRoute.pantryAdd.routeName, extra: item),
        semanticLabel: item.name,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Row(
            children: <Widget>[
              // **The tile does two jobs and that is the point.** It carries the
              // aisle's glyph, which gives the eye something to run down the left
              // edge of a long list — and it changes colour when the item wants
              // eating, so urgency needs no badge, no second row and no extra
              // colour anywhere else. An 8-pixel pip was doing the second job on
              // its own and doing it invisibly.
              _RowTile(aisle: item.category, status: status),
              const SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // Stored lower case, shown with a capital. The vocabulary
                      // is normalised for matching; a reader should not have to
                      // look at the consequences of that.
                      AppFormat.sentenceCase(item.name),
                      style: context.text.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (warning case final String line)
                      Text(
                        line,
                        style: context.text.metadata.copyWith(
                          // Past its date is an error; nearly is a warning. The
                          // two want different colours because they want
                          // different actions — throw it out, or cook it.
                          color: status == ExpiryStatus.gone
                              ? context.colors.error.color
                              : context.colors.warning.color,
                        ),
                        maxLines: 1,
                      )
                    else if (item.isStaple)
                      Text(
                        'Always assumed in',
                        style: context.text.metadata,
                        maxLines: 1,
                      )
                    else if (item.expiresOn case final DateTime date)
                      Text(
                        'Good until ${AppFormat.calendarDate(date, now: now)}',
                        style: context.text.metadata,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              _AmountFigure(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row's leading tile: the aisle it belongs to, tinted by how urgent it is.
///
/// The same 30-pixel rounded square `DashboardActionRow` uses, because it is the
/// app's existing vocabulary for "a small thing with a glyph in it" — a row that
/// invented its own shape would read as a different kind of list.
///
/// Ink for the ordinary case, and **the semantic colour when the item wants
/// eating**. That is deliberate reuse of one element for two facts: the aisle is
/// what the glyph says, the urgency is what its background says, and neither needs
/// a badge.
class _RowTile extends StatelessWidget {
  const _RowTile({required this.aisle, required this.status});

  final IngredientCategory aisle;
  final ExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final Color fill = switch (status) {
      ExpiryStatus.gone => colors.error.color,
      ExpiryStatus.today || ExpiryStatus.soon => colors.warning.color,
      // Ink, matching the action tiles. Most rows are fine, and a list of
      // confident green squares would spend the reader's whole attention saying
      // nothing.
      ExpiryStatus.fine || ExpiryStatus.none => colors.series2,
    };

    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: AppRadius.borderSm),
      child: SizedBox.square(
        dimension: _size,
        child: Center(
          child: Icon(
            _aisleIcon(aisle),
            size: AppIconSize.xs,
            color: colors.surface,
          ),
        ),
      ),
    );
  }

  static const double _size = 34;
}

/// How much there is, set as a figure with its unit beneath.
///
/// The reference's third move, applied to a list row: *"a unit word, small and
/// separate"*, so `500 g` reads as one phrase in two weights rather than as a
/// single run of text. It is also what stops a long unit — "half bottle" — from
/// crowding the name, because the unit wraps under the number instead of
/// competing with it on one line.
class _AmountFigure extends StatelessWidget {
  const _AmountFigure({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    // No tracked amount. "Some" rather than a blank, because an empty right
    // column reads as a row that failed to load — and it is the truth: the schema
    // treats a null quantity as "we have some".
    if (item.quantity == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Text(
          item.unit.isEmpty ? 'Some' : AppFormat.sentenceCase(item.unit),
          style: context.text.metadata,
          textAlign: TextAlign.right,
          maxLines: 2,
        ),
      );
    }

    final double value = item.quantity!;
    final String figure = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(figure, style: context.text.titleMedium),
          if (item.unit.isNotEmpty)
            Text(
              item.unit,
              style: context.text.metadata,
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
        ],
      ),
    );
  }

  /// Enough for "half bottle" on two lines, and never enough to squeeze the name.
  static const double _maxWidth = 88;
}

/// Filtered down to nothing.
/// Filtered down to nothing.
class _NothingMatched extends StatelessWidget {
  const _NothingMatched({
    required this.onlyUrgent,
    required this.hasQuery,
    required this.onClear,
  });

  final bool onlyUrgent;
  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState(
        icon: AppIcons.search,
        // Three filters, three sentences, because they have three different fixes
        // and a generic "no results" leaves the reader to work out which one they
        // are looking at.
        title: switch ((onlyUrgent, hasQuery)) {
          (true, _) => 'Nothing needs using',
          (_, true) => 'Not in the kitchen',
          _ => 'Nothing in this aisle',
        },
        body: switch ((onlyUrgent, hasQuery)) {
          (true, _) => 'Everything with a date on it is still fine.',
          (_, true) => 'Add it, and the roulette can start counting on it.',
          _ => 'Nothing filed here yet.',
        },
        actionLabel: 'Show everything',
        onAction: onClear,
      ),
    );
  }
}

/// Nothing in yet.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    // The shared constructor rather than a bespoke one. docs/COMPONENTS.md keeps
    // these in `EmptyState` precisely so the same absence reads the same way
    // wherever it turns up, and there is already a pantry variant.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState.pantry(
        onAddIngredient: () => context.pushNamed(AppRoute.pantryAdd.routeName),
      ),
    );
  }
}

/// The shape the pantry will be, while it loads.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppSkeleton.textLine(widthFactor: 0.35),
              SizedBox(height: AppSpacing.space3),
              AppSkeleton(height: _figureHeight),
              SizedBox(height: AppSpacing.space5),
              AppSkeleton(height: _trioHeight),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        for (int index = 0; index < _rows; index++) ...<Widget>[
          const AppSkeleton.textLine(widthFactor: 0.55),
          const SizedBox(height: AppSpacing.space4),
        ],
      ],
    );
  }

  static const double _figureHeight = 40;
  static const double _trioHeight = 54;
  static const int _rows = 6;
}

/// The glyph for each aisle.
///
/// Here rather than on the enum because `core/domain` imports nothing but Dart,
/// and outline glyphs because this app has no coloured icons anywhere.
IconData _aisleIcon(IngredientCategory aisle) => switch (aisle) {
  IngredientCategory.protein => Icons.set_meal_outlined,
  IngredientCategory.vegetable => Icons.grass_outlined,
  IngredientCategory.fruit => Icons.local_florist_outlined,
  IngredientCategory.grain => Icons.rice_bowl_outlined,
  IngredientCategory.dairy => Icons.local_drink_outlined,
  IngredientCategory.spice => Icons.scatter_plot_outlined,
  IngredientCategory.condiment => Icons.water_drop_outlined,
  IngredientCategory.other => Icons.inventory_2_outlined,
};
