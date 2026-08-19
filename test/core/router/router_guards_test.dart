import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/router/router_guards.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';

/// docs/NAVIGATION_MAP.md §4, branch by branch.
///
/// The guard is the app's only auth check, so a hole in it is a hole in the
/// whole app. It is a pure function precisely so the entire decision tree can be
/// covered here rather than sampled through a widget test.
void main() {
  const AppSession restoring = AppSession.restoring();
  const AppSession signedOut = AppSession.signedOut();
  const AppSession notOnboarded = AppSession.signedIn(
    isOnboarded: false,
    hasHousehold: false,
  );
  const AppSession onboarded = AppSession.signedIn(
    isOnboarded: true,
    hasHousehold: true,
  );
  const AppSession noHousehold = AppSession.signedIn(
    isOnboarded: true,
    hasHousehold: false,
  );

  String? redirectFor(String location, AppSession session) =>
      RouterGuard.redirect(location: location, session: session);

  group('while the session is restoring', () {
    test('everything waits on splash', () {
      // A cold start that renders Welcome for a few frames shows a returning
      // user a sign-in prompt they do not need.
      expect(redirectFor(AppRoute.home.path, restoring), AppRoute.splash.path);
      expect(
        redirectFor(AppRoute.welcome.path, restoring),
        AppRoute.splash.path,
      );
      expect(redirectFor(AppRoute.meals.path, restoring), AppRoute.splash.path);
    });

    test('splash itself is allowed', () {
      expect(redirectFor(AppRoute.splash.path, restoring), isNull);
    });
  });

  group('signed out', () {
    test('public routes are allowed', () {
      for (final AppRoute route in AppRoute.values.where(
        (AppRoute route) =>
            route.access == RouteAccess.public && route != AppRoute.splash,
      )) {
        expect(
          redirectFor(route.path, signedOut),
          isNull,
          reason: '${route.name} is public',
        );
      }
    });

    test('the guest route is allowed', () {
      expect(redirectFor(AppRoute.guestSpin.path, signedOut), isNull);
    });

    test('splash moves on rather than sitting there', () {
      expect(
        redirectFor(AppRoute.splash.path, signedOut),
        AppRoute.welcome.path,
      );
    });

    test('a protected route redirects to welcome', () {
      final String? redirect = redirectFor(AppRoute.home.path, signedOut);

      expect(redirect, isNotNull);
      expect(Uri.parse(redirect!).path, AppRoute.welcome.path);
    });

    test('the intended destination is preserved', () {
      // §4: "A redirect always preserves the intended destination, so
      // post-login the user lands where they were going — never on Home by
      // default."
      final String? redirect = redirectFor('/meals/abc-123', signedOut);

      expect(RouterGuard.intendedDestination(redirect!), '/meals/abc-123');
    });

    test('a query string in the destination survives the round trip', () {
      final String? redirect = redirectFor(
        '/couple/join?code=ABC123',
        signedOut,
      );

      expect(
        RouterGuard.intendedDestination(redirect!),
        '/couple/join?code=ABC123',
        reason: 'the invite code is the whole point of the link',
      );
    });

    test('the reset-password deep link opens directly', () {
      // §5: "Opens directly — the whole point." A password reset that demands a
      // sign-in first is unusable.
      expect(
        redirectFor('${AppRoute.resetPassword.path}?token=abc', signedOut),
        isNull,
      );
    });
  });

  group('signed in but not onboarded', () {
    test('the onboarding zone is allowed', () {
      expect(redirectFor(AppRoute.onboarding.path, notOnboarded), isNull);
      expect(
        redirectFor(AppRoute.onboardingHousehold.path, notOnboarded),
        isNull,
      );
    });

    test('everything else goes to onboarding', () {
      expect(
        redirectFor(AppRoute.home.path, notOnboarded),
        AppRoute.onboarding.path,
      );
      expect(
        redirectFor(AppRoute.meals.path, notOnboarded),
        AppRoute.onboarding.path,
      );
      expect(
        redirectFor(AppRoute.welcome.path, notOnboarded),
        AppRoute.onboarding.path,
      );
    });
  });

  group('signed in and onboarded', () {
    test('shell routes are allowed', () {
      for (final AppRoute route in <AppRoute>[
        AppRoute.home,
        AppRoute.meals,
        AppRoute.pantry,
        AppRoute.grocery,
        AppRoute.profile,
      ]) {
        expect(redirectFor(route.path, onboarded), isNull);
      }
    });

    test('a public route redirects home', () {
      // §4: "Reaching the login screen while logged in is a bug, not a feature."
      expect(redirectFor(AppRoute.login.path, onboarded), AppRoute.home.path);
      expect(redirectFor(AppRoute.welcome.path, onboarded), AppRoute.home.path);
      expect(
        redirectFor(AppRoute.register.path, onboarded),
        AppRoute.home.path,
      );
    });

    test('onboarding redirects home once complete', () {
      expect(
        redirectFor(AppRoute.onboarding.path, onboarded),
        AppRoute.home.path,
      );
    });

    test('reset-password stays reachable with a live session', () {
      // Changing a password while signed in is the normal case, so this is the
      // one public route that is not bounced.
      expect(
        redirectFor('${AppRoute.resetPassword.path}?token=abc', onboarded),
        isNull,
      );
    });

    test('a path parameter route resolves', () {
      expect(redirectFor('/meals/some-meal-id', onboarded), isNull);
      expect(redirectFor('/home/result/some-meal-id', onboarded), isNull);
    });
  });

  group('household requirement', () {
    test('household routes redirect to setup when there is none', () {
      for (final AppRoute route in AppRoute.values.where(
        (AppRoute route) => route.requiresHousehold,
      )) {
        expect(
          redirectFor(route.path, noHousehold),
          AppRoute.householdSetup.path,
          reason: '${route.name} needs a household',
        );
      }
    });

    test('the routes that create a household never require one', () {
      // The loop this prevents: /couple/setup requiring a household would make
      // creating one unreachable.
      for (final AppRoute route in <AppRoute>[
        AppRoute.householdSetup,
        AppRoute.householdCreate,
        AppRoute.householdJoin,
      ]) {
        expect(
          route.requiresHousehold,
          isFalse,
          reason: '${route.name} must be reachable without a household',
        );
        expect(redirectFor(route.path, noHousehold), isNull);
      }
    });

    test('household routes are allowed once there is one', () {
      expect(redirectFor(AppRoute.couple.path, onboarded), isNull);
      expect(redirectFor(AppRoute.householdInvite.path, onboarded), isNull);
    });
  });

  group('no redirect ever loops', () {
    // The property that matters most: whatever the guard returns must itself be
    // allowed, or the router bounces forever and the app hangs on a white
    // screen. Checked for every route against every session shape.
    final Map<String, AppSession> sessions = <String, AppSession>{
      'restoring': restoring,
      'signed out': signedOut,
      'not onboarded': notOnboarded,
      'no household': noHousehold,
      'onboarded': onboarded,
    };

    for (final MapEntry<String, AppSession> entry in sessions.entries) {
      test('for a ${entry.key} session', () {
        for (final AppRoute route in AppRoute.values) {
          String location = route.path;

          // Follow the chain; it must settle within a couple of hops.
          for (int hop = 0; hop < 5; hop++) {
            final String? next = redirectFor(location, entry.value);
            if (next == null) {
              break;
            }
            expect(
              next,
              isNot(location),
              reason: '${route.name} redirects to itself',
            );
            location = next;
            expect(
              hop,
              lessThan(4),
              reason: '${route.name} did not settle for a ${entry.key} session',
            );
          }
        }
      });
    }
  });

  group('routeFor', () {
    test('matches literal segments before path parameters', () {
      // The ordering trap: with `:id` checked first, /meals/search resolves to
      // a meal whose id is "search".
      expect(RouterGuard.routeFor('/meals/search'), AppRoute.mealSearch);
      expect(RouterGuard.routeFor('/meals/favorites'), AppRoute.favorites);
      expect(RouterGuard.routeFor('/meals/mine'), AppRoute.myMeals);
      expect(RouterGuard.routeFor('/meals/abc-123'), AppRoute.mealDetail);
    });

    test('matches nested parameter routes', () {
      expect(RouterGuard.routeFor('/meals/abc/edit'), AppRoute.mealEdit);
      expect(RouterGuard.routeFor('/home/decided/hist-1'), AppRoute.decided);
      expect(
        RouterGuard.routeFor('/profile/settings/account'),
        AppRoute.accountSettings,
      );
    });

    test('ignores the query string', () {
      expect(
        RouterGuard.routeFor('/couple/join?code=ABC'),
        AppRoute.householdJoin,
      );
    });

    test('returns null for an unknown path', () {
      expect(RouterGuard.routeFor('/nonsense'), isNull);
      expect(RouterGuard.routeFor('/meals/abc/nonsense'), isNull);
    });

    test('an unknown path is left to the 404 rather than redirected', () {
      // Absorbing it into a redirect would hide broken links instead of
      // surfacing them.
      expect(redirectFor('/nonsense', onboarded), isNull);
    });
  });

  group('intendedDestination', () {
    test('reads an in-app path', () {
      expect(
        RouterGuard.intendedDestination('/welcome?redirect=/meals/abc'),
        '/meals/abc',
      );
    });

    test('is null when absent', () {
      expect(RouterGuard.intendedDestination('/welcome'), isNull);
      expect(RouterGuard.intendedDestination('/welcome?redirect='), isNull);
    });

    test('refuses an absolute URL', () {
      // A crafted deep link would otherwise use the app to bounce someone to an
      // external site immediately after they sign in.
      expect(
        RouterGuard.intendedDestination(
          '/welcome?redirect=https://evil.example.com',
        ),
        isNull,
      );
      expect(
        RouterGuard.intendedDestination('/welcome?redirect=//evil.example.com'),
        isNull,
      );
    });
  });

  group('route table integrity', () {
    test('every path is unique', () {
      final Set<String> paths = AppRoute.values
          .map((AppRoute route) => route.path)
          .toSet();

      expect(paths, hasLength(AppRoute.values.length));
    });

    test('every path is absolute', () {
      for (final AppRoute route in AppRoute.values) {
        expect(route.path, startsWith('/'), reason: route.name);
      }
    });

    test('full-screen routes and sheets are disjoint', () {
      for (final AppRoute route in AppRoute.values) {
        expect(
          route.isFullScreen && route.isSheet,
          isFalse,
          reason: '${route.name} cannot be both',
        );
      }
    });

    test('only onboarded routes can require a household', () {
      for (final AppRoute route in AppRoute.values.where(
        (AppRoute route) => route.requiresHousehold,
      )) {
        expect(route.access, RouteAccess.onboarded, reason: route.name);
      }
    });
  });
}
