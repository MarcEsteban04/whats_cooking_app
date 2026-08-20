import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/avatar.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/profile/presentation/widgets/profile_row.dart';

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
            _ProfileHeader(profile: profile),

            const SectionHeader(title: 'My preferences'),
            ProfileCard(
              rows: <Widget>[
                ProfileRow(
                  title: 'Food preferences',
                  emoji: '🍽️',
                  value: _preferencesSummary(preferences),
                  onTap: () => context.goNamed(AppRoute.preferences.routeName),
                ),
                ProfileRow(
                  title: 'Budget',
                  emoji: '💰',
                  value: preferences.budget == null
                      ? 'No budget set'
                      : '${AppFormat.peso(preferences.budget!)} a meal',
                  onTap: () =>
                      context.goNamed(AppRoute.budgetSettings.routeName),
                ),
              ],
            ),

            const SectionHeader(title: 'Household'),
            ProfileCard(
              rows: <Widget>[
                ProfileRow(
                  title: profile.householdName ?? 'Our Kitchen',
                  emoji: '❤️',
                  value: profile.hasHousehold
                      ? 'Cooking together'
                      : 'Set up a shared kitchen',
                  onTap: () => context.goNamed(
                    profile.hasHousehold
                        ? AppRoute.couple.routeName
                        : AppRoute.householdSetup.routeName,
                  ),
                ),
              ],
            ),

            const SectionHeader(title: 'Settings'),
            ProfileCard(
              rows: <Widget>[
                ProfileRow(
                  title: 'Appearance',
                  emoji: '🌗',
                  onTap: () =>
                      context.goNamed(AppRoute.appearanceSettings.routeName),
                ),
                ProfileRow(
                  title: 'Account',
                  emoji: '🔑',
                  value: 'Password, sign out, delete',
                  onTap: () =>
                      context.goNamed(AppRoute.accountSettings.routeName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A one-line summary of the six preference fields.
  ///
  /// Cuisines first, because that is the answer people remember giving; then a
  /// count of the things they avoid, which is the answer that changes the results
  /// most.
  static String _preferencesSummary(FoodPreferences preferences) {
    final List<String> parts = <String>[
      if (preferences.favouriteCuisines.isNotEmpty)
        preferences.favouriteCuisines
            .take(_summaryCuisines)
            .map((Cuisine cuisine) => cuisine.label)
            .join(', '),
      if (preferences.dislikedFoods.isNotEmpty)
        '${preferences.dislikedFoods.length} avoided',
      if (preferences.dietaryTags.isNotEmpty)
        '${preferences.dietaryTags.length} dietary',
    ];

    return parts.isEmpty ? 'Nothing set yet' : parts.join(' · ');
  }

  static const int _summaryCuisines = 2;
}

/// Avatar, name and the line beneath it (docs/design_ui.md §25).
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.space5),
        Avatar(
          name: profile.displayName,
          imageUrl: profile.avatarUrl,
          size: AvatarSize.large,
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          profile.displayName.isEmpty ? 'You' : profile.displayName,
          style: context.text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          // §25 shows "Food Explorer · 32 meals". The meal count needs the
          // history feature (Sprint 31), so until then this says only what is
          // true rather than a zero that reads as a broken counter.
          'Food explorer',
          style: context.text.metadata,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
