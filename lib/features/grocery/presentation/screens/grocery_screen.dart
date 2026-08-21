import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/circle_action.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';

/// What we need to buy (Sprint 42, docs/USER_FLOWS.md §13).
///
/// The dashboard language, like every other tab. The figure is **progress** rather
/// than a total, because that is the number somebody halfway down an aisle wants:
/// six of ten is a position, and "ten items" is a fact about the past.
///
/// **A ticked line stays exactly where it is** — no re-sorting, no removal, only a
/// fade. design_ui §23 and USER_FLOWS §13 both require it, and the reason is
/// physical: something that vanishes under your thumb makes you lose your place in
/// a shop. Clearing them is a separate, deliberate action, and it says how many it
/// took.
///
/// **Grouped by aisle**, like the pantry, so the list can be walked instead of
/// read. Free-text lines land in "Everything else" because there is nothing to
/// look their aisle up from.
class GroceryScreen extends ConsumerWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroceryItem>> list = ref.watch(
      groceryControllerProvider,
    );
    final GroceryController controller = ref.read(
      groceryControllerProvider.notifier,
    );

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
                          title: 'Shopping',
                          subtitle: _subtitle(list.value),
                          actions: <Widget>[
                            // Always here, whatever state the list is in. Two
                            // circles fit comfortably; the header only ran out of
                            // room at three (see the Meals header).
                            AppCircleAction(
                              icon: AppIcons.invent,
                              label: 'Import a list from a file',
                              onTap: () => context.pushNamed(
                                AppRoute.groceryImport.routeName,
                              ),
                            ),
                            AppCircleAction(
                              icon: AppIcons.add,
                              label: 'Add something to buy',
                              onTap: () => context.pushNamed(
                                AppRoute.groceryAdd.routeName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space5),
                        switch (list) {
                          AsyncError<List<GroceryItem>>(:final Object error) =>
                            ErrorState(
                              kind: error is AppException
                                  ? error.errorStateKind
                                  : ErrorStateKind.unknown,
                              body: error is AppException
                                  ? error.displayMessage
                                  : null,
                              onRetry: controller.refresh,
                            ),
                          AsyncValue<List<GroceryItem>>(
                            :final List<GroceryItem> value,
                          ) =>
                            value.isEmpty
                                ? const _Empty()
                                : _Loaded(items: value),
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

  static String _subtitle(List<GroceryItem>? items) {
    if (items == null) {
      return 'what we need';
    }
    if (items.isEmpty) {
      return 'nothing to buy';
    }
    final int left = items.where((GroceryItem item) => !item.isCompleted).length;
    return left == 0
        ? 'all done'
        : '$left still to get';
  }
}

/// The list, with something on it.
class _Loaded extends ConsumerWidget {
  const _Loaded({required this.items});

  final List<GroceryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;

    final int done = items.where((GroceryItem item) => item.isCompleted).length;
    final int left = items.length - done;

    final Map<IngredientCategory, List<GroceryItem>> byAisle =
        <IngredientCategory, List<GroceryItem>>{};
    for (final GroceryItem item in items) {
      byAisle.putIfAbsent(item.category, () => <GroceryItem>[]).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                // Progress, not a total. Six of ten is a position in a shop; "ten
                // items" is a fact about a decision already made.
                label: left == 0 ? 'Everything got' : 'Still to get',
                value: left == 0 ? '${items.length}' : '$left',
                unit: left == 1 ? 'thing' : 'things',
              ),
              const SizedBox(height: AppSpacing.space4),
              _Progress(done: done, total: items.length),
              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space4),
              DashboardActionRow(
                actions: <DashboardAction>[
                  DashboardAction(
                    label: 'Add',
                    icon: AppIcons.add,
                    onTap: () =>
                        context.pushNamed(AppRoute.groceryAdd.routeName),
                  ),
                  // Importing one (Sprint 53). Beside Add, because it is the same
                  // job done differently — a list somebody already wrote, in a
                  // photo or a PDF, instead of twenty lines typed at a shelf.
                  DashboardAction(
                    label: 'Import',
                    icon: AppIcons.invent,
                    onTap: () =>
                        context.pushNamed(AppRoute.groceryImport.routeName),
                  ),
                  DashboardAction(
                    label: 'Kitchen',
                    icon: AppIcons.pantry,
                    onTap: () => context.goNamed(AppRoute.pantry.routeName),
                  ),
                  DashboardAction(
                    label: 'Clear done',
                    icon: AppIcons.check,
                    // Disabled rather than hidden when there is nothing ticked.
                    // A control that appears and disappears as you shop is a
                    // control you cannot learn the position of.
                    onTap: done == 0
                        ? null
                        : () => _clearCompleted(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),

        for (final IngredientCategory group in IngredientCategory.values)
          if (byAisle[group] case final List<GroceryItem> rows) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            DashboardPanel(
              title: group.label,
              icon: _aisleIcon(group),
              trailing: Text(
                // How many of this aisle are left, not how many there are. In an
                // aisle the useful number is what is still on the shelf list.
                '${rows.where((GroceryItem i) => !i.isCompleted).length}'
                '/${rows.length}',
                style: context.text.metadata.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (int index, GroceryItem item) in rows.indexed)
                    ...<Widget>[
                      if (index > 0) const DashboardRule(),
                      _GroceryRow(item: item, key: ValueKey<String>(item.id)),
                    ],
                ],
              ),
            ),
          ],
      ],
    );
  }

  Future<void> _clearCompleted(BuildContext context, WidgetRef ref) async {
    final (int gone, AppException? failure) = await ref
        .read(groceryControllerProvider.notifier)
        .clearCompleted();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? failure.displayMessage ?? failure.message
              : 'Cleared $gone ${gone == 1 ? 'item' : 'items'}.',
        ),
      ),
    );
  }
}

/// The thin bar the reference puts under a figure, carrying how far along we are.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final double fraction = total == 0 ? 0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$done of $total in the basket',
                style: context.text.overline,
              ),
            ),
            Text(AppFormat.percent(fraction), style: context.text.metadata),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        MiniBar(
          fraction: fraction,
          // Ink rather than the accent. The accent belongs to SPIN, and a
          // shopping list filling up is satisfying without being the loudest
          // thing in the app (docs/DESIGN_SYSTEM.md §2.2).
          color: colors.series2,
        ),
      ],
    );
  }
}

/// One line on the list.
///
/// The checkbox is the whole row: in a shop this is tapped one-handed, often
/// without looking properly, and a 24-pixel target beside a 300-pixel row is a
/// design that assumes a desk.
class _GroceryRow extends ConsumerWidget {
  const _GroceryRow({required this.item, super.key});

  final GroceryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;
    final bool done = item.isCompleted;

    return Dismissible(
      key: ValueKey<String>('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.error.color,
          borderRadius: AppRadius.borderMd,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space4),
            child: Icon(
              AppIcons.delete,
              color: colors.error.onColor,
              size: AppIconSize.sm,
            ),
          ),
        ),
      ),
      onDismissed: (_) async {
        final AppException? failure = await ref
            .read(groceryControllerProvider.notifier)
            .remove(item);

        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure == null
                  ? '${AppFormat.sentenceCase(item.name)} is off the list.'
                  : failure.displayMessage ?? failure.message,
            ),
          ),
        );
      },
      child: PressFeedback(
        onTap: () => _toggle(ref),
        semanticLabel: '${item.name}, ${done ? 'got' : 'still to get'}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          // **Fades in place, and does not move.** The opacity is the only thing
          // that changes — see the screen's own doc for why nothing re-sorts.
          child: AnimatedOpacity(
            duration: AppMotion.resolve(context, AppMotion.normal),
            opacity: done ? _doneOpacity : 1,
            child: Row(
              children: <Widget>[
                _Tick(isDone: done),
                const SizedBox(width: AppSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppFormat.sentenceCase(item.name),
                        style: context.text.bodyLarge.copyWith(
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: colors.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Why this line is here, when a meal put it here
                      // (Sprint 43). "Bay leaves — for Chicken Adobo" is a line
                      // somebody trusts; "bay leaves" on its own is a line they
                      // delete in three days because they cannot remember adding
                      // it.
                      if (item.fromMealName case final String meal)
                        Text(
                          'for $meal',
                          style: context.text.metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (item.hasAmount) ...<Widget>[
                  const SizedBox(width: AppSpacing.space3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _amountWidth),
                    child: Text(
                      item.amount,
                      style: context.text.metadata,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref) async {
    // Before the request, not after. The tick is optimistic and so is the feel of
    // it — a haptic that waits for a supermarket's connection arrives after the
    // thumb has moved on.
    AppHaptics.reelTick();

    await ref
        .read(groceryControllerProvider.notifier)
        .setCompleted(item, isCompleted: !item.isCompleted);
  }

  /// Faded, not hidden. Legible enough to check you did not miss anything, faint
  /// enough that the eye skips it.
  static const double _doneOpacity = 0.45;
  static const double _amountWidth = 84;
}

/// The checkbox.
class _Tick extends StatelessWidget {
  const _Tick({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.curveFast,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: isDone ? colors.series2 : Colors.transparent,
        borderRadius: AppRadius.borderXs,
        border: Border.all(
          color: isDone ? colors.series2 : colors.outline,
          width: _stroke,
        ),
      ),
      child: isDone
          ? Icon(AppIcons.check, size: AppIconSize.xs, color: colors.surface)
          : null,
    );
  }

  static const double _size = 24;
  static const double _stroke = 1.5;
}

/// Nothing to buy.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState(
        icon: AppIcons.grocery,
        title: 'Nothing to buy',
        // Says both ways in: by hand now, and by itself from Sprint 43. The
        // shared `EmptyState.grocery` only mentions spinning, and this screen can
        // be filled in directly.
        body: 'Add what you need, or accept a meal and we will work out what is '
            'missing.',
        actionLabel: 'Add something',
        onAction: () => context.pushNamed(AppRoute.groceryAdd.routeName),
        // **The import belongs here most of all.** It was only in the panel's
        // action row, and that row does not exist on an empty list — so the one
        // feature that fills an empty list was hidden precisely when the list was
        // empty.
        secondaryActionLabel: 'Import a photo, txt or PDF',
        onSecondaryAction: () =>
            context.pushNamed(AppRoute.groceryImport.routeName),
      ),
    );
  }
}

/// The shape the list will be, while it loads.
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
              AppSkeleton(height: _barHeight),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        for (int index = 0; index < _rows; index++) ...<Widget>[
          const AppSkeleton.textLine(widthFactor: 0.6),
          const SizedBox(height: AppSpacing.space4),
        ],
      ],
    );
  }

  static const double _figureHeight = 40;
  static const double _barHeight = 28;
  static const int _rows = 6;
}

/// The glyph for each aisle.
///
/// The same mapping the pantry uses. Duplicated rather than shared for now,
/// because a two-entry `core/widgets` file for one switch is a worse trade than
/// two switches — but if a third screen needs it, it moves.
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
