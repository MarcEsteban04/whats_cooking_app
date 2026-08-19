import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: WhatsCookingApp()));
}

/// Application root.
///
/// A [ConsumerWidget] because the router is provided by Riverpod, which is also
/// how the Sprint 09 authentication redirect will reach the auth state without
/// any screen performing its own check (docs/ARCHITECTURE.md §7).
class WhatsCookingApp extends ConsumerWidget {
  const WhatsCookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    // Theming lands in Sprint 07 from docs/DESIGN_SYSTEM.md; the framework
    // default applies until then.
    return MaterialApp.router(
      title: "What's Cooking?",
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
