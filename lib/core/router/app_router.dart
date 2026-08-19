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
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';

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
  _route(AppRoute.welcome, null, sprint: 'Sprint 16'),
  _route(AppRoute.login, null, sprint: 'Sprint 16'),
  _route(AppRoute.register, null, sprint: 'Sprint 16'),
  _route(AppRoute.forgotPassword, null, sprint: 'Sprint 16'),
  _route(AppRoute.resetPassword, null, sprint: 'Sprint 16'),
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
        const PlaceholderScreen(title: 'Onboarding', sprint: 'Sprint 18'),
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
              const AppInstantPage<void>(
                child: PlaceholderScreen(title: 'Home', sprint: 'Sprint 28'),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.rouletteFilters, AppRoute.home),
              name: AppRoute.rouletteFilters.routeName,
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  const AppSheetPage<void>(
                    child: PlaceholderScreen(
                      title: 'Roulette filters',
                      sprint: 'Sprint 30',
                    ),
                  ),
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
              const AppInstantPage<void>(
                child: PlaceholderScreen(title: 'Meals', sprint: 'Sprint 22'),
              ),
          // Literal segments are declared before `:id`, because GoRouter matches
          // in declaration order — with `:id` first, `/meals/search` would
          // resolve to a meal whose id is "search".
          routes: <RouteBase>[
            _child(
              AppRoute.mealSearch,
              AppRoute.meals,
              'Search meals',
              sprint: 'Sprint 22',
            ),
            _child(
              AppRoute.favorites,
              AppRoute.meals,
              'Favourites',
              sprint: 'Sprint 24',
            ),
            _child(
              AppRoute.mealHistory,
              AppRoute.meals,
              'Meal history',
              sprint: 'Sprint 31',
            ),
            _child(
              AppRoute.myMeals,
              AppRoute.meals,
              'My meals',
              sprint: 'Sprint 26',
            ),
            _child(
              AppRoute.mealCreate,
              AppRoute.meals,
              'New meal',
              sprint: 'Sprint 26',
            ),
            GoRoute(
              path: _relative(AppRoute.mealDetail, AppRoute.meals),
              name: AppRoute.mealDetail.routeName,
              builder: (BuildContext context, GoRouterState state) =>
                  PlaceholderScreen(
                    title: 'Meal detail',
                    sprint: 'Sprint 23',
                    detail: state.pathParameters['id'],
                  ),
              routes: <RouteBase>[
                GoRoute(
                  path: _relative(AppRoute.mealEdit, AppRoute.mealDetail),
                  name: AppRoute.mealEdit.routeName,
                  builder: (BuildContext context, GoRouterState state) =>
                      PlaceholderScreen(
                        title: 'Edit meal',
                        sprint: 'Sprint 26',
                        detail: state.pathParameters['id'],
                      ),
                ),
              ],
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
              const AppInstantPage<void>(
                child: PlaceholderScreen(title: 'Pantry', sprint: 'Sprint 48'),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.pantryAdd, AppRoute.pantry),
              name: AppRoute.pantryAdd.routeName,
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  const AppSheetPage<void>(
                    child: PlaceholderScreen(
                      title: 'Add ingredient',
                      sprint: 'Sprint 48',
                    ),
                  ),
            ),
            _child(
              AppRoute.ingredientMatches,
              AppRoute.pantry,
              'Ingredient matches',
              sprint: 'Sprint 50',
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
              const AppInstantPage<void>(
                child: PlaceholderScreen(
                  title: 'Grocery list',
                  sprint: 'Sprint 51',
                ),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: _relative(AppRoute.groceryAdd, AppRoute.grocery),
              name: AppRoute.groceryAdd.routeName,
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  const AppSheetPage<void>(
                    child: PlaceholderScreen(
                      title: 'Add grocery item',
                      sprint: 'Sprint 51',
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
              const AppInstantPage<void>(
                child: PlaceholderScreen(title: 'Profile', sprint: 'Sprint 20'),
              ),
          routes: <RouteBase>[
            _child(
              AppRoute.preferences,
              AppRoute.profile,
              'Preferences',
              sprint: 'Sprint 35',
            ),
            _child(
              AppRoute.budgetSettings,
              AppRoute.profile,
              'Budget',
              sprint: 'Sprint 38',
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
                _child(
                  AppRoute.appearanceSettings,
                  AppRoute.settings,
                  'Appearance',
                  sprint: 'Sprint 20',
                ),
                _child(
                  AppRoute.accountSettings,
                  AppRoute.settings,
                  'Account',
                  sprint: 'Sprint 20',
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

final List<RouteBase> _fullScreenRoutes = <RouteBase>[
  GoRoute(
    path: AppRoute.roulette.path,
    name: AppRoute.roulette.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        const AppScaleFadePage<void>(
          child: PlaceholderScreen(title: 'Spinning', sprint: 'Sprint 28'),
        ),
  ),
  GoRoute(
    path: AppRoute.rouletteResult.path,
    name: AppRoute.rouletteResult.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppScaleFadePage<void>(
          child: PlaceholderScreen(
            title: "Tonight's pick",
            sprint: 'Sprint 28',
            detail: state.pathParameters['mealId'],
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.decided.path,
    name: AppRoute.decided.routeName,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppScaleFadePage<void>(
          child: PlaceholderScreen(
            title: 'Dinner decided',
            sprint: 'Sprint 31',
            detail: state.pathParameters['historyId'],
          ),
        ),
  ),
  GoRoute(
    path: AppRoute.cookingMode.path,
    name: AppRoute.cookingMode.routeName,
    parentNavigatorKey: rootNavigatorKey,
    builder: (BuildContext context, GoRouterState state) => PlaceholderScreen(
      title: 'Cooking mode',
      sprint: 'Sprint 34 (P1)',
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
