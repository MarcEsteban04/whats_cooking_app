import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/config/app_env.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/profile/presentation/providers/reminder_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/theme_mode_controller.dart';

/// Settings.
///
/// **Replaces a placeholder**, and it is deliberately short. Two screens sit
/// under it and both already existed — appearance and account — so the job here
/// was never to invent settings but to stop the only door to them being a page
/// that said "Sprint 20".
///
/// **Notifications are listed now** (Sprint 56). They were deliberately left off
/// for two sprints, on the rule that a labelled tile leading to a placeholder is
/// worse than no tile — it teaches people that tiles do not work. The condition
/// that comment set was "when there is something to notify", and there is: the
/// evening reminder, which is the app's only notification and the one thing that
/// gets it opened at the hour it is useful.
///
/// Each row shows its current value rather than only a label, which is the one
/// rule this screen inherits from the old profile list: a settings list you have
/// to open to read is a settings list nobody reads.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeControllerProvider);
    final ReminderSetting reminder = ref.watch(reminderControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenMargin,
                AppSpacing.space4,
                AppLayout.screenMargin,
                AppLayout.scrollBottomPadding,
              ),
              children: <Widget>[
                DashboardPanel(
                  title: 'This app',
                  icon: AppIcons.settings,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Listed now (Sprint 56). The comment above this class
                      // used to explain why it was not: nothing in the app sent a
                      // notification, so the tile would have led to a
                      // placeholder. It sends one.
                      DashboardRow(
                        title: 'Reminders',
                        subtitle: 'BEING ASKED WHAT TO EAT',
                        value: reminder.isOn ? reminder.label : 'Off',
                        trailing: const Icon(
                          AppIcons.forward,
                          size: AppIconSize.xs,
                        ),
                        onTap: () => context.pushNamed(
                          AppRoute.notificationSettings.routeName,
                        ),
                      ),
                      const DashboardRule(),
                      DashboardRow(
                        title: 'Appearance',
                        subtitle: 'LIGHT, DARK OR WHATEVER THE PHONE IS',
                        value: _themeLabel(mode),
                        trailing: const Icon(
                          AppIcons.forward,
                          size: AppIconSize.xs,
                        ),
                        onTap: () => context.pushNamed(
                          AppRoute.appearanceSettings.routeName,
                        ),
                      ),
                      const DashboardRule(),
                      DashboardRow(
                        title: 'Account',
                        subtitle: 'PASSWORD, SIGN OUT, DELETE',
                        trailing: const Icon(
                          AppIcons.forward,
                          size: AppIconSize.xs,
                        ),
                        onTap: () => context.pushNamed(
                          AppRoute.accountSettings.routeName,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.space4),
                const _About(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What the appearance row reads, so the value is visible without opening it.
  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Match the phone',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

/// What this build is.
///
/// **Not an "About" page with a logo and a licence.** Nobody needs one for an app
/// two people sideload. What is genuinely useful is whether the phone is talking
/// to the backend, because every screen in the app is empty without it and the
/// symptom looks identical to having no data — that cost an evening once already.
///
/// The flavour and the backend state only, and **never the project URL**: it
/// identifies the project and belongs in a dashboard, not on a screen somebody
/// might screenshot.
class _About extends ConsumerWidget {
  const _About();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BackendStatus> health = ref.watch(backendStatusProvider);

    final (String, Color) backend = switch (health) {
      AsyncData<BackendStatus>(value: BackendStatus.healthy) => (
        'Connected',
        context.colors.success.color,
      ),
      AsyncData<BackendStatus>() => (
        'Not reachable',
        context.colors.error.color,
      ),
      AsyncError<BackendStatus>() => (
        'Not reachable',
        context.colors.error.color,
      ),
      _ => ('Checking…', context.colors.textTertiary),
    };

    return DashboardPanel(
      title: 'This build',
      icon: AppIcons.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DashboardRow(
            title: 'Backend',
            value: backend.$1,
            trailing: Icon(
              AppIcons.success,
              size: AppIconSize.xs,
              color: backend.$2,
            ),
            onTap: () => ref.invalidate(backendStatusProvider),
          ),
          const DashboardRule(),
          DashboardRow(
            title: 'Flavour',
            // Only ever "development" or "production" — no key, no URL.
            value: AppEnv.flavor.name,
          ),
        ],
      ),
    );
  }
}
