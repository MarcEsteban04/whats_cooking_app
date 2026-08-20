import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';

/// The route guard from docs/NAVIGATION_MAP.md §4.
///
/// A **pure function** of (location, session) rather than a closure inside the
/// router. §4 is a decision tree with nine branches and two of them loop if you
/// get them wrong; expressing it as a function means the whole tree is unit
/// tested in milliseconds, with no widget tree, no navigator and no Supabase.
///
/// docs/NAVIGATION_MAP.md §4: "Guards are declarative in the router. No screen
/// performs its own auth check — one place to reason about, one place to get
/// wrong." This is that one place.
abstract final class RouterGuard {
  /// The query parameter that carries an interrupted destination.
  static const String redirectParam = 'redirect';

  /// Where [location] should go given [session], or null to allow it.
  ///
  /// [location] is a full location including any query string, as GoRouter
  /// reports it.
  static String? redirect({
    required String location,
    required AppSession session,
  }) {
    final AppRoute? route = routeFor(location);

    // An unrecognised path is handled by the not-found route rather than the
    // guard: redirecting it here would swallow the 404 and silently land the
    // user on Home, which hides broken links instead of surfacing them.
    if (route == null) {
      return null;
    }

    return switch (session.status) {
      SessionStatus.restoring => _whileRestoring(route),
      SessionStatus.unauthenticated => _whenSignedOut(route, location),
      SessionStatus.authenticated => _whenSignedIn(route, session, location),
    };
  }

  /// Holds everything on the splash screen until the session is known.
  ///
  /// Without this, a cold start renders the welcome screen for the few frames it
  /// takes to read secure storage, and a returning user sees a sign-in prompt
  /// they do not need.
  static String? _whileRestoring(AppRoute route) {
    return route == AppRoute.splash ? null : AppRoute.splash.path;
  }

  static String? _whenSignedOut(AppRoute route, String location) {
    if (route.allowsNoSession) {
      // Splash has nothing left to restore, so it moves on rather than sitting
      // there as a dead end.
      return route == AppRoute.splash ? AppRoute.welcome.path : null;
    }

    // §4: "A redirect always preserves the intended destination, so post-login
    // the user lands where they were going — never on Home by default."
    return Uri(
      path: AppRoute.welcome.path,
      queryParameters: <String, String>{redirectParam: location},
    ).toString();
  }

  static String? _whenSignedIn(
    AppRoute route,
    AppSession session,
    String location,
  ) {
    // Checked first, and it has to be. A password-reset link signs the user in
    // before they choose a new password, so every rule below would happily send
    // them to Home — leaving them with a live session, a half-finished reset and
    // no way back to the form. Nothing but the reset screen is reachable until
    // the new password is set or the session is dropped.
    if (session.isRecoveringPassword) {
      return route == AppRoute.resetPassword
          ? null
          : AppRoute.resetPassword.path;
    }

    if (!session.isOnboarded) {
      return route.isOnboardingZone ? null : AppRoute.onboarding.path;
    }

    // §4: "An authenticated user hitting a public route is redirected to /home.
    // Reaching the login screen while logged in is a bug, not a feature." The
    // reset-password deep link is the one exception — arriving at it with a live
    // session is exactly how a password change happens.
    if (route.allowsNoSession || route.isOnboardingZone) {
      if (route == AppRoute.resetPassword) {
        return null;
      }

      // §18: "The user is returned to where they were after re-authenticating.
      // Never dump them on Home." The destination was preserved on the way in by
      // [_whenSignedOut]; this is where it is spent. Without this half, the
      // parameter is written and never read, and a user who followed a link to a
      // meal lands on Home having lost it.
      return intendedDestination(location) ?? AppRoute.home.path;
    }

    if (route.requiresHousehold && !session.hasHousehold) {
      return AppRoute.householdSetup.path;
    }

    return null;
  }

  /// The [AppRoute] matching [location], or null when nothing matches.
  ///
  /// Specificity order, most specific first:
  ///
  /// 1. More path segments, so `/meals/abc/edit` beats `/meals/:id`.
  /// 2. Fewer path parameters, so `/meals/search` resolves to `mealSearch`
  ///    rather than to a meal whose id happens to be "search" — the same
  ///    ordering trap the router itself has to avoid.
  /// 3. Declaration order, purely so the result is deterministic.
  ///
  /// That third tiebreak is not decoration: `List.sort` is not a stable sort in
  /// Dart, so without an explicit final comparison two equally specific routes
  /// resolve differently depending on list length.
  static AppRoute? routeFor(String location) {
    final String path = Uri.parse(location).path;

    final List<AppRoute> candidates = AppRoute.values.toList()
      ..sort((AppRoute a, AppRoute b) {
        final int bySegments = _segments(b.path).length
            .compareTo(_segments(a.path).length);
        if (bySegments != 0) {
          return bySegments;
        }

        final int byParameters = _parameterCount(a.path)
            .compareTo(_parameterCount(b.path));
        if (byParameters != 0) {
          return byParameters;
        }

        return a.index.compareTo(b.index);
      });

    for (final AppRoute route in candidates) {
      if (_matches(route.path, path)) {
        return route;
      }
    }
    return null;
  }

  static int _parameterCount(String path) =>
      _segments(path).where((String segment) => segment.startsWith(':')).length;

  /// Whether [path] matches [pattern], treating `:segment` as a wildcard.
  static bool _matches(String pattern, String path) {
    final List<String> patternSegments = _segments(pattern);
    final List<String> pathSegments = _segments(path);

    if (patternSegments.length != pathSegments.length) {
      return false;
    }

    for (int i = 0; i < patternSegments.length; i++) {
      final String expected = patternSegments[i];
      if (expected.startsWith(':')) {
        // A path parameter matches anything except nothing.
        if (pathSegments[i].isEmpty) {
          return false;
        }
        continue;
      }
      if (expected != pathSegments[i]) {
        return false;
      }
    }

    return true;
  }

  static List<String> _segments(String path) =>
      path.split('/').where((String segment) => segment.isNotEmpty).toList();

  /// The destination stored on a `/welcome?redirect=` URL, if it is one this
  /// app is willing to send someone to.
  ///
  /// Only in-app paths are honoured. An absolute URL arriving in a redirect
  /// parameter — from a crafted deep link — would otherwise let the app be used
  /// to bounce a user somewhere else after they sign in.
  static String? intendedDestination(String location) {
    final String? redirect = Uri.parse(location).queryParameters[redirectParam];

    if (redirect == null || redirect.isEmpty) {
      return null;
    }
    if (!redirect.startsWith('/') || redirect.startsWith('//')) {
      return null;
    }
    return redirect;
  }
}
