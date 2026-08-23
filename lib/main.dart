import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/analytics/analytics.dart';
import 'package:whats_cooking/core/config/app_env.dart';
import 'package:whats_cooking/core/errors/global_error_handler.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/core/router/app_router.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/core/widgets/feedback/app_toast.dart';
import 'package:whats_cooking/features/profile/presentation/providers/reminder_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/theme_mode_controller.dart';

Future<void> main() async {
  // Installed before anything else runs, so an error thrown during startup is
  // reported rather than lost (docs/ARCHITECTURE.md §9).
  GlobalErrorHandler.install();

  await GlobalErrorHandler.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Fails loudly if a privileged key was passed in. Continuing would ship a
    // build in which every Row Level Security policy is bypassed, and nothing
    // else in the stack would notice.
    AppEnv.assertNoPrivilegedKey();

    // And the same for an AI provider key, which is the easier mistake to make:
    // the three keys live in the same `.env.local` as the Supabase ones, and
    // pasting them into `config/development.json` would work — the assistant
    // would answer, and the build would ship with three billable credentials in
    // it. They belong on the ai-assistant Edge Function (Sprint 59).
    AppEnv.assertNoProviderKey();

    AppLog.info('Starting ${AppEnv.describe()}', name: 'main');

    // Awaited, because a session restored from secure storage has to be in place
    // before the router runs its first redirect — otherwise a returning user
    // sees the welcome screen for a frame.
    //
    // Missing credentials are handled inside: the app starts without a backend
    // rather than crashing, so a fresh clone runs (supabase/README.md).
    await SupabaseBootstrap.initialize();

    final ProviderContainer container = ProviderContainer();

    // Not awaited. The health probe's answer is a diagnosis for the log, not
    // something the first frame depends on — waiting on a network round trip
    // before painting would trade a startup budget for a log line
    // (docs/ARCHITECTURE.md §12: 1.5 s cold start to interactive).
    unawaited(container.read(backendStatusProvider.future));

    // The cold open, and the moment the Time to Decision clock starts
    // (docs/ARCHITECTURE.md §10). Here rather than in the first screen's
    // `initState`, because the metric is about opening the *app*: a household
    // that lands on the welcome screen, signs in and then decides has spent all
    // of that time deciding, and a clock started after the redirect would hide
    // the slowest part of the journey.
    container.read(analyticsProvider).appLaunched();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const WhatsCookingApp(),
      ),
    );
  });
}

/// Application root.
///
/// A consumer because the router is provided by Riverpod, which is also how the
/// authentication redirect reaches the auth state without any screen performing
/// its own check (docs/ARCHITECTURE.md §7).
///
/// Stateful because the app's own lifecycle is the other half of the Time to
/// Decision measurement: a resume can start a new session, and backgrounding is
/// the last chance to flush buffered events before the OS is free to kill the
/// process.
class WhatsCookingApp extends ConsumerStatefulWidget {
  const WhatsCookingApp({super.key});

  @override
  ConsumerState<WhatsCookingApp> createState() => _WhatsCookingAppState();
}

class _WhatsCookingAppState extends ConsumerState<WhatsCookingApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();

    // Brings the reminder controller to life (Sprint 56).
    //
    // A read rather than a call, and that is the whole point: the controller is
    // `keepAlive` but still *lazy*, so before this line nothing constructed it and
    // its `build` — which restores the saved setting and re-asserts the schedule —
    // had never run. The reminder would have worked until the first reboot and
    // then silently stopped, because Android drops every pending alarm on restart
    // and the boot receiver only restores what was outstanding at the time.
    //
    // The value is deliberately unused. Nothing on this screen depends on it.
    ref.read(reminderControllerProvider);

    // [AppLifecycleListener] rather than [WidgetsBindingObserver]: it reports the
    // transitions by name, so "hidden, then paused, then detached" on the way to
    // the background does not have to be reconstructed from a state enum here.
    _lifecycle = AppLifecycleListener(
      onPause: () => ref.read(analyticsProvider).appBackgrounded(),
      onResume: () {
        ref.read(analyticsProvider).appResumed();

        // Refills the reminder queue with what is true now. `ReminderController`
        // lays down a week of notifications rather than a repeating alarm, and
        // only the first carries anything current — so coming back is what keeps
        // them fresh and keeps the queue from running out. Here rather than on
        // Home, because a resume onto any tab is still a resume. Free when the
        // reminder is off: `apply` cancels and returns.
        unawaited(ref.read(reminderControllerProvider.notifier).apply());
      },
      // The last call the framework makes. A flush here is best-effort — the
      // process may not survive long enough for the request — which is why
      // `onPause` above flushes too rather than relying on this.
      onDetach: () => unawaited(ref.read(analyticsProvider).flush()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeMode themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: "What's Cooking?",
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // The user's choice, defaulting to the OS setting. docs/design_ui.md §1
      // rules out a dark interface *by default*, not dark mode itself, and an app
      // that ignores the system preference is the one thing a premium app never
      // does — so system is the default and the override is theirs to set
      // (docs/USER_FLOWS.md §17).
      themeMode: themeMode,

      builder: _clampTextScale,
    );
  }

  /// Clamps OS text scaling, and hangs the toast layer above every route.
  ///
  /// **Clamping rather than ignoring** (docs/DESIGN_SYSTEM.md §3): below 0.85 the
  /// 13 px metadata floor stops being legible, and above 1.3 prices and button
  /// labels start to truncate. Both bounds are a promise the layouts have to
  /// keep, so they are enforced once here instead of per screen.
  ///
  /// **[ToastHost] belongs here and nowhere else** (Sprint 57). `builder` runs
  /// below the theme and the media query and *above* the router's navigator, so
  /// one host covers every route, sheet and full-screen takeover — and no screen
  /// has to own a messenger or hold a context to say something happened.
  static Widget _clampTextScale(BuildContext context, Widget? child) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: AppTypography.minTextScale,
          maxScaleFactor: AppTypography.maxTextScale,
        ),
      ),
      child: ToastHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
