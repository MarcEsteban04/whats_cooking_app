import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';

/// "Dinner decided" (docs/design_ui.md §14, Sprint 31).
///
/// The end of the loop, and a **route** rather than a state on the result screen
/// now that there is a history row to point at. That matters more than it sounds:
/// the decision now survives a restart, can be reopened from the history list,
/// and is the same screen either way — which is the difference between a
/// celebration and a confirmation.
///
/// The card **inverts to ink** rather than taking a tint. The palette has one
/// accent and it belongs to the SPIN button (docs/DESIGN_SYSTEM.md §2.2), so on a
/// page of pale surfaces the loudest thing left to say is "black" — which is
/// what §14's "celebratory confirmation" needs to be.
class DecidedScreen extends ConsumerWidget {
  const DecidedScreen({
    required this.historyId,
    this.addedToList,
    super.key,
  });

  final String historyId;

  /// How many lines the accepted meal put on the shopping list (Sprint 43).
  ///
  /// Null when this screen was reached any way other than accepting — a deep
  /// link, a restart, the history list. That is a third state, not a zero: "we
  /// do not know" has to read differently from "nothing was needed", and the
  /// screen says nothing at all rather than claiming either.
  final int? addedToList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MealHistoryEntry> entry = ref.watch(
      historyEntryProvider(historyId),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.screenMargin),
              child: switch (entry) {
                AsyncData<MealHistoryEntry>(:final MealHistoryEntry value) =>
                  _Decided(entry: value, addedToList: addedToList),
                AsyncError<MealHistoryEntry>(:final Object error) => ErrorState(
                  kind: error is AppException
                      ? error.errorStateKind
                      : ErrorStateKind.unknown,
                  body: error is AppException ? error.displayMessage : null,
                  onRetry: () =>
                      ref.invalidate(historyEntryProvider(historyId)),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Decided extends StatelessWidget {
  const _Decided({required this.entry, this.addedToList});

  final MealHistoryEntry entry;
  final int? addedToList;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final Meal? meal = entry.meal;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'DINNER DECIDED',
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceInverse,
            borderRadius: AppRadius.borderXxxl,
            boxShadow: context.shadows.xl,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  // The occasion, not the date. "Dinner" is what somebody
                  // standing in their kitchen recognises; the timestamp is on
                  // the history list where it is a fact rather than a headline.
                  entry.mealType.label.toUpperCase(),
                  style: context.text.overline.copyWith(
                    color: colors.textOnInverse,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  entry.displayName,
                  style: context.text.displayMedium.copyWith(
                    color: colors.textOnInverse,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  "You're eating this tonight.",
                  style: context.text.bodyMedium.copyWith(
                    color: colors.textOnInverse,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (meal != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.space5),
                  // §14 asks for time, estimated cost and ingredients. The first
                  // two are here; ingredients live one tap away on the meal
                  // itself rather than being repeated in a celebration.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.space2,
                    runSpacing: AppSpacing.space2,
                    children: <Widget>[
                      if (entry.costPerServing case final double cost)
                        MetadataPill(
                          icon: AppIcons.budget,
                          label: '${AppFormat.peso(cost)} a head',
                        ),
                      MetadataPill(
                        icon: AppIcons.cookingTime,
                        label: AppFormat.cookingTime(meal.cookingTimeMinutes),
                      ),
                      MetadataPill(
                        icon: AppIcons.servings,
                        label: AppFormat.servings(meal.servings),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        // What accepting this just did to the shopping list (Sprint 43).
        //
        // Inside the celebration rather than as a banner over it, and phrased as
        // a fact: "4 things added" is useful, and a screen that interrupts a
        // decision to talk about errands is not. Silent when the count is zero,
        // because "nothing was added" on a night the kitchen already had
        // everything is the app congratulating itself for doing nothing.
        if (addedToList case final int added when added > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          Center(
            child: AppButton.tertiary(
              label:
                  '$added ${added == 1 ? 'thing' : 'things'} added to the list',
              size: AppButtonSize.small,
              leadingIcon: AppIcons.grocery,
              onPressed: () => context.goNamed(AppRoute.grocery.routeName),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.space6),
        if (meal != null)
          AppButton.primary(
            label: 'How to cook it',
            size: AppButtonSize.large,
            onPressed: () => context.pushNamed(
              AppRoute.mealDetail.routeName,
              pathParameters: <String, String>{'id': meal.id},
              extra: meal,
            ),
          ),
        const SizedBox(height: AppSpacing.space3),
        AppButton.secondary(
          label: 'What we have eaten',
          onPressed: () => context.pushNamed(AppRoute.mealHistory.routeName),
        ),
        const SizedBox(height: AppSpacing.space2),
        Align(
          child: AppButton.tertiary(
            label: 'Done',
            size: AppButtonSize.small,
            // Home, not back. Back would return to the result screen for a
            // decision already made, which is a screen offering to re-spin
            // something the household has settled.
            onPressed: () => context.goNamed(AppRoute.home.routeName),
          ),
        ),
      ],
    );
  }
}
