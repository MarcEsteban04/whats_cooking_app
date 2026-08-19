import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// The application's single [GoRouter] instance.
///
/// Kept alive deliberately: navigation state must survive the disposal of any
/// individual screen, so this is one of the justified exceptions to the
/// `autoDispose` default (docs/CODING_STANDARDS.md §11).
///
/// The real route tree — splash, auth, onboarding and the shell with its five
/// tabs — arrives in Sprint 09 from docs/NAVIGATION_MAP.md, along with the
/// authentication redirect that watches `authStateProvider`. Until then this
/// serves a single placeholder route so the router, and the Riverpod wiring
/// around it, are exercised by a real build.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const _ScaffoldPlaceholder(),
      ),
    ],
  );
}

/// Temporary landing surface, replaced by the splash route in Sprint 09.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: Text("What's Cooking?"))),
    );
  }
}
