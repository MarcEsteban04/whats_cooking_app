import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/disliked_ingredients_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
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

    // Warmed here, deliberately, and the values are not used on this screen.
    //
    // The spin needs all of these before it can pick — the hidden set, the saved
    // set, what the household has eaten, the meals their avoided foods rule out,
    // and the profile — and fetching them cold *during* the animation is what
    // made the first spin of a session roll nothing while every spin after it
    // rolled properly. Asking while somebody is still deciding whether to tap
    // SPIN costs nothing they can see.
    ref.watch(dislikesControllerProvider);
    ref.watch(favoritesControllerProvider);
    ref.watch(mealHistoryProvider);
    ref.watch(mealsBlockedByDislikesProvider);
    ref.watch(pantryMatchesProvider);

    // Read, not just warmed: Home says what needs using tonight (Sprint 40), and
    // from Sprint 41 the spin weights meals by what is already in.
    final List<PantryItem> pantry =
        ref.watch(pantryControllerProvider).value ?? const <PantryItem>[];

    // One clock for the whole build, so no two rows can disagree about what day
    // it is if this renders across midnight.
    final DateTime now = DateTime.now();
    final int needsUsing = pantry
        .where((PantryItem item) => item.statusAsOf(now).needsAttention)
        .length;

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
                  needsUsing: needsUsing,
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
  const _SpinPanel({
    required this.filters,
    required this.servings,
    this.needsUsing = 0,
  });

  /// What the next spin will narrow by.
  final SpinFilters filters;

  /// How many the household is cooking for.
  ///
  /// A preference rather than a filter: it changes the cost a head the reader is
  /// comparing against, not which meals are eligible.
  final int servings;

  /// How many things in the kitchen want eating soon (Sprint 40).
  ///
  /// Zero hides the line entirely. A permanent row reading "0 to use up" is a
  /// warning somebody learns to stop seeing, and this one has to still work on the
  /// evening it matters.
  final int needsUsing;

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
                // No unit when there is no figure to qualify: "Any a head" is
                // not a thing anybody says.
                unit: filters.maxCostPerServing == null ? null : 'a head',
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
                label: 'Ready in',
                value: filters.maxCookingTimeMinutes == null
                    ? 'Any'
                    : '${filters.maxCookingTimeMinutes}',
                unit: filters.maxCookingTimeMinutes == null ? null : 'min',
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

          // What the fridge is about to lose (Sprint 40).
          //
          // Under the spin rather than above it, because it is not the question
          // Home exists to ask — it is a reason to answer that question a
          // particular way tonight. And phrased as an amount rather than a
          // scolding: "2 things to use up" is a fact, where "you are wasting
          // food" is an app with an opinion about somebody's week.
          if (needsUsing > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Center(
              child: AppButton.tertiary(
                label:
                    '$needsUsing ${needsUsing == 1 ? 'thing' : 'things'} to use up',
                size: AppButtonSize.small,
                leadingIcon: AppIcons.expiring,
                onPressed: () => context.goNamed(AppRoute.pantry.routeName),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _filterLabel {
    final int chosen = filters.chosenCount;

    // The mood leads when there is one. It is the choice that changes the
    // *character* of what comes back rather than the size of the pool, so
    // "Comfort food" tells a reader more about their next spin than "2 filters
    // on" does — and a mood chosen last night and forgotten is exactly the
    // surprise §6 exists to prevent.
    if (filters.mood case final Mood mood) {
      return chosen == 0 ? mood.label : '${mood.label} · $chosen';
    }

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
          // On Home rather than buried in the Meals tab, because what the
          // household ate this week is the thing somebody checks *before*
          // spinning — "not chicken again" is a decision made here.
          DashboardAction(
            label: 'Recent',
            icon: AppIcons.plannerActive,
            onTap: () => context.pushNamed(AppRoute.mealHistory.routeName),
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
