import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// What is in the kitchen (Sprint 39, docs/USER_FLOWS.md §12).
///
/// The dashboard language, like Home and Meals: one figure set huge, tiny caps
/// labels, hairline rules instead of nested boxes.
///
/// **Grouped by aisle, not alphabetically.** `protein, vegetables, dairy` is a
/// list you can walk; A-to-Z sends the eye between the fridge and the spice rack
/// four times. That ordering is the whole reason `ingredients.category` is read
/// here at all.
///
/// **Tap an item to change the amount, swipe to remove.** Removing is the
/// destructive one and gets the gesture that cannot be triggered by a mis-tap
/// while scrolling a list at the fridge door.
class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PantryItem>> pantry = ref.watch(
      pantryControllerProvider,
    );
    final PantryController controller = ref.read(
      pantryControllerProvider.notifier,
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
                          title: 'Kitchen',
                          subtitle: _countLine(pantry.value),
                        ),
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
                                : _Loaded(items: value),
                          // Loading with nothing cached yet.
                          _ => const _Loading(),
                        },
                        // Clears the floating bottom navigation. Without it the
                        // last aisle sits under the bar and reads as a list that
                        // has stopped early.
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

  /// The context line under the title.
  static String _countLine(List<PantryItem>? items) {
    if (items == null) {
      return 'what we have in';
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
  const _Loaded({required this.items});

  final List<PantryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Grouped in one pass. The list arrives already sorted by category then name
    // (both the repository and the controller sort it), so this only has to
    // notice where one group ends.
    final Map<IngredientCategory, List<PantryItem>> byAisle =
        <IngredientCategory, List<PantryItem>>{};
    for (final PantryItem item in items) {
      byAisle.putIfAbsent(item.category, () => <PantryItem>[]).add(item);
    }

    final int withAmounts = items.where((PantryItem i) => i.hasAmount).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'In the kitchen',
                value: '${items.length}',
                unit: items.length == 1 ? 'thing' : 'things',
              ),
              const SizedBox(height: AppSpacing.space5),
              StatTrio(
                columns: <StatColumnData>[
                  StatColumnData(
                    label: 'Aisles',
                    value: '${byAisle.length}',
                    fraction:
                        byAisle.length / IngredientCategory.values.length,
                    color: context.colors.series1,
                  ),
                  StatColumnData(
                    // The number the pantry does *not* need in order to be
                    // useful — Sprint 41 asks "do we have any", not "how much".
                    // Shown because it is the honest measure of how much detail
                    // has been bothered with, not because it is a target.
                    label: 'With amounts',
                    value: '$withAmounts',
                    fraction: items.isEmpty ? 0 : withAmounts / items.length,
                    color: context.colors.series2,
                  ),
                  StatColumnData(
                    label: 'Staples',
                    value: '${items.where((PantryItem i) => i.isStaple).length}',
                    fraction: items.isEmpty
                        ? 0
                        : items.where((PantryItem i) => i.isStaple).length /
                              items.length,
                    color: context.colors.primary,
                  ),
                ],
              ),
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
        for (final IngredientCategory aisle in IngredientCategory.values)
          if (byAisle[aisle] case final List<PantryItem> group)
            ...<Widget>[
              SectionHeader(title: aisle.label),
              for (final PantryItem item in group)
                _PantryRow(item: item, key: ValueKey<String>(item.id)),
            ],
      ],
    );
  }
}

/// One thing in the kitchen.
///
/// A row rather than a card, per the dashboard language: hairline division, the
/// name leading, the amount right-aligned as the figure.
class _PantryRow extends ConsumerWidget {
  const _PantryRow({required this.item, super.key});

  final PantryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: context.colors.surface,
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
                  ? '${_sentenceCase(item.name)} is out of the kitchen.'
                  : failure.displayMessage ?? failure.message,
            ),
          ),
        );
      },
      child: PressFeedback(
        onTap: () => _edit(context, ref),
        semanticLabel: item.name,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // Stored lower case, shown with a capital. The vocabulary
                      // is normalised for matching; a reader should not have to
                      // look at the consequences of that.
                      _sentenceCase(item.name),
                      style: context.text.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.isStaple)
                      Text(
                        'Always assumed in',
                        style: context.text.metadata,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Text(
                // "Some" rather than a blank, because an empty right column reads
                // as a row that failed to load. It is also the truth: the schema
                // treats a null quantity as "we have some".
                item.hasAmount ? item.amount : 'Some',
                style: item.hasAmount
                    ? context.text.bodyLarge
                    : context.text.metadata,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The amount sheet, reusing the add sheet with this item pre-filled.
  void _edit(BuildContext context, WidgetRef ref) {
    context.pushNamed(AppRoute.pantryAdd.routeName, extra: item);
  }

  static String _sentenceCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
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
        onAddIngredient: () =>
            context.pushNamed(AppRoute.pantryAdd.routeName),
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
        const SizedBox(height: AppSpacing.space5),
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
