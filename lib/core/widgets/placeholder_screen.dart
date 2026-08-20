import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// A stand-in for a screen its feature has not built yet.
///
/// **Temporary scaffolding.** Sprint 09 wires every route in
/// docs/NAVIGATION_MAP.md §2 so that navigation, guards and transitions can be
/// built and tested as one thing; the screens themselves arrive with their own
/// features, from Sprint 16 onward. Each route swaps its placeholder for the
/// real screen as that sprint lands, and this file is deleted when the last one
/// does.
///
/// It names the sprint that will replace it, so an unimplemented screen reached
/// during development says what it is waiting for rather than looking broken.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.sprint,
    this.detail,
    this.action,
    super.key,
  });

  /// The screen this will become.
  final String title;

  /// Which sprint builds it, e.g. `Sprint 22`.
  final String sprint;

  /// An optional note — a path parameter's value, usually, so a test or a
  /// developer can see the route resolved its arguments.
  final String? detail;

  /// An action the placeholder can still offer.
  ///
  /// Used by the Profile route to expose sign-out before Sprint 20 builds the
  /// real screen. Without it there is no way out of a signed-in app, which makes
  /// the whole auth flow impossible to exercise by hand.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.screenMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  AppIcons.settings,
                  size: AppIconSize.xl,
                  color: colors.textDisabled,
                ),
                const SizedBox(height: AppSpacing.space5),
                Text(
                  title,
                  style: context.text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Arrives in $sprint',
                  style: context.text.metadata,
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.space6),
                  action!,
                ],
                if (detail != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    detail!,
                    style: context.text.bodySmall.copyWith(
                      color: colors.textDisabled,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
