import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';

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
/// The three stat columns are the constraints the spin will actually apply, so
/// docs/USER_FLOWS.md §6's rule holds — "current budget and party size are
/// always visible on Home, so the user never wonders what the app is about to
/// assume" — and each one is tappable straight through to the setting behind it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(
      profileControllerProvider,
    );
    final FoodPreferences? preferences = profile.value?.preferences;

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
                _SpinPanel(preferences: preferences),
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
  const _SpinPanel({required this.preferences});

  /// Null while the profile loads. The panel renders anyway — the button is the
  /// point, and it works without knowing the budget.
  final FoodPreferences? preferences;

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
                value: preferences?.budget == null
                    ? '—'
                    : AppFormat.peso(preferences!.budget!),
                unit: 'a head',
                color: colors.series1,
                onTap: () => _openPreferences(context),
              ),
              StatColumnData(
                label: 'Cooking for',
                value: '${preferences?.preferredServings ?? 2}',
                unit: 'people',
                color: colors.series2,
                onTap: () => _openPreferences(context),
              ),
              StatColumnData(
                label: 'No longer than',
                value: preferences?.maxCookingTimeMinutes == null
                    ? 'any'
                    : '${preferences!.maxCookingTimeMinutes}',
                unit: preferences?.maxCookingTimeMinutes == null
                    ? 'time'
                    : 'min',
                color: colors.primary,
                onTap: () => _openPreferences(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space5),
          // The strongest call to action in the app (docs/COMPONENTS.md §36:
          // `brand` is for this button and nothing else).
          AppButton.brand(
            label: 'SPIN',
            size: AppButtonSize.large,
            onPressed: () => context.goNamed(AppRoute.roulette.routeName),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            AppConstants.tagline,
            style: context.text.metadata,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Where the numbers on this panel actually live.
  ///
  /// Sprint 30 repoints these at the roulette's filter sheet, which is a
  /// per-spin override of the same values (docs/COMPONENTS.md §7). Until that
  /// sheet exists, sending someone to the setting they are looking at beats
  /// sending them to a screen that says "Sprint 30".
  void _openPreferences(BuildContext context) {
    context.goNamed(AppRoute.preferences.routeName);
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
