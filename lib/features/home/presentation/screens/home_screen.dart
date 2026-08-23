import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/meal_moment.dart';
import 'package:whats_cooking/core/domain/mood.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/home/presentation/providers/home_dashboard.dart';
import 'package:whats_cooking/features/home/presentation/providers/tonight.dart';
import 'package:whats_cooking/features/home/presentation/widgets/dashboard_charts.dart';
import 'package:whats_cooking/features/meals/presentation/providers/disliked_ingredients_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';
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
    // The one extra query this screen's second panel costs. Warmed with the rest
    // rather than fetched when the panel builds, so the numbers are there on the
    // first frame instead of appearing a beat later.
    ref.watch(groceryControllerProvider);

    // The library and the places, for the dashboard's own counts and for the
    // setup guide that replaces it on a fresh install. Two more warmed queries,
    // paid once a session because both are `keepAlive`.
    ref.watch(restaurantsControllerProvider);

    // Where things stand. Best effort by construction — a dashboard that failed
    // is a panel that does not appear, never a reason Home does not load.
    final HomeDashboard? dashboard = ref.watch(homeDashboardProvider).value;

    // Whether this meal is already settled (Sprint 55).
    //
    // `.value` rather than a `switch`, and that is the point: while this is
    // loading the panel shows the question, which is the *correct* thing to show
    // if nothing has been decided and a harmless half-second if something has.
    // A spinner where SPIN belongs would be the app hesitating over its one job.
    final Decided? decided = ref.watch(decidedNowProvider).value;

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
                  // Follows the clock. It read "Tonight" at three in the
                  // morning, which is where somebody noticed.
                  title: MealMoment.current.heading,
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
                  decided: decided,
                ),

                // Where things stand (Sprint 47b).
                //
                // **Below the button, never above it.** Home has one job and it is
                // the question at the top; a dashboard that pushes SPIN down the
                // screen has decided that looking at numbers matters more than
                // deciding what to eat, which is the opposite of the product.
                //
                if (dashboard case final HomeDashboard data) ...<Widget>[
                  const SizedBox(height: AppSpacing.space4),
                  // **Two panels, and which one appears is the whole fix.** The
                  // first version showed nothing at all on a fresh install,
                  // reasoning that four zeros were worse than a gap. That was the
                  // wrong default for the state most people are in on day one —
                  // an empty app is exactly when the screen has something worth
                  // saying, which is what to do next.
                  if (data.hasAnything)
                    _WhereThingsStand(dashboard: data)
                  else
                    _GetStarted(dashboard: data),
                ],

                const SizedBox(height: AppSpacing.space4),
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

/// Where things stand (Sprint 47b).
///
/// **Counts that are destinations, then charts that are not.** The split is
/// deliberate and it is the answer to a question docs/project_dev.md already
/// settled: "food statistics" was cut as "an interesting dashboard nobody opens
/// twice", and a pie chart on its own screen deserved that. These two earn their
/// place because each one changes a decision — the spend trend tells you whether
/// to cook this week, and the cuisine mix is the variety engine's premise made
/// checkable.
///
/// The three counts above them are the opposite kind of number: every one is a
/// tap to the screen where it can be changed.
class _WhereThingsStand extends StatelessWidget {
  const _WhereThingsStand({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BigFigure(
            label: 'Decided this week',
            value: '${dashboard.decisions}',
            unit: dashboard.decisions == 1 ? 'dinner' : 'dinners',
          ),

          // How the week split, and what it cost. One line rather than a
          // two-segment bar, because "four cooked, one out" is the whole story and
          // a bar of it would be a graphic of a sentence. The six-week chart below
          // is where a shape earns its space.
          if (dashboard.decisions > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              <String>[
                '${dashboard.mealsCooked} cooked',
                if (dashboard.nightsOut > 0) '${dashboard.nightsOut} out',
                if (dashboard.averageCostPerHead case final double cost)
                  'about ${AppFormat.peso(cost.round())} a head',
              ].join(' · '),
              style: context.text.metadata,
            ),
          ],

          const SizedBox(height: AppSpacing.space5),
          StatTrio(
            columns: <StatColumnData>[
              StatColumnData(
                label: 'Can cook now',
                value: '${dashboard.cookableNow}',
                color: colors.series1,
                onTap: () => context.goNamed(AppRoute.meals.routeName),
              ),
              StatColumnData(
                label: 'To use up',
                value: '${dashboard.needsUsing}',
                // The one column that changes colour, because it is the one with a
                // deadline — and only when there is something to warn about. An
                // amber zero is a warning somebody learns to stop seeing.
                color: dashboard.needsUsing > 0
                    ? colors.warning.color
                    : colors.series2,
                onTap: () => context.goNamed(AppRoute.pantry.routeName),
              ),
              StatColumnData(
                label: 'To buy',
                value: '${dashboard.stillToBuy}',
                color: colors.primary,
                onTap: () => context.goNamed(AppRoute.grocery.routeName),
              ),
            ],
          ),

          // The charts, and only once there is history to draw. A chart of one
          // dinner is a chart making a claim about a trend it cannot see.
          if (dashboard.hasHistory) ...<Widget>[
            const SizedBox(height: AppSpacing.space5),
            const DashboardRule(),
            const SizedBox(height: AppSpacing.space4),
            SpendChart(weeks: dashboard.spend),

            if (dashboard.cuisineMix.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),
              const SizedBox(height: AppSpacing.space4),
              CuisineMix(counts: dashboard.cuisineMix),
            ],
          ],
        ],
      ),
    );
  }
}

/// What Home shows before anything has happened (Sprint 47b).
///
/// **This is the panel that should have been there on day one.** The first version
/// hid the dashboard until a number was real, on the argument that four zeros are
/// worse than a gap — which is true of zeros and false of the space. An empty app
/// is exactly when this screen has something worth saying, and it is not a figure:
/// it is the three things that make the roulette worth using.
///
/// Ticked rather than hidden once done, so the list is a short record of progress
/// rather than a shrinking pile of chores — and so that finishing the last one
/// visibly finishes something.
class _GetStarted extends StatelessWidget {
  const _GetStarted({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final List<({String label, String body, bool isDone, HomeSetupStep step})>
    steps = dashboard.setupSteps;
    final int done = steps.where((({String label, String body, bool isDone, HomeSetupStep step}) s) => s.isDone).length;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BigFigure(
            label: 'Worth setting up',
            value: '$done of ${steps.length}',
            unit: 'done',
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            // Says what the payoff is, because a checklist with no stated reward is
            // homework. The roulette already works — this is what makes it good.
            'It already works. These make it better at guessing.',
            style: context.text.metadata,
          ),
          const SizedBox(height: AppSpacing.space5),
          for (final (int index,
                  ({String label, String body, bool isDone, HomeSetupStep step})
                  step)
              in steps.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            PressFeedback(
              onTap: () => _open(context, step.step),
              semanticLabel: step.label,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      step.isDone
                          ? AppIcons.success
                          : AppIcons.forward,
                      size: AppIconSize.sm,
                      color: step.isDone
                          ? colors.series2
                          : colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            step.label,
                            style: context.text.bodyLarge.copyWith(
                              color: step.isDone ? colors.textTertiary : null,
                              decoration: step.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: colors.textTertiary,
                            ),
                          ),
                          if (!step.isDone)
                            Text(step.body, style: context.text.metadata),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, HomeSetupStep step) {
    switch (step) {
      case HomeSetupStep.meals:
        context.pushNamed(AppRoute.mealCreate.routeName);
      case HomeSetupStep.pantry:
        context.goNamed(AppRoute.pantry.routeName);
      case HomeSetupStep.places:
        context.pushNamed(AppRoute.restaurantCreate.routeName);
    }
  }
}

/// The centrepiece: the question, the constraints, and the button.
class _SpinPanel extends StatelessWidget {
  const _SpinPanel({
    required this.filters,
    required this.servings,
    this.needsUsing = 0,
    this.decided,
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

  /// What was already settled for this meal, or null while it is still open
  /// (Sprint 55).
  final Decided? decided;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The answer, when there is one. Otherwise the question.
          //
          // **This is the panel admitting its job is done.** It asked "what are
          // we eating tonight?" over a large accent-coloured SPIN whether or not
          // the household had decided an hour earlier — and spinning again wrote
          // a *second* dinner into the history, so the week's count and the spend
          // chart both claimed they ate twice. For an app that exists to make one
          // decision an evening, not noticing the decision was the sharpest thing
          // it could be wrong about.
          if (decided case final Decided settled)
            _Settled(decided: settled)
          else ...<Widget>[
            Text(
              'What are we eating ${MealMoment.current.phrase}?',
              style: context.text.displayMedium,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text('Let us decide for you.', style: context.text.bodyMedium),
          ],
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
          // Settled: the loudest thing is the decision, and spinning is demoted
          // to a small line under it.
          //
          // **Ink rather than the accent, deliberately.** The palette has one
          // accent and it belongs to SPIN (docs/DESIGN_SYSTEM.md §2.2) — putting
          // it on "Open it" would make deciding again the second-loudest thing on
          // a screen whose question has been answered. The decided screen inverts
          // to ink for the same reason, and this is the button that opens it.
          if (decided case final Decided settled) ...<Widget>[
            if (settled.historyId case final String historyId)
              AppButton.inverse(
                label: 'Open it',
                size: AppButtonSize.large,
                onPressed: () => context.pushNamed(
                  AppRoute.decided.routeName,
                  pathParameters: <String, String>{'historyId': historyId},
                ),
              )
            else
              // A night out has no history row to open — nothing was cooked, so
              // there is no recipe, no cooking mode and no shopping list. Where
              // they have been is the honest destination instead.
              AppButton.inverse(
                label: 'Where we have been',
                size: AppButtonSize.large,
                onPressed: () =>
                    context.pushNamed(AppRoute.restaurantHistory.routeName),
              ),
            const SizedBox(height: AppSpacing.space3),
            Center(
              child: AppButton.tertiary(
                // Not "SPIN again". Deciding twice in an evening is changing your
                // mind, and the button should say the thing the person is actually
                // doing — including that the first decision is about to be
                // replaced.
                label: 'Change our mind',
                size: AppButtonSize.small,
                leadingIcon: AppIcons.spin,
                onPressed: () => context.goNamed(AppRoute.roulette.routeName),
              ),
            ),
          ] else ...<Widget>[
            // The strongest call to action in the app, and the only thing wearing
            // the palette's one accent (docs/DESIGN_SYSTEM.md §2.2).
            AppButton.brand(
              label: 'SPIN',
              size: AppButtonSize.large,
              onPressed: () => context.goNamed(AppRoute.roulette.routeName),
            ),
          ],
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

          // Ask and Recent, inside the card the spin lives in rather than in a
          // panel of their own at the bottom of the screen.
          //
          // They belong here: both are things somebody reaches for *while*
          // deciding, not afterwards. "Not chicken again" is checked before
          // spinning, and asking in words is the alternative to spinning at all —
          // so a separate panel two scrolls down was filing them as afterthoughts.
          const SizedBox(height: AppSpacing.space5),
          const DashboardRule(),
          const SizedBox(height: AppSpacing.space4),
          DashboardActionRow(
            actions: <DashboardAction>[
              DashboardAction(
                label: 'Ask',
                icon: AppIcons.assistant,
                onTap: () => context.pushNamed(AppRoute.assistant.routeName),
              ),
              DashboardAction(
                label: 'Recent',
                icon: AppIcons.plannerActive,
                onTap: () => context.pushNamed(AppRoute.mealHistory.routeName),
              ),
            ],
          ),
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

/// The answer, where the question used to be (Sprint 55).
///
/// **The one place in this app where Home leads with a name rather than a
/// figure.** The class doc above argues that Home's number would have to be
/// invented — "60 meals available" is not what anybody in their kitchen at seven
/// wants to read — so the question is the figure. Once the question has been
/// answered, the *answer* is the figure, and it is the only thing on the screen
/// worth setting in display type.
///
/// It says when, and it says whether it was cooked or eaten out, because both are
/// how somebody checks the app is talking about the right meal. An app that says
/// "Adobo" with no hour attached is asking to be believed rather than checked.
class _Settled extends StatelessWidget {
  const _Settled({required this.decided});

  final Decided decided;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          // The moment's own word, so a settled breakfast does not read
          // "TONIGHT" — the same bug `MealMoment` was written to fix on the
          // header and the result screen's overline.
          '${MealMoment.current.mealName} is settled'.toUpperCase(),
          style: context.text.overline,
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          AppFormat.sentenceCase(decided.name),
          style: context.text.displayMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space2),
        Row(
          children: <Widget>[
            Icon(
              decided.wasEatenOut ? AppIcons.meals : AppIcons.check,
              size: _markSize,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space2),
            Flexible(
              child: Text(
                AppFormat.metadata(<String?>[
                  decided.wasEatenOut ? 'You ate out' : 'Decided',
                  AppFormat.timeOfDay(decided.at),
                ]),
                style: context.text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const double _markSize = 16;
}

