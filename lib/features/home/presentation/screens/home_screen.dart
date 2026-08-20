import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/roulette/domain/entities/spin_filters.dart';
import 'package:whats_cooking/features/roulette/presentation/providers/spin_filters_controller.dart';

/// The decision surface (docs/design_ui.md §11, docs/COMPONENTS.md §7).
///
/// The most important screen in the app, and the one with the least on it. Its
/// whole job is to make one button obvious.
///
/// Built in the dashboard language of `reference_design/dashboards_ref.webp`
/// like the rest of the tabs, with one deliberate departure: the hero panel
/// leads with a **question** rather than a figure. Every other panel in the app
/// opens with a number because there is a number worth leading with — meals
/// matching, meals saved, meals hidden. Home's number would have to be invented,
/// and "60 meals available" is not what anybody standing in their kitchen at
/// seven o'clock wants to read. The question is the figure here.
///
/// **The three stat columns show what the next spin will actually apply**, taken
/// from the spin filters rather than from the profile. That is what makes
/// docs/USER_FLOWS.md §6 true — "current budget and party size are always
/// visible on Home, so the user never wonders what the app is about to assume" —
/// and it stays true after the sheet has overridden something for one evening,
/// which reading the profile here would not.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(
      profileControllerProvider,
    );
    final SpinFilters filters = ref.watch(spinFiltersProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenMargin,
                AppSpacing.space4,
                AppLayout.screenMargin,
                AppLayout.scrollBottomPadding,
              ),
              children: <Widget>[
                DashboardHeader(
                  initials: 'wc',
                  title: 'Tonight',
                  subtitle: _kitchenLine(profile.value),
                  onSubtitleTap: () =>
                      context.goNamed(AppRoute.profile.routeName),
                  actions: const <Widget>[],
                ),
                const SizedBox(height: AppSpacing.space5),
                _SpinPanel(
                  filters: filters,
                  servings:
                      profile.value?.preferences.preferredServings ??
                      AppConstants.defaultPartySize,
                ),
                const SizedBox(height: AppSpacing.space4),
                const _Elsewhere(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whose kitchen this is — the reference's `37 Members ⌄` line.
  String? _kitchenLine(UserProfile? profile) {
    if (profile == null) {
      return null;
    }
    if (profile.householdName case final String household) {
      return household;
    }
    return '${profile.displayName}, cooking';
  }
}

/// The centrepiece: the question, the constraints, and the button.
class _SpinPanel extends StatelessWidget {
  const _SpinPanel({required this.filters, required this.servings});

  /// What the next spin will narrow by.
  final SpinFilters filters;

  /// How many the household is cooking for.
  ///
  /// A preference rather than a filter: it changes the cost a head the reader is
  /// comparing against, not which meals are eligible.
  final int servings;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What are we eating tonight?',
            style: context.text.displayMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text('Let us decide for you.', style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.space5),
          StatTrio(
            columns: <StatColumnData>[
              StatColumnData(
                label: 'Budget',
                value: filters.maxCostPerServing == null
                    ? 'Any'
                    : AppFormat.peso(filters.maxCostPerServing!),
                unit: 'a head',
                color: colors.series1,
                onTap: () => _openFilters(context),
              ),
              StatColumnData(
                label: 'Cooking for',
                value: '$servings',
                unit: servings == 1 ? 'person' : 'people',
                color: colors.series2,
                onTap: () => _openFilters(context),
              ),
              StatColumnData(
                label: 'No longer than',
                value: filters.maxCookingTimeMinutes == null
                    ? 'Any'
                    : '${filters.maxCookingTimeMinutes}',
                unit: filters.maxCookingTimeMinutes == null ? 'time' : 'min',
                color: colors.primary,
                onTap: () => _openFilters(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space5),
          // The strongest call to action in the app, and the only thing wearing
          // the palette's one accent (docs/DESIGN_SYSTEM.md §2.2).
          AppButton.brand(
            label: 'SPIN',
            size: AppButtonSize.large,
            onPressed: () => context.goNamed(AppRoute.roulette.routeName),
          ),
          const SizedBox(height: AppSpacing.space3),
          // Says what *else* is narrowing the spin. The three columns above
          // cannot show a cuisine or a meal type, and a reader who set one
          // yesterday should not have to open the sheet to find out it is still
          // on — that is the surprise §6 exists to prevent.
          Center(
            child: AppButton.tertiary(
              label: _filterLabel,
              size: AppButtonSize.small,
              leadingIcon: AppIcons.filter,
              onPressed: () => _openFilters(context),
            ),
          ),
        ],
      ),
    );
  }

  String get _filterLabel {
    final int chosen = filters.chosenCount;
    if (chosen == 0) {
      return 'Narrow it down';
    }
    return '$chosen ${chosen == 1 ? 'filter' : 'filters'} on';
  }

  /// The sheet that owns these numbers for one spin (docs/COMPONENTS.md §7:
  /// "budget and party-size pills are tappable and open the filter sheet
  /// directly — the fastest possible path to adjusting a constraint").
  ///
  /// The sheet rather than the profile, now that there is one. Somebody tapping
  /// a budget at seven in the evening wants it changed for *tonight*; sending
  /// them to a setting would change it for every night.
  void _openFilters(BuildContext context) {
    context.pushNamed(AppRoute.rouletteFilters.routeName);
  }
}

/// The other places worth going from here.
///
/// Only routes that exist. A labelled tile leading to a placeholder is worse
/// than no tile: it teaches people that tiles do not work.
class _Elsewhere extends StatelessWidget {
  const _Elsewhere();

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: DashboardActionRow(
        actions: <DashboardAction>[
          DashboardAction(
            label: 'Browse',
            icon: AppIcons.meals,
            onTap: () => context.goNamed(AppRoute.meals.routeName),
          ),
          DashboardAction(
            label: 'Saved',
            icon: AppIcons.favoriteActive,
            onTap: () => context.pushNamed(AppRoute.favorites.routeName),
          ),
          DashboardAction(
            label: 'Yours',
            icon: AppIcons.add,
            onTap: () => context.pushNamed(AppRoute.myMeals.routeName),
          ),
        ],
      ),
    );
  }
}
