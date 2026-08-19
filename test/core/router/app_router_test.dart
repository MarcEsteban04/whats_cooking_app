import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/router/app_router.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/router/app_shell.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/navigation/app_bottom_nav.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/auth/presentation/screens/welcome_screen.dart';

/// Sample values for every path parameter in the route table.
const Map<String, String> _sampleParameters = <String, String>{
  'mealId': 'meal-1',
  'historyId': 'history-1',
  'id': 'meal-1',
  'date': '2026-08-20',
};

void main() {
  /// A container with a signed-in, onboarded session so shell routes are
  /// reachable without going through screens that do not exist yet.
  ProviderContainer onboardedContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .signIn(isOnboarded: true, hasHousehold: true);
    return container;
  }

  Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A tab label inside the navigation bar.
  ///
  /// Scoped, because a tab and the screen it opens share a name — an unscoped
  /// search for "Home" matches both the tab and the Home screen's own title.
  Finder tab(String label) => find.descendant(
    of: find.byType(AppBottomNav),
    matching: find.text(label),
  );

  group('the registered paths match the route table', () {
    // AppRoute stores full paths while GoRouter is declared with relative child
    // paths. The two can drift silently, which would leave a deep link pointing
    // at nothing while every in-app `goNamed` still worked. Asserting that
    // GoRouter generates exactly the documented path for every name closes that
    // gap.
    test('every route name resolves to its documented path', () {
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);

      for (final AppRoute route in AppRoute.values) {
        final Map<String, String> parameters = <String, String>{
          for (final String key in _parametersOf(route.path))
            key: _sampleParameters[key]!,
        };

        final String generated = router.namedLocation(
          route.routeName,
          pathParameters: parameters,
        );

        expect(
          generated,
          _expand(route.path, parameters),
          reason: '${route.name} is registered at a different path',
        );
      }
    });

    test('every route in the table has a sample for each parameter', () {
      // Guards the test above: a new `:parameter` with no sample would make the
      // loop throw rather than fail informatively.
      for (final AppRoute route in AppRoute.values) {
        for (final String parameter in _parametersOf(route.path)) {
          expect(
            _sampleParameters,
            contains(parameter),
            reason: 'add a sample value for :$parameter (${route.name})',
          );
        }
      }
    });
  });

  group('the shell', () {
    testWidgets('shows five tabs', (WidgetTester tester) async {
      final ProviderContainer container = onboardedContainer();
      await pumpApp(tester, container);

      container.read(appRouterProvider).goNamed(AppRoute.home.routeName);
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
      for (final AppTab navTab in AppTab.values) {
        expect(tab(navTab.label), findsOneWidget, reason: navTab.label);
      }
    });

    testWidgets('tapping a tab switches to it', (WidgetTester tester) async {
      final ProviderContainer container = onboardedContainer();
      await pumpApp(tester, container);

      container.read(appRouterProvider).goNamed(AppRoute.home.routeName);
      await tester.pumpAndSettle();
      expect(find.textContaining('Arrives in Sprint 28'), findsOneWidget);

      await tester.tap(tab('Pantry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Arrives in Sprint 48'), findsOneWidget);
    });

    testWidgets('each tab keeps its own stack across a switch', (
      WidgetTester tester,
    ) async {
      // docs/NAVIGATION_MAP.md §8: switching tabs preserves depth. The indexed
      // stack is what makes that true, and it is the reason a tab is not simply
      // rebuilt on selection.
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);
      await pumpApp(tester, container);

      router.goNamed(AppRoute.favorites.routeName);
      await tester.pumpAndSettle();
      expect(find.text('Favourites'), findsOneWidget);

      await tester.tap(tab('Grocery'));
      await tester.pumpAndSettle();
      expect(find.text('Favourites'), findsNothing);

      await tester.tap(tab('Meals'));
      await tester.pumpAndSettle();
      expect(
        find.text('Favourites'),
        findsOneWidget,
        reason: 'the Meals tab should still be showing where it was left',
      );
    });

    testWidgets('re-tapping the active tab pops it to its root', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);
      await pumpApp(tester, container);

      router.goNamed(AppRoute.favorites.routeName);
      await tester.pumpAndSettle();
      expect(find.text('Favourites'), findsOneWidget);

      await tester.tap(tab('Meals'));
      await tester.pumpAndSettle();

      expect(
        find.text('Favourites'),
        findsNothing,
        reason: 'the active tab should have returned to its root',
      );
    });
  });

  group('full-screen routes cover the navigation', () {
    testWidgets('the spin hides the bottom nav', (WidgetTester tester) async {
      // §9: full-screen routes use the root navigator. Rendered inside a branch
      // instead, the floating capsule would stay on top of the spin.
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);
      await pumpApp(tester, container);

      router.goNamed(AppRoute.home.routeName);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNav), findsOneWidget);

      router.goNamed(AppRoute.roulette.routeName);
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.text('Spinning'), findsOneWidget);
    });

    testWidgets('the result screen receives its path parameter', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);
      await pumpApp(tester, container);

      router.goNamed(
        AppRoute.rouletteResult.routeName,
        pathParameters: <String, String>{'mealId': 'chicken-katsu'},
      );
      await tester.pumpAndSettle();

      expect(find.text('chicken-katsu'), findsOneWidget);
    });
  });

  group('sheets are routes', () {
    testWidgets('a sheet route presents as a modal sheet', (
      WidgetTester tester,
    ) async {
      // §9: sheets are routes, not imperative showModalBottomSheet calls, so
      // they are deep-linkable and survive configuration changes.
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);
      await pumpApp(tester, container);

      router.goNamed(AppRoute.rouletteFilters.routeName);
      await tester.pumpAndSettle();

      expect(find.text('Roulette filters'), findsOneWidget);
      expect(
        find.byType(BottomSheet),
        findsOneWidget,
        reason: 'a real sheet, so drag-to-dismiss and the scrim come for free',
      );
    });
  });

  group('the guard runs inside the router', () {
    testWidgets('a signed-out cold start lands on Welcome', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await pumpApp(tester, container);

      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('a protected route is refused while signed out', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final GoRouter router = container.read(appRouterProvider);

      await pumpApp(tester, container);
      router.goNamed(AppRoute.meals.routeName);
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('signing in moves the app off the public zone', (
      WidgetTester tester,
    ) async {
      // The refreshListenable path: a session change has to re-run the redirect
      // without the router being rebuilt, or the user stays on Welcome after a
      // successful login.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await pumpApp(tester, container);
      expect(find.byType(WelcomeScreen), findsOneWidget);

      container
          .read(sessionProvider.notifier)
          .signIn(isOnboarded: true, hasHousehold: true);
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('an unonboarded session is held in the onboarding zone', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .signIn(isOnboarded: false, hasHousehold: true);

      await pumpApp(tester, container);

      expect(find.text('Onboarding'), findsOneWidget);

      container.read(sessionProvider.notifier).completeOnboarding();
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('a household route redirects to setup when there is none', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .signIn(isOnboarded: true, hasHousehold: false);
      final GoRouter router = container.read(appRouterProvider);

      await pumpApp(tester, container);
      router.goNamed(AppRoute.couple.routeName);
      await tester.pumpAndSettle();

      expect(find.text('Household setup'), findsOneWidget);
    });

    testWidgets('signing out returns to the public zone', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = onboardedContainer();
      await pumpApp(tester, container);
      expect(find.byType(AppShell), findsOneWidget);

      container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('unknown paths', () {
    testWidgets('render the not-found state rather than redirecting', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);

      await pumpApp(tester, container);
      router.go('/this-does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text("We couldn't find that"), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);
    });

    testWidgets('offer a way back that works', (WidgetTester tester) async {
      final ProviderContainer container = onboardedContainer();
      final GoRouter router = container.read(appRouterProvider);

      await pumpApp(tester, container);
      router.go('/this-does-not-exist');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go home'));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });
  });
}

/// The `:parameter` names in [path].
List<String> _parametersOf(String path) => path
    .split('/')
    .where((String segment) => segment.startsWith(':'))
    .map((String segment) => segment.substring(1))
    .toList();

/// [path] with its `:parameter` segments substituted.
String _expand(String path, Map<String, String> parameters) {
  String expanded = path;
  parameters.forEach((String key, String value) {
    expanded = expanded.replaceAll(':$key', value);
  });
  return expanded;
}
