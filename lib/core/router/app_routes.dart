/// Every route in the application (docs/NAVIGATION_MAP.md §2).
///
/// This file imports nothing. Feature code needs route *names* to navigate, and
/// the router needs feature *screens* to build — so keeping the names here,
/// separate from the router itself, is what stops that from becoming a circular
/// dependency between `core/router` and every feature.
///
/// docs/NAVIGATION_MAP.md §9: "Route names are the constants used everywhere;
/// **never navigate by raw path string**." The paths below exist for the guard,
/// for deep links, and for the test that asserts they match what GoRouter
/// actually generates — not for call sites.
library;

/// What a route requires of the visitor (docs/NAVIGATION_MAP.md §2).
enum RouteAccess {
  /// Reachable with no session at all.
  public,

  /// Reachable with no session, but only as a guest trying the app.
  guest,

  /// Requires a session. The onboarding zone.
  authenticated,

  /// Requires a session *and* completed onboarding. The application shell.
  onboarded,
}

/// The application's routes.
///
/// An enum rather than a wall of string constants: the guard in
/// `router_guards.dart` switches on [access] and [requiresHousehold], so the
/// rules and the routes cannot drift apart. Adding a route without deciding its
/// access level is not expressible.
enum AppRoute {
  // ---------------------------------------------------------------------------
  // Public
  // ---------------------------------------------------------------------------

  /// Session restore. Never a branded delay.
  splash(path: '/splash', access: RouteAccess.public),

  /// Sign up · Log in · Try it first.
  welcome(path: '/welcome', access: RouteAccess.public),

  /// Accepts `?redirect=` as the post-login destination.
  login(path: '/login', access: RouteAccess.public),

  register(path: '/register', access: RouteAccess.public),
  forgotPassword(path: '/forgot-password', access: RouteAccess.public),

  /// Deep-link target; requires a `token` query parameter.
  resetPassword(path: '/reset-password', access: RouteAccess.public),

  /// Limited spins, no persistence (P1).
  guestSpin(path: '/guest-spin', access: RouteAccess.guest),

  // ---------------------------------------------------------------------------
  // Onboarding
  //
  // One route with internal paging, not one route per step, so a mid-flow back
  // gesture cannot strand someone between partially-saved steps.
  // ---------------------------------------------------------------------------

  onboarding(path: '/onboarding', access: RouteAccess.authenticated),
  onboardingHousehold(
    path: '/onboarding/household',
    access: RouteAccess.authenticated,
  ),

  // ---------------------------------------------------------------------------
  // Home tab
  // ---------------------------------------------------------------------------

  /// The default tab.
  home(path: '/home'),

  /// Bottom sheet.
  rouletteFilters(path: '/home/filters', isSheet: true),

  /// Full-screen: the spin takes over, bottom navigation included.
  roulette(path: '/home/spin', isFullScreen: true),
  rouletteResult(path: '/home/result/:mealId', isFullScreen: true),

  /// Post-acceptance celebration.
  decided(path: '/home/decided/:historyId', isFullScreen: true),

  /// Keeps the screen awake (P1).
  cookingMode(path: '/home/cooking/:mealId', isFullScreen: true),

  // ---------------------------------------------------------------------------
  // Meals tab
  // ---------------------------------------------------------------------------

  meals(path: '/meals'),
  mealSearch(path: '/meals/search'),
  favorites(path: '/meals/favorites'),

  /// Meals the user has hidden (Sprint 25). Not in docs/NAVIGATION_MAP.md's
  /// original table — the map predates the sprint, and the exclusion needs a
  /// place where it can be undone.
  dislikedMeals(path: '/meals/disliked'),
  mealHistory(path: '/meals/history'),
  myMeals(path: '/meals/mine'),
  mealCreate(path: '/meals/new'),

  /// Asking the assistant to write one (Sprint 48).
  ///
  /// Under `/meals` rather than under `/ask`, because what it produces is a meal
  /// and where it lands is the library. The chat is a different feature that
  /// happens to use the same provider.
  inventMeal(path: '/meals/invent'),

  /// Hero transition from any card.
  mealDetail(path: '/meals/:id'),

  /// Custom meals only.
  mealEdit(path: '/meals/:id/edit'),

  // ---------------------------------------------------------------------------
  // Pantry tab
  // ---------------------------------------------------------------------------

  pantry(path: '/pantry'),
  pantryAdd(path: '/pantry/add', isSheet: true),

  /// Reading a photo of the fridge (Sprint 49).
  ///
  /// Under `/pantry` because what it produces is pantry items, and because the
  /// only place it makes sense to reach for is standing in front of the fridge
  /// with the kitchen list open.
  pantryScan(path: '/pantry/scan'),

  /// What cooking a meal took out of the kitchen (Sprint 54).
  ///
  /// Reached from the decided screen with the meal's name as `extra`, and a sheet
  /// rather than a page: it is a confirmation about something that just happened,
  /// not a place to be.
  pantryUsed(path: '/pantry/used/:mealId', isSheet: true),

  /// Ranked by match percentage.
  ingredientMatches(path: '/pantry/matches'),

  // ---------------------------------------------------------------------------
  // Grocery tab
  // ---------------------------------------------------------------------------

  grocery(path: '/grocery'),
  groceryAdd(path: '/grocery/add', isSheet: true),

  /// Reading a shopping list out of a file (Sprint 53).
  groceryImport(path: '/grocery/import'),

  // ---------------------------------------------------------------------------
  // Eating out (Sprint 45)
  //
  // Full-screen on the root navigator rather than a sixth tab. Eating out is the
  // *other* answer to the question the roulette asks, so it belongs beside it —
  // and a navigation bar with six destinations is a navigation bar nobody reads.
  // ---------------------------------------------------------------------------

  restaurants(path: '/eat-out'),
  restaurantCreate(path: '/eat-out/new'),
  restaurantEdit(path: '/eat-out/:id/edit'),

  /// The night-out roulette (Sprint 46).
  ///
  /// A sibling of [roulette] rather than a child of [restaurants], because it is
  /// the same *kind* of thing as the meal spin — a full-screen decision that
  /// takes over — and nesting it under the list would make going back land on a
  /// list nobody asked to see.
  restaurantSpin(path: '/eat-out/spin'),
  restaurantResult(path: '/eat-out/spin/:id'),

  // ---------------------------------------------------------------------------
  // AI (Sprint 47)
  //
  // One route, not a tab. The assistant is a way of asking the question Home
  // already asks, not a sixth place to be — and a chat given a permanent slot in
  // the navigation bar is a chat the app is pretending is the main event.
  // ---------------------------------------------------------------------------

  assistant(path: '/ask'),

  // ---------------------------------------------------------------------------
  // Profile tab
  // ---------------------------------------------------------------------------

  profile(path: '/profile'),
  preferences(path: '/profile/preferences'),
  budgetSettings(path: '/profile/budget'),

  /// P1.
  statistics(path: '/profile/statistics'),

  settings(path: '/profile/settings'),

  /// P2.
  notificationSettings(path: '/profile/settings/notifications'),

  appearanceSettings(path: '/profile/settings/appearance'),

  /// Includes account deletion.
  accountSettings(path: '/profile/settings/account'),

  // ---------------------------------------------------------------------------
  // Couple
  //
  // Deliberately not a tab: it is a *context* the whole app operates in, not a
  // destination (docs/NAVIGATION_MAP.md §3). Reached from Profile and from the
  // household indicator in the Home header.
  // ---------------------------------------------------------------------------

  couple(path: '/couple', requiresHousehold: true),

  /// Create or join. Must not require a household, or joining is unreachable.
  householdSetup(path: '/couple/setup'),
  householdCreate(path: '/couple/create'),

  /// Accepts `?code=`.
  householdJoin(path: '/couple/join'),

  householdInvite(path: '/couple/invite', requiresHousehold: true),

  /// P1/T2.
  cantAgree(path: '/couple/vote', requiresHousehold: true),
  cantAgreeResult(path: '/couple/vote/result', requiresHousehold: true),

  // ---------------------------------------------------------------------------
  // Planner — v1.3, not in MVP
  //
  // Registered so the paths are fixed and deep links resolve, but not a tab:
  // five slots are already full (§3).
  // ---------------------------------------------------------------------------

  planner(path: '/planner'),
  plannerDay(path: '/planner/day/:date'),
  plannerGenerate(path: '/planner/generate'),

  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  /// An unrecoverable failure, with a route home.
  error(path: '/error', access: RouteAccess.public);

  const AppRoute({
    required this.path,
    this.access = RouteAccess.onboarded,
    this.requiresHousehold = false,
    this.isFullScreen = false,
    this.isSheet = false,
  });

  /// The full path. Used by the guard, by deep links and by tests — never as a
  /// navigation argument.
  final String path;

  final RouteAccess access;

  /// Whether the route needs an active household beyond being onboarded.
  ///
  /// A route that *creates* a household must never set this, or the redirect
  /// loops (§4).
  final bool requiresHousehold;

  /// Whether the route covers the bottom navigation, and so must be pushed onto
  /// the root navigator rather than a shell branch (§9).
  final bool isFullScreen;

  /// Whether the route presents as a bottom sheet.
  ///
  /// Sheets are routes rather than imperative `showModalBottomSheet` calls so
  /// they are deep-linkable and survive configuration changes (§9).
  final bool isSheet;

  /// The name used by `goNamed` and `pushNamed`.
  ///
  /// Derived from the enum member so a route can never be registered under one
  /// name and navigated to by another.
  String get routeName => name;

  /// Whether a visitor with no session may see this route.
  bool get allowsNoSession =>
      access == RouteAccess.public || access == RouteAccess.guest;

  /// Whether this route belongs to the onboarding zone.
  bool get isOnboardingZone => access == RouteAccess.authenticated;
}
