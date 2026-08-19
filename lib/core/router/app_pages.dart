import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The page types the router uses (docs/NAVIGATION_MAP.md §6).
///
/// Transitions are declared here rather than per route so that "screen to child
/// uses the platform default" and "home to spin scales and fades" are each
/// written once. Every one degrades to a cross-fade when the platform asks for
/// reduced motion.

/// A bottom sheet presented as a route.
///
/// docs/NAVIGATION_MAP.md §9: "Bottom sheets are routes, not imperative
/// `showModalBottomSheet` calls — they must be deep-linkable and must survive
/// configuration changes."
///
/// Backed by a real [ModalBottomSheetRoute] rather than a translucent page, so
/// drag-to-dismiss, the scrim and the barrier all behave as Material's own
/// sheets do; §9 requires drag-to-dismiss everywhere.
class AppSheetPage<T> extends Page<T> {
  const AppSheetPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return ModalBottomSheetRoute<T>(
      settings: this,
      builder: (BuildContext context) => child,
      // The sheet sizes to its content and may grow to 90% of the screen, which
      // it cannot do without this.
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
    );
  }
}

/// A full-screen route that scales and fades in.
///
/// The Home-to-spin transition: the spin takes over the screen rather than
/// sliding in beside it (§6).
class AppScaleFadePage<T> extends CustomTransitionPage<T> {
  const AppScaleFadePage({required super.child, super.key, super.name})
    : super(
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: _transition,
      );

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curveNormal,
    );

    // Reduce motion keeps the fade and drops the scale: the fade carries the
    // "something changed" signal without the movement.
    if (AppMotion.prefersReducedMotion(context)) {
      return FadeTransition(opacity: curved, child: child);
    }

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: _fromScale, end: 1).animate(curved),
        child: child,
      ),
    );
  }

  static const double _fromScale = 0.92;
}

/// A cross-fade, used for every transition when motion is reduced.
class AppFadePage<T> extends CustomTransitionPage<T> {
  const AppFadePage({required super.child, super.key, super.name})
    : super(
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.normal,
        transitionsBuilder: _transition,
      );

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.curveNormal),
      child: child,
    );
  }
}

/// A tab root, which never animates.
///
/// §6: "Tab to tab: instant, no animation. Tabs must feel like places, not
/// steps." An animated tab switch makes five destinations feel like a five-step
/// wizard.
class AppInstantPage<T> extends CustomTransitionPage<T> {
  const AppInstantPage({required super.child, super.key, super.name})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: _noTransition,
      );

  static Widget _noTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
