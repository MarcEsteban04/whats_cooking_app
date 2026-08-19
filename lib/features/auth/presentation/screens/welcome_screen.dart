import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/features/auth/presentation/widgets/auth_scaffold.dart';

/// The first screen anyone sees (docs/USER_FLOWS.md §1).
///
/// Not in `login_reference.webp`, which starts at sign-in — so it is built in the
/// same language: centred headline, centred subtitle, near-black primary pill,
/// quiet secondary beneath it. What it adds is the product's own face, since this
/// is the one screen whose job is to say what the app *is*.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: AppConstants.appName,
      subtitle: AppConstants.tagline,
      leading: const _WelcomeMark(),
      footer: const AppButton.tertiary(
        // Guest mode is P1 and its route is registered but unbuilt
        // (docs/NAVIGATION_MAP.md §2), so the offer is here and disabled rather
        // than absent — the layout will not shift when Sprint 29 enables it.
        label: 'Try it first',
        onPressed: null,
      ),
      children: <Widget>[
        AppButton.inverse(
          label: 'Get started',
          onPressed: () => context.goNamed(AppRoute.register.routeName),
        ),
        const SizedBox(height: AppSpacing.space3),
        AppButton.secondary(
          label: 'I already have an account',
          isFullWidth: true,
          onPressed: () => context.goNamed(AppRoute.login.routeName),
        ),
      ],
    );
  }
}

/// The product mark: the roulette emoji on a soft pastel disc.
///
/// An emoji rather than an asset, deliberately. docs/DESIGN_SYSTEM.md §8 treats
/// emoji as content, and the app icon is Sprint 69's job — a placeholder PNG
/// shipped now would be a second thing to remember to replace.
class _WelcomeMark extends StatelessWidget {
  const _WelcomeMark();

  @override
  Widget build(BuildContext context) {
    final AppAccent accent = context.colors.accentFor(AppConstants.appName);

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.background,
          shape: BoxShape.circle,
          boxShadow: context.shadows.sm,
        ),
        child: const SizedBox.square(
          dimension: _diameter,
          child: Center(
            child: ExcludeSemantics(
              child: Text('🎰', style: TextStyle(fontSize: _glyphSize)),
            ),
          ),
        ),
      ),
    );
  }

  static const double _diameter = 104;
  static const double _glyphSize = 48;
}
