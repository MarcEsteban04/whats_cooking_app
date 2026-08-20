import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';

/// The layout every settings sub-screen shares.
///
/// Left-aligned, unlike the auth screens: these are screens *inside* the app, and
/// docs/design_ui.md §8's left-aligned hierarchy is the app's normal voice. Auth
/// centres because it is a threshold; settings should not.
///
/// A [action] pinned at the foot rather than an app-bar "Save": the pinned pill is
/// the app's primary-action shape everywhere else, and a save button in the top
/// corner is the one control people reliably fail to find.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Pinned above the safe area.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenMargin,
                    AppSpacing.space4,
                    AppLayout.screenMargin,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            boxShadow: context.shadows.xs,
                          ),
                          child: AppIconButton(
                            icon: AppIcons.back,
                            semanticLabel: 'Back',
                            iconSize: AppIconSize.sm,
                            // pop() rather than a named route, so a screen
                            // reached from two places returns to whichever one
                            // it came from.
                            onPressed: () => context.pop(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(title, style: context.text.headlineMedium),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.space2),
                        Text(
                          subtitle!,
                          style: context.text.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.space5),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.screenMargin,
                      0,
                      AppLayout.screenMargin,
                      AppSpacing.space7,
                    ),
                    child: child,
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.screenMargin,
                      AppSpacing.space3,
                      AppLayout.screenMargin,
                      AppSpacing.space5,
                    ),
                    child: action,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
