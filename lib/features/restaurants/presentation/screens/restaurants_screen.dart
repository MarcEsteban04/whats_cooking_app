import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/circle_action.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
import 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';

/// Where we eat out (Sprint 45).
///
/// **A list we wrote, with no discovery layer.** No maps, no ratings, no location
/// search — the places two people actually go, which is better than every
/// restaurant in the city and needs no third-party dependency to keep working.
///
/// The dashboard language like every other screen, with one departure: the figure
/// is the number of places, and the trio is **how far** rather than a category
/// breakdown. Proximity is the thing that decides most weeknights — "can we walk"
/// is the question, and it is also the filter.
///
/// Reached from Home rather than being a tab. Eating out is the *other* answer to
/// the same question, so it belongs beside the roulette, not in the navigation bar
/// as a fifth destination.
/// The route at `/eat-out`, for deep links and for the spin screen's siblings.
///
/// **The primary way in is the Meals tab**, which embeds [RestaurantLibraryView]
/// under a Cook / Eat out segment — eating out is the same decision as cooking, so
/// it belongs in the same tab rather than in a shortcut on Home. This screen
/// exists because `/eat-out/new`, `/eat-out/:id/edit` and `/eat-out/spin` are all
/// children of this path, and a parent that resolves is tidier than a path that
/// only ever 404s.
class RestaurantsScreen extends StatelessWidget {
  const RestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Eat out'),
      ),
      body: const SafeArea(top: false, child: RestaurantLibraryView()),
    );
  }
}

/// The restaurant library, without a Scaffold of its own.
///
/// Extracted so the Meals tab and the `/eat-out` route render the *same* screen
/// rather than two that drift. [aboveContent] is the slot the Meals tab puts its
/// Cook / Eat out segment into, so the switch sits with the content it switches
/// rather than floating above it in a bar of its own.
class RestaurantLibraryView extends ConsumerStatefulWidget {
  const RestaurantLibraryView({this.aboveContent, super.key});

  /// Rendered between the header and the panel. Null on the standalone route.
  final Widget? aboveContent;

  @override
  ConsumerState<RestaurantLibraryView> createState() =>
      _RestaurantLibraryViewState();
}

class _RestaurantLibraryViewState
    extends ConsumerState<RestaurantLibraryView> {
  /// Narrowed to one distance, or null for all of them.
  Proximity? _proximity;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Restaurant>> places = ref.watch(
      restaurantsControllerProvider,
    );
    final RestaurantsController controller = ref.read(
      restaurantsControllerProvider.notifier,
    );

    final List<Restaurant> all = places.value ?? const <Restaurant>[];
    final List<Restaurant> visible = _proximity == null
        ? all
        : all
              .where((Restaurant place) => place.proximity == _proximity)
              .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.contentMaxWidth,
        ),
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppLayout.screenMargin,
              AppSpacing.space4,
              AppLayout.screenMargin,
              AppLayout.scrollBottomPadding,
            ),
            children: <Widget>[
              // The dashboard header, matching every other tab — this view is
              // embedded in one now, so an AppBar here would be a second title
              // bar under the first.
              DashboardHeader(
                title: 'Eat out',
                subtitle: _subtitle(all),
                actions: <Widget>[
                  AppCircleAction(
                    icon: AppIcons.add,
                    label: 'Add a place',
                    onTap: () => context.pushNamed(
                      AppRoute.restaurantCreate.routeName,
                    ),
                  ),
                ],
              ),
              if (widget.aboveContent case final Widget above) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                above,
              ],
              const SizedBox(height: AppSpacing.space5),
                  switch (places) {
                    AsyncError<List<Restaurant>>(:final Object error) =>
                      ErrorState(
                        kind: error is AppException
                            ? error.errorStateKind
                            : ErrorStateKind.unknown,
                        body: error is AppException
                            ? error.displayMessage
                            : null,
                        onRetry: controller.refresh,
                      ),
                    AsyncValue<List<Restaurant>>(
                      :final List<Restaurant> value,
                    ) =>
                      value.isEmpty
                          ? const _Empty()
                          : _Loaded(
                              all: value,
                              visible: visible,
                              proximity: _proximity,
                              onProximity: (Proximity picked) => setState(
                                () => _proximity = _proximity == picked
                                    ? null
                                    : picked,
                              ),
                            ),
                _ => const _Loading(),
              },
            ],
          ),
        ),
      ),
    );
  }

  /// The context line under the title.
  String _subtitle(List<Restaurant> all) {
    if (all.isEmpty) {
      return 'nowhere yet';
    }
    if (_proximity case final Proximity limit) {
      return 'within ${limit.phrase}';
    }
    return '${all.length} ${all.length == 1 ? 'place' : 'places'} we go';
  }
}

/// The list, with something on it.
class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.all,
    required this.visible,
    required this.proximity,
    required this.onProximity,
  });

  final List<Restaurant> all;
  final List<Restaurant> visible;
  final Proximity? proximity;
  final ValueChanged<Proximity> onProximity;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final Map<Proximity, int> byDistance = <Proximity, int>{};
    for (final Restaurant place in all) {
      byDistance[place.proximity] = (byDistance[place.proximity] ?? 0) + 1;
    }

    // The median cost a head, not the mean. One expensive place we go twice a year
    // drags an average somewhere nobody recognises, and this figure exists to
    // answer "what does eating out cost us" honestly.
    final List<double> costs = <double>[
      for (final Restaurant place in all) place.costPerHead,
    ]..sort();
    final double median = costs.isEmpty
        ? 0
        : costs[costs.length ~/ 2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BigFigure(
                label: 'Places we go',
                value: '${all.length}',
                unit: all.length == 1 ? 'place' : 'places',
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'Usually about ${AppFormat.peso(median.round())} a head',
                style: context.text.metadata,
              ),
              const SizedBox(height: AppSpacing.space5),
              // How far, because that is the thing that decides most weeknights —
              // and the figures are the filter, as everywhere else in this app.
              StatTrio(
                columns: <StatColumnData>[
                  for (final (int index, Proximity option)
                      in Proximity.values.indexed)
                    StatColumnData(
                      label: option.label,
                      value: '${byDistance[option] ?? 0}',
                      fraction: all.isEmpty
                          ? 0
                          : (byDistance[option] ?? 0) / all.length,
                      color: switch (index) {
                        0 => colors.series1,
                        1 => colors.series2,
                        _ => colors.primary,
                      },
                      onTap: () => onProximity(option),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space5),

              // The point of the list (Sprint 46). Loud, in the accent, exactly
              // as Home's is — this screen is a decision surface too, and a list
              // you can only read is a list nobody keeps up to date.
              //
              // Two places, not one: spinning between a single option is a
              // ceremony with a foregone conclusion, and the button would teach
              // somebody the feature is pointless on the one occasion it is.
              if (all.length >= 2)
                AppButton.brand(
                  label: 'PICK ONE',
                  size: AppButtonSize.large,
                  onPressed: () =>
                      context.goNamed(AppRoute.restaurantSpin.routeName),
                )
              else
                // **Says what is missing rather than showing nothing** (Sprint
                // 49b). The `>= 2` rule is right and the silence around it was
                // not: with one place saved, the roulette left no trace on this
                // screen at all, so the only way to learn it exists was to add a
                // second place and notice a new button. A locked line teaches the
                // feature and names the one thing that unlocks it.
                const _PickOneLocked(),

              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space4),
              DashboardActionRow(
                actions: <DashboardAction>[
                  DashboardAction(
                    label: 'Add',
                    icon: AppIcons.add,
                    onTap: () => context.pushNamed(
                      AppRoute.restaurantCreate.routeName,
                    ),
                  ),
                  // Where we have been (Sprint 55). Three tiles rather than two,
                  // and this is the one that was missing: the app has recorded
                  // every night out since Sprint 46 and used them to push down
                  // places visited recently, with no screen anywhere that said
                  // so. A feature nobody can reach is a feature nobody has.
                  DashboardAction(
                    label: 'Been to',
                    icon: AppIcons.plannerActive,
                    onTap: () => context.pushNamed(
                      AppRoute.restaurantHistory.routeName,
                    ),
                  ),
                  DashboardAction(
                    label: 'Cook instead',
                    icon: AppIcons.spin,
                    onTap: () => context.goNamed(AppRoute.home.routeName),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space7),
            child: EmptyState(
              icon: AppIcons.search,
              title: 'Nothing that close',
              body: proximity == null
                  ? 'Nothing here yet.'
                  : 'No places within ${proximity!.phrase}.',
              actionLabel: 'Show all',
              onAction: () => onProximity(proximity ?? Proximity.walk),
            ),
          )
        else ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          DashboardPanel(
            title: proximity == null ? 'Everywhere' : proximity!.label,
            icon: AppIcons.meals,
            trailing: Text(
              '${visible.length}',
              style: context.text.metadata.copyWith(
                color: colors.textSecondary,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (int index, Restaurant place) in visible.indexed)
                  ...<Widget>[
                    if (index > 0) const DashboardRule(),
                    _RestaurantRow(
                      place: place,
                      key: ValueKey<String>(place.id),
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

/// One place.
///
/// The name, what it costs and how far on one line each; the order we get there on
/// a third when there is one. That last line is the reason this list exists — no
/// maps API returns it, and it is the thing that turns "somewhere Japanese" into a
/// decision.
class _RestaurantRow extends ConsumerWidget {
  const _RestaurantRow({required this.place, super.key});

  final Restaurant place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: () => context.pushNamed(
        AppRoute.restaurantEdit.routeName,
        pathParameters: <String, String>{'id': place.id},
      ),
      onLongPress: () => _confirmRemove(context, ref),
      semanticLabel: place.name,
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
                    place.name,
                    style: context.text.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    place.summary,
                    style: context.text.metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.goToOrder case final String order)
                    Text(
                      '"$order"',
                      style: context.text.metadata.copyWith(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            // A star rather than a heart. The heart is the meals vocabulary and
            // this is a different library; using the same glyph for both would
            // imply one list of favourites where there are two.
            PressFeedback(
              onTap: () => ref
                  .read(restaurantsControllerProvider.notifier)
                  .toggleFavorite(place),
              semanticLabel: place.isFavorite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              expandTouchTarget: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: Icon(
                  place.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: AppIconSize.sm,
                  color: place.isFavorite
                      ? colors.primary
                      : colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Long-press to delete, behind a confirmation.
  ///
  /// Not a swipe, unlike the pantry and the grocery list. Those hold things that
  /// come and go weekly; a restaurant is a record somebody typed with notes and an
  /// order, and losing it to a stray horizontal flick would be a real loss with no
  /// undo. Long-press is the gesture that cannot happen by accident.
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove ${place.name}?',
      body: 'The notes and what we order there go with it.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final AppException? failure = await ref
        .read(restaurantsControllerProvider.notifier)
        .remove(place);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? '${place.name} is off the list.'
              : failure.displayMessage ?? failure.message,
        ),
      ),
    );
  }
}

/// Nothing on the list yet.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space7),
      child: EmptyState(
        icon: AppIcons.meals,
        title: 'No places yet',
        // Says what the list is for, because a restaurant list with no discovery
        // layer is not obviously worth typing into until you know it gets spun.
        body: 'Add the places you actually go. On the nights nobody is cooking, '
            'the app can pick one.',
        actionLabel: 'Add a place',
        onAction: () => context.pushNamed(AppRoute.restaurantCreate.routeName),
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
              AppSkeleton(height: _trioHeight),
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
  static const double _trioHeight = 54;
  static const int _rows = 5;
}

/// The roulette, before there is enough to spin (Sprint 49b).
///
/// Deliberately quiet rather than a disabled accent button. A dead SPIN in
/// terracotta would be the loudest thing on the screen and the only thing on it
/// that does nothing — the accent is reserved for the action that works
/// (docs/DESIGN_SYSTEM.md §2.2). This is a sentence and a tap that leads to the
/// thing that fixes it.
/// Only ever seen with exactly one place saved. An empty library gets [_Empty],
/// which already says what the list is for, so there is no zero case to word.
class _PickOneLocked extends StatelessWidget {
  const _PickOneLocked();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: () => context.pushNamed(AppRoute.restaurantCreate.routeName),
      semanticLabel: 'Add a place so we can pick one for you',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: AppRadius.borderLg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            children: <Widget>[
              Icon(AppIcons.spin, size: AppIconSize.sm, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('We can pick for you', style: context.text.titleSmall),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      'One more place and the roulette can choose between '
                      'them.',
                      style: context.text.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Icon(
                AppIcons.forward,
                size: AppIconSize.xs,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
