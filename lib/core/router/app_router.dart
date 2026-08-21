import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/router/app_pages.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/router/app_shell.dart';
import 'package:whats_cooking/core/router/router_guards.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/placeholder_screen.dart';
import 'package:whats_cooking/features/ai/presentation/screens/assistant_screen.dart';
import 'package:whats_cooking/features/ai/presentation/screens/fridge_scan_screen.dart';
import 'package:whats_cooking/features/ai/presentation/screens/recipe_generator_screen.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/login_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/register_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/welcome_screen.dart';
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/presentation/screens/grocery_import_screen.dart';
import 'package:whats_cooking/features/grocery/presentation/screens/grocery_item_sheet.dart';
import 'package:whats_cooking/features/grocery/presentation/screens/grocery_screen.dart';
import 'package:whats_cooking/features/history/presentation/screens/decided_screen.dart';
import 'package:whats_cooking/features/history/presentation/screens/meal_history_screen.dart';
import 'package:whats_cooking/features/home/presentation/screens/home_screen.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/presentation/screens/disliked_meals_screen.dart';
import 'package:whats_cooking/features/meals/presentation/screens/favorites_screen.dart';
import 'package:whats_cooking/features/meals/presentation/screens/meal_detail_screen.dart';
import 'package:whats_cooking/features/meals/presentation/screens/meal_form_screen.dart';
import 'package:whats_cooking/features/meals/presentation/screens/meals_screen.dart';
import 'package:whats_cooking/features/meals/presentation/screens/my_meals_screen.dart';
import 'package:whats_cooking/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/screens/pantry_item_sheet.dart';
import 'package:whats_cooking/features/pantry/presentation/screens/pantry_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/account_settings_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/appearance_settings_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/budget_settings_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/preferences_screen.dart';
import 'package:whats_cooking/features/profile/presentation/screens/profile_screen.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/screens/restaurant_form_screen.dart';
import 'package:whats_cooking/features/restaurants/presentation/screens/restaurant_result_screen.dart';
import 'package:whats_cooking/features/restaurants/presentation/screens/restaurant_spin_screen.dart';
import 'package:whats_cooking/features/restaurants/presentation/screens/restaurants_screen.dart';
import 'package:whats_cooking/features/roulette/presentation/screens/spin_filters_sheet.dart';
import 'package:whats_cooking/features/roulette/presentation/screens/spin_result_screen.dart';
import 'package:whats_cooking/features/roulette/presentation/screens/spin_screen.dart';

part 'app_router.g.dart';

/// The root navigator, used by routes that must cover the bottom navigation.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// One navigator per tab, so each keeps its own stack (§9).
final Map<AppTab, GlobalKey<NavigatorState>> tabNavigatorKeys =
    <AppTab, GlobalKey<NavigatorState>>{
      for (final AppTab tab in AppTab.values)
        tab: GlobalKey<NavigatorState>(debugLabel: tab.name),
    };

/// The application's single [GoRouter] instance.
///
/// Kept alive deliberately: navigation state must survive the disposal of any
/// individual screen, so this is one of the justified exceptions to the
/// `autoDispose` default (docs/CODING_STANDARDS.md §11).
///
/// The redirect is the app's only auth check. docs/NAVIGATION_MAP.md §4: "No
/// screen performs its own auth check — one place to reason about, one place to
/// get wrong." The rules themselves live in [RouterGuard] as a pure function,
/// which is why they can be exhaustively tested without a widget tree.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // A listenable rather than a `watch`: rebuilding the router on every session
  // change would rebuild the entire navigator stack and lose the user's place.
  // GoRouter re-runs its redirect when this notifies, which is all that is
  // needed.
  final _SessionListenable sessionListenable = _SessionListenable(ref);
  ref.onDispose(sessionListenable.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    refreshListenable: sessionListenable,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      return RouterGuard.redirect(
        location: state.uri.toString(),
        session: ref.read(sessionProvider),
      );
    },
    // §2: an unmatched path goes to Home when authenticated and Welcome
    // otherwise. Handled here rather than in the guard so a genuinely broken
    // link is visible as a 404 instead of being silently absorbed.
    errorBuilder: (BuildContext context, GoRouterState state) {
      final AppSession session = ref.read(sessionProvider);
      return _NotFoundScreen(isAuthenticated: session.isAuthenticated);
    },
    routes: <RouteBase>[
      ..._publicRoutes,
      ..._onboardingRoutes,
      // Before the shell, and that ordering is load-bearing. GoRouter matches in
      // declaration order, and the shell holds /meals/:id — so declared after
      // it, /meals/new would resolve to a meal whose id is "new".
      _mealCreateRoute,
      _mealEditRoute,
      _mealInventRoute,
      _shellRoute,
      ..._fullScreenRoutes,
      ..._coupleRoutes,
      ..._plannerRoutes,
      _errorRoute,
    ],
  );
}

// -----------------------------------------------------------------------------
// Public zone
// -----------------------------------------------------------------------------

final List<RouteBase> _publicRoutes = <RouteBase>[
  _route(AppRoute.splash, const _SplashScreen(), sprint: 'Sprint 17'),
  _route(AppRoute.welcome, const WelcomeScreen(), sprint: 'Sprint 16'),
  GoRoute(
    path: AppRoute.login.path,
    name: AppRoute.login.routeName,
    builder: (BuildContext context, GoRouterState state) => LoginScreen(
      // Carried by the register screen when an address already has an account
      // (docs/USER_FLOWS.md §2), so the user does not retype it.
      prefilledEmail: state.uri.queryParameters['email'],
    ),
  ),
  _route(AppRoute.register, const RegisterScreen(), sprint: 'Sprint 16'),
  _route(
    AppRoute.forgotPassword,
    const ForgotPasswordScreen(),
    sprint: 'Sprint 16',
  ),
  GoRoute(
    path: AppRoute.resetPassword.path,
    name: AppRoute.resetPassword.routeName,
    builder: (BuildContext context, GoRouterState state) => ResetPasswordScreen(
      // The recovery token from the deep link (docs/NAVIGATION_MAP.md §5).
      token: state.uri.queryParameters['token'],
    ),
  ),
  _route(AppRoute.guestSpin, null, sprint: 'Sprint 29 (P1)'),
];

// -----------------------------------------------------------------------------
// Onboarding zone
//
// One route with internal paging (§2), plus the optional household branch.
// -----------------------------------------------------------------------------

final List<RouteBase> _onboardingRoutes = <RouteBase>[
  GoRoute(
    path: AppRoute.onboarding.path,
    name: AppRoute.onboarding.routeName,
    builder: (BuildContext context, GoRouterState state) =>
        const OnboardingScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: _relative(AppRoute.onboardingHousehold, AppRoute.onboarding),
        name: AppRoute.onboardingHousehold.routeName,
        builder: (BuildContext context, GoRouterState state) =>
            const PlaceholderScreen(
              title: 'Onboarding — household',
              sprint: 'Sprint 41',
            ),
      ),
    ],
  ),
];

// -----------------------------------------------------------------------------
// The shell
// -----------------------------------------------------------------------------

final StatefulShellRoute _shellRoute = StatefulShellRoute.indexedStack(
  builder: (
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => AppShell(navigationShell: navigationShell),
  branches: <StatefulShellBranch>[
    StatefulShellBranch(
      navigatorKey: tabNavigatorKeys[AppTab.home],
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.home.path,
          name: AppRoute.home.routeName,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const AppInstantPage<void>(child: HomeScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.rouletteFilters, AppRoute.home),
              name: AppRoute.rouletteFilters.routeName,
              // On the **root** navigator despite being nested under `/home`.
              // Pushed on the branch navigator, the sheet drew *under* the
              // floating bottom navigation — which sits above the branch — and
              // the nav capsule covered its SPIN button. A sheet that hides its
              // own primary action is worse than no sheet.
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  const AppSheetPage<void>(child: SpinFiltersSheet()),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: tabNavigatorKeys[AppTab.meals],
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.meals.path,
          name: AppRoute.meals.routeName,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const AppInstantPage<void>(child: MealsScreen()),
          // Literal segments are declared before `:id`, because GoRouter matches
          // in declaration order — with `:id` first, `/meals/search` would
          // resolve to a meal whose id is "search".
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.mealSearch, AppRoute.meals),
              name: AppRoute.mealSearch.routeName,
              // The same screen with the keyboard already up. Home's search
              // affordance lands here (docs/USER_FLOWS.md §6); the tab itself
              // lands on /meals, where the search field waits to be tapped.
              builder: (BuildContext context, GoRouterState state) =>
                  const MealsScreen(autofocusSearch: true),
            ),
            GoRoute(
              path: _relative(AppRoute.favorites, AppRoute.meals),
              name: AppRoute.favorites.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const FavoritesScreen(),
            ),
            GoRoute(
              path: _relative(AppRoute.dislikedMeals, AppRoute.meals),
              name: AppRoute.dislikedMeals.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const DislikedMealsScreen(),
            ),
            GoRoute(
              path: _relative(AppRoute.mealHistory, AppRoute.meals),
              name: AppRoute.mealHistory.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const MealHistoryScreen(),
            ),
            GoRoute(
              path: _relative(AppRoute.myMeals, AppRoute.meals),
              name: AppRoute.myMeals.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const MyMealsScreen(),
            ),
            GoRoute(
              path: _relative(AppRoute.mealDetail, AppRoute.meals),
              name: AppRoute.mealDetail.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  MealDetailScreen(
                    mealId: state.pathParameters['id']!,
                    // The row that was tapped hands over the meal it already
                    // has, so the screen paints before the read returns
                    // (Sprint 27). Null on a deep link or a cold start, which
                    // is what the skeleton is still there for.
                    preview: state.extra is Meal ? state.extra as Meal : null,
                  ),
              // No children. `/meals/:id/edit` is `_mealEditRoute`, on the root
              // navigator beside `/meals/new`, because the two are the same
              // screen doing the same job — see its own comment.
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: tabNavigatorKeys[AppTab.pantry],
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.pantry.path,
          name: AppRoute.pantry.routeName,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const AppInstantPage<void>(child: PantryScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.pantryAdd, AppRoute.pantry),
              name: AppRoute.pantryAdd.routeName,
              // On the **root** navigator, for the same reason the roulette's
              // filter sheet is: pushed on the branch navigator it drew *under*
              // the floating bottom navigation, and the nav capsule covered its
              // "Add to the kitchen" button. Twice now, so it is worth saying
              // plainly — **every modal sheet in this app belongs on the root
              // navigator**.
              parentNavigatorKey: rootNavigatorKey,
              // One sheet for adding and for editing an amount (Sprint 39).
              // `extra` carries the item when it is an edit — the pantry row is
              // already in hand, so making the sheet re-fetch it would be a round
              // trip to learn something the list already knows.
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  AppSheetPage<void>(
                    child: PantryItemSheet(
                      existing: state.extra is PantryItem
                          ? state.extra as PantryItem
                          : null,
                    ),
                  ),
            ),
            _child(
              AppRoute.ingredientMatches,
              AppRoute.pantry,
              'Ingredient matches',
              sprint: 'Sprint 41',
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: tabNavigatorKeys[AppTab.grocery],
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.grocery.path,
          name: AppRoute.grocery.routeName,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const AppInstantPage<void>(child: GroceryScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.groceryAdd, AppRoute.grocery),
              name: AppRoute.groceryAdd.routeName,
              // Root navigator, per the rule the pantry sheet's comment states:
              // every modal sheet in this app belongs here, or the floating
              // bottom navigation covers its primary button.
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  AppSheetPage<void>(
                    child: GroceryItemSheet(
                      existing: state.extra is GroceryItem
                          ? state.extra as GroceryItem
                          : null,
                    ),
                  ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: tabNavigatorKeys[AppTab.profile],
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.profile.path,
          name: AppRoute.profile.routeName,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const AppInstantPage<void>(child: ProfileScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.preferences, AppRoute.profile),
              name: AppRoute.preferences.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const PreferencesScreen(),
            ),
            GoRoute(
              path: _relative(AppRoute.budgetSettings, AppRoute.profile),
              name: AppRoute.budgetSettings.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const BudgetSettingsScreen(),
            ),
            _child(
              AppRoute.statistics,
              AppRoute.profile,
              'Statistics',
              sprint: 'Sprint 63 (P1)',
            ),
            GoRoute(
              path: _relative(AppRoute.settings, AppRoute.profile),
              name: AppRoute.settings.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  const PlaceholderScreen(
                    title: 'Settings',
                    sprint: 'Sprint 20',
                  ),
              routes: <RouteBase>[
                _child(
                  AppRoute.notificationSettings,
                  AppRoute.settings,
                  'Notifications',
                  sprint: 'Sprint 49 (P2)',
                ),
                GoRoute(
                  path: _relative(
                    AppRoute.appearanceSettings,
                    AppRoute.settings,
                  ),
                  name: AppRoute.appearanceSettings.routeName,
                  builder: (BuildContext context, GoRouterState state) =>
                      const AppearanceSettingsScreen(),
                ),
                GoRoute(
                  path: _relative(AppRoute.accountSettings, AppRoute.settings),
                  name: AppRoute.accountSettings.routeName,
                  builder: (BuildContext context, GoRouterState state) =>
                      const AccountSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

// -----------------------------------------------------------------------------
// Full-screen routes
//
// §9: these use the **root** navigator so they cover the bottom navigation.
// Declared outside the shell for that reason — inside a branch they would render
// with the capsule still floating on top.
// -----------------------------------------------------------------------------

/// Writing your own meal.
///
/// Full-screen on the root navigator so the bottom navigation is covered: a
/// half-written recipe should not be one tap on Home away from gone. See
/// [AppSlideUpPage] for why this is not a bottom sheet.
final GoRoute _mealCreateRoute = GoRoute(
  path: AppRoute.mealCreate.path,
  name: AppRoute.mealCreate.routeName,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (BuildContext context, GoRouterState state) => AppSlideUpPage<void>(
    // A generated recipe arrives as `extra` (Sprint 48), which is why this is the
    // same route rather than a second one: what opens is the same form doing the
    // same job, with some of the fields already filled in. Null on a deep link or
    // a cold start, and a blank form is the right answer to both.
    child: MealFormScreen(
      initialDraft: state.extra is MealDraft ? state.extra as MealDraft : null,
    ),
  ),
);

/// Asking for a recipe (Sprint 48).
///
/// Beside [_mealCreateRoute] and *before* the shell for the same reason it is:
/// `/meals/invent` declared after `/meals/:id` would resolve to a meal whose id is
/// "invent". On the root navigator because it hands off to the meal form, and a
/// hand-off that starts under the bottom navigation ends under it too.
final GoRoute _mealInventRoute = GoRoute(
  path: AppRoute.inventMeal.path,
  name: AppRoute.inventMeal.routeName,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (BuildContext context, GoRouterState state) =>
      const AppSlideUpPage<void>(child: RecipeGeneratorScreen()),
);

/// Rewriting one (Sprint 26).
///
/// Beside [_mealCreateRoute] rather than nested under the meal it edits, and on
/// the same root navigator, because it is the same screen doing the same job.
/// Half-finished edits deserve the same protection from a stray tap on Home as a
/// half-written recipe, and one rule for the meal form is one thing to remember.
///
/// Three segments, so it could not collide with the shell's two-segment
/// `/meals/:id` whichever came first — but it is declared before the shell
/// anyway, next to the route whose ordering *is* load-bearing.
final GoRoute _mealEditRoute = GoRoute(
  path: AppRoute.mealEdit.path,
  name: AppRoute.mealEdit.routeName,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (BuildContext context, GoRouterState state) =>
      AppSlideUpPage<void>(
        child: MealFormScreen(mealId: state.pathParameters['id']),
      ),
);

final List<RouteBase> _fullScreenRoutes = <RouteBase>[
  // Importing a shopping list (Sprint 53). Root navigator, for the same reason
  // every other full-screen form is: its primary button must not end up behind
  // the floating bottom navigation.
  GoRoute(
    path: AppRoute.groceryImport.path,
    name: AppRoute.groceryImport.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppSlideUpPage<void>(child: GroceryImportScreen()),
  ),
  // Reading the fridge (Sprint 49). Full screen on the root navigator, like every
  // other screen whose primary button must not end up behind the floating bottom
  // navigation — the rule this app has now learned twice.
  GoRoute(
    path: AppRoute.pantryScan.path,
    name: AppRoute.pantryScan.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppSlideUpPage<void>(child: FridgeScanScreen()),
  ),
  // Asking in words (Sprint 47). Slides up on the root navigator: it is a
  // conversation that takes the screen, and its composer must not end up behind
  // the floating bottom navigation.
  GoRoute(
    path: AppRoute.assistant.path,
    name: AppRoute.assistant.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppSlideUpPage<void>(child: AssistantScreen()),
  ),
  // Eating out (Sprint 45). Full screen on the root navigator, beside the
  // roulette rather than in the navigation bar — see `AppRoute.restaurants`.
  GoRoute(
    path: AppRoute.restaurantSpin.path,
    name: AppRoute.restaurantSpin.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppScaleFadePage<void>(child: RestaurantSpinScreen()),
  ),
  GoRoute(
    path: AppRoute.restaurantResult.path,
    name: AppRoute.restaurantResult.routeName,
    parentNavigatorKey: rootNavigatorKey,
    // The scale-and-fade entry *is* the reveal, exactly as it is for meals — the
    // spin screen stops one phase short so this transition finishes the job.
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppScaleFadePage<void>(
          child: RestaurantResultScreen(
            restaurantId: state.pathParameters['id']!,
            pick: state.extra is Restaurant
                ? state.extra as Restaurant
                : null,
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.restaurants.path,
    name: AppRoute.restaurants.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppSlideUpPage<void>(child: RestaurantsScreen()),
    routes: <RouteBase>[
      GoRoute(
        path: _relative(AppRoute.restaurantCreate, AppRoute.restaurants),
        name: AppRoute.restaurantCreate.routeName,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const AppSlideUpPage<void>(child: RestaurantFormScreen()),
      ),
      GoRoute(
        path: _relative(AppRoute.restaurantEdit, AppRoute.restaurants),
        name: AppRoute.restaurantEdit.routeName,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            AppSlideUpPage<void>(
              child: RestaurantFormScreen(
                restaurantId: state.pathParameters['id'],
              ),
            ),
      ),
    ],
  ),
  GoRoute(
    path: AppRoute.roulette.path,
    name: AppRoute.roulette.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppScaleFadePage<void>(child: SpinScreen()),
  ),
  GoRoute(
    path: AppRoute.rouletteResult.path,
    name: AppRoute.rouletteResult.routeName,
    parentNavigatorKey: rootNavigatorKey,
    // The scale-and-fade entry *is* the reveal — docs/DESIGN_SYSTEM.md §7's
    // fourth phase. The spin screen deliberately stops its own animation one
    // phase short so this transition finishes the job, which is why the card
    // that lands is the card that stays.
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppScaleFadePage<void>(
          child: SpinResultScreen(
            mealId: state.pathParameters['mealId']!,
            pick: state.extra is Meal ? state.extra as Meal : null,
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.decided.path,
    name: AppRoute.decided.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppScaleFadePage<void>(
          child: DecidedScreen(
            historyId: state.pathParameters['historyId']!,
            // How many things the accepted meal put on the shopping list
            // (Sprint 43). Null on a deep link or a restart, which is the
            // difference between "we do not know" and "nothing was needed" —
            // and the screen says nothing rather than guessing.
            addedToList: state.extra is int ? state.extra as int : null,
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.cookingMode.path,
    name: AppRoute.cookingMode.routeName,
    parentNavigatorKey: rootNavigatorKey,
    builder: (BuildContext context, GoRouterState state) => PlaceholderScreen(
      title: 'Cooking mode',
      sprint: 'unscheduled',
      detail: state.pathParameters['mealId'],
    ),
  ),
];

// -----------------------------------------------------------------------------
// Couple
//
// Not a tab: a context the app operates in, not a destination (§3). Lives on the
// root navigator so it is reachable from Profile and from the Home header
// without belonging to either tab's stack.
// -----------------------------------------------------------------------------

final List<RouteBase> _coupleRoutes = <RouteBase>[
  _route(AppRoute.couple, null, sprint: 'Sprint 43'),
  _route(AppRoute.householdSetup, null, sprint: 'Sprint 41'),
  _route(AppRoute.householdCreate, null, sprint: 'Sprint 41'),
  _route(AppRoute.householdJoin, null, sprint: 'Sprint 42'),
  _route(AppRoute.householdInvite, null, sprint: 'Sprint 42'),
  _route(AppRoute.cantAgree, null, sprint: 'Sprint 45 (P1)'),
  _route(AppRoute.cantAgreeResult, null, sprint: 'Sprint 45 (P1)'),
];

// -----------------------------------------------------------------------------
// Planner — v1.3
//
// Registered so the paths are fixed and deep links resolve, but not a tab.
// -----------------------------------------------------------------------------

final List<RouteBase> _plannerRoutes = <RouteBase>[
  _route(AppRoute.planner, null, sprint: 'Sprint 54 (v1.3)'),
  _route(AppRoute.plannerDay, null, sprint: 'Sprint 55 (v1.3)'),
  _route(AppRoute.plannerGenerate, null, sprint: 'Sprint 56 (v1.3)'),
];

final GoRoute _errorRoute = GoRoute(
  path: AppRoute.error.path,
  name: AppRoute.error.routeName,
  builder: (BuildContext context, GoRouterState state) => Scaffold(
    body: ErrorState(
      onRetry: () => context.goNamed(AppRoute.home.routeName),
      retryLabel: 'Go home',
    ),
  ),
);

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

/// A top-level route, with [screen] or a placeholder naming its [sprint].
GoRoute _route(AppRoute route, Widget? screen, {required String sprint}) {
  final String title = _titleFor(route);

  return GoRoute(
    path: route.path,
    name: route.routeName,
    builder: (BuildContext context, GoRouterState state) =>
        screen ?? PlaceholderScreen(title: title, sprint: sprint),
  );
}

/// A child route whose path is derived from its parent's.
GoRoute _child(
  AppRoute route,
  AppRoute parent,
  String title, {
  required String sprint,
}) {
  return GoRoute(
    path: _relative(route, parent),
    name: route.routeName,
    builder: (BuildContext context, GoRouterState state) =>
        PlaceholderScreen(title: title, sprint: sprint),
  );
}

/// [route]'s path relative to [parent]'s.
///
/// GoRouter requires child paths to be relative while [AppRoute] stores full
/// paths — deriving one from the other means the two cannot disagree, which they
/// silently would if each child repeated its own segment as a literal.
String _relative(AppRoute route, AppRoute parent) {
  assert(
    route.path.startsWith('${parent.path}/'),
    '${route.name} is not nested under ${parent.name}',
  );
  return route.path.substring(parent.path.length + 1);
}

/// A readable title from a route name — `householdSetup` becomes
/// "Household setup". Placeholder-only; real screens carry their own copy.
String _titleFor(AppRoute route) {
  final String spaced = route.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (Match match) => ' ${match[0]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Bridges Riverpod's session state to GoRouter's [Listenable] refresh.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(this._ref) {
    _subscription = _ref.listen<AppSession>(sessionProvider, (
      AppSession? previous,
      AppSession next,
    ) {
      if (previous != next) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AppSession> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Shown while the session is being restored.
///
/// docs/NAVIGATION_MAP.md §2: "Session restore. Never a branded delay." So this
/// is a plain background with a small indicator, not a logo animation — it
/// should be invisible on a warm start.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

/// The 404 (§2).
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ErrorState(
        kind: ErrorStateKind.notFound,
        retryLabel: isAuthenticated ? 'Go home' : 'Go back',
        onRetry: () => context.goNamed(
          isAuthenticated
              ? AppRoute.home.routeName
              : AppRoute.welcome.routeName,
        ),
      ),
    );
  }
}
