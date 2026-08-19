import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/router/app_router.dart';
import 'package:whats_cooking/core/theme/theme.dart';

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

    return MaterialApp.router(
      title: "What's Cooking?",
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // The OS setting decides. docs/design_ui.md §1 rules out a dark interface
      // *by default*, not dark mode itself, and an app that ignores the system
      // preference is the one thing a premium app never does. A manual override
      // arrives with the appearance setting in Sprint 20.
      themeMode: ThemeMode.system,

      builder: _clampTextScale,
    );
  }

  /// Clamps OS text scaling to the range every layout is designed to survive
  /// (docs/DESIGN_SYSTEM.md §3).
  ///
  /// Clamping rather than ignoring: below 0.85 the 13 px metadata floor stops
  /// being legible, and above 1.3 prices and button labels start to truncate.
  /// Both bounds are a promise the layouts have to keep, so they are enforced
  /// once here instead of per screen.
  static Widget _clampTextScale(BuildContext context, Widget? child) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: AppTypography.minTextScale,
          maxScaleFactor: AppTypography.maxTextScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
