import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/circle_action.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';

/// The Profile tab (docs/design_ui.md §25).
///
/// Avatar and name at the top, then cards: preferences, household, budget,
/// statistics, settings. Each row shows its current value rather than only a
/// label, because a settings list you have to open to read is a settings list
/// nobody reads.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        // The four states, rendered from one AsyncValue rather than from three
        // booleans (docs/ARCHITECTURE.md §3.2).
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _ProfileError(
            failure: error is AppException ? error : const UnknownException(),
            onRetry: () =>
                ref.read(profileControllerProvider.notifier).refresh(),
          ),
          data: (UserProfile data) => _ProfileBody(profile: data),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.failure, required this.onRetry});

  final AppException failure;
  final VoidCallback onRetry;

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

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FoodPreferences preferences = profile.preferences;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.only(
            left: AppLayout.screenMargin,
            right: AppLayout.screenMargin,
            top: AppLayout.screenTopPadding,
            // Clears the floating navigation (docs/COMPONENTS.md §8).
            bottom: AppLayout.scrollBottomPadding,
          ),
          children: <Widget>[
            // **The house vocabulary, at last.** This screen was the last one
            // still built from `SectionHeader` + `IconListCard` + `StatCardRow`,
            // which is where the whole app started — every other tab moved to
            // `DashboardHeader`/`DashboardPanel`/`StatTrio` and this one did not,
            // so opening Profile felt like leaving the app. Nothing here is a new
            // idea; it is the same three components Home, Meals and the Kitchen
            // already use.
            DashboardHeader(
              title: profile.displayName.isEmpty
                  ? 'You'
                  : profile.displayName,
              subtitle: _kitchenLine(profile),
              actions: <Widget>[
                AppCircleAction(
                  icon: AppIcons.settings,
                  label: 'Settings',
                  onTap: () => context.pushNamed(AppRoute.settings.routeName),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),

            // **One panel, not three.** Three cards with their own padding, their
            // own headers and a gap between each left a settings screen that
            // scrolled past the fold to say six things, and then ended in a
            // hand-span of nothing above the navigation. These belong together —
            // they are all "what the app knows about you" — and inside one panel
            // the hairlines do the dividing that three separate cards were doing
            // with whitespace.
            DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  BigFigure(
                    label: 'Usually cooking for',
                    value: '${preferences.preferredServings}',
                    unit: preferences.preferredServings == 1
                        ? 'person'
                        : 'people',
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  StatTrio(
                    columns: <StatColumnData>[
                      StatColumnData(
                        label: 'Cuisines',
                        value: '${preferences.favouriteCuisines.length}',
                        onTap: () =>
                            context.pushNamed(AppRoute.preferences.routeName),
                      ),
                      StatColumnData(
                        label: 'Avoided',
                        value: '${preferences.dislikedFoods.length}',
                        onTap: () =>
                            context.pushNamed(AppRoute.preferences.routeName),
                      ),
                      StatColumnData(
                        label: 'Dietary',
                        value: '${preferences.dietaryTags.length}',
                        onTap: () =>
                            context.pushNamed(AppRoute.preferences.routeName),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.space4),
                  const DashboardRule(),

                  // **No value on this row.** It carried
                  // "Filipino, Japanese · 1 avoided", which is the trio directly
                  // above it said again in prose — and it was the long value that
                  // squeezed the title into "Food pr / efere…". The row's job is
                  // the way in; the numbers are already stated.
                  DashboardRow(
                    title: 'Food preferences',
                    subtitle: 'Cuisines, avoided foods, dietary needs',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: AppIconSize.xs,
                    ),
                    onTap: () =>
                        context.pushNamed(AppRoute.preferences.routeName),
                  ),
                  const DashboardRule(),
                  DashboardRow(
                    title: 'Budget',
                    subtitle: 'A head, not per pot',
                    // Short enough to be a figure, which is what `value` is for.
                    value: preferences.budget == null
                        ? 'Any'
                        : AppFormat.peso(preferences.budget!),
                    trailing: const Icon(
                      AppIcons.forward,
                      size: AppIconSize.xs,
                    ),
                    onTap: () =>
                        context.pushNamed(AppRoute.budgetSettings.routeName),
                  ),

                  const SizedBox(height: AppSpacing.space4),
                  const DashboardRule(),
                  const SizedBox(height: AppSpacing.space4),
                  DashboardActionRow(
                    actions: <DashboardAction>[
                      DashboardAction(
                        label: 'Recent',
                        icon: AppIcons.plannerActive,
                        onTap: () =>
                            context.pushNamed(AppRoute.mealHistory.routeName),
                      ),
                      DashboardAction(
                        label: 'Yours',
                        icon: AppIcons.meals,
                        onTap: () =>
                            context.pushNamed(AppRoute.myMeals.routeName),
                      ),
                      DashboardAction(
                        label: 'Settings',
                        icon: AppIcons.settings,
                        onTap: () =>
                            context.pushNamed(AppRoute.settings.routeName),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The line under the name.
  ///
  /// **The household, stated rather than offered.** This used to be a "Household"
  /// section with a row leading to `/couple` — invite a partner, join a kitchen,
  /// vote when you cannot agree. That feature was cut at Sprint 37, when the app
  /// became two people in one house on one phone: there is nobody to invite and
  /// nothing to agree about. A section pointing at it was a door to a room that no
  /// longer exists.
  ///
  /// The kitchen's *name* is still worth a word, because it is the thing every
  /// row in the database belongs to — so it says so here, in one line, and leads
  /// nowhere.
  static String _kitchenLine(UserProfile profile) =>
      profile.householdName ?? 'Our Kitchen';

}

