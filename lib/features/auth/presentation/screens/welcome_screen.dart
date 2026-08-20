import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/app_badge.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/feedback/backend_banner.dart';

/// The first screen anyone sees (docs/USER_FLOWS.md §1).
///
/// Built to `docs/reference_design/reference_img.webp` rather than to the auth
/// reference: this screen's job is not to take input, it is to say what the app
/// *is*. So it borrows the home screen's language — warm ground, floating white
/// cards, a staggered card cluster, generous whitespace — and shows the product
/// instead of describing it.
///
/// The cluster is the point. "Spin. Decide. Eat." told as three floating cards is
/// the same promise the roulette makes, arranged the way the reference arranges
/// its stat cards, so the first screen already looks like the app it opens.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.screenMargin,
                    vertical: AppSpacing.space5,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0,
                        constraints.maxHeight - (AppSpacing.space5 * 2),
                      ),
                    ),
                    // `spaceBetween` rather than `IntrinsicHeight` and two
                    // `Spacer`s. The Spacer version looked identical and was
                    // broken: `IntrinsicHeight` resolves to the *tighter* of the
                    // intrinsic height and the incoming constraint, so once the
                    // content grew past the viewport — which the backend banner
                    // alone was enough to do — the column was pinned to the
                    // viewport height and overflowed instead of scrolling. It
                    // cost the sign-in button, and only a real device showed it.
                    //
                    // A plain column under `minHeight` sizes to whichever is
                    // larger, so it fills a tall screen and scrolls on a short
                    // one, and `spaceBetween` distributes whatever slack there
                    // is between the three groups.
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            BackendBanner(),
                            _Wordmark(),
                            SizedBox(height: AppSpacing.space7),
                            _Headline(),
                          ],
                        ),
                        // The minimum gaps, so the groups never touch when
                        // `spaceBetween` has no slack to give.
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.space6,
                          ),
                          child: _PromiseCluster(),
                        ),
                        _Actions(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The product mark and name, on one line.
///
/// A glyph on a disc rather than an asset: the app icon is Sprint 69's job, and
/// a placeholder PNG shipped now would be a second thing to remember to replace.
///
/// An icon rather than the slot-machine emoji it used to be. The palette has no
/// colour of its own any more, so a full-colour glyph was the one thing on the
/// first screen anybody sees that did not come from the design system.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.borderMd,
            boxShadow: context.shadows.sm,
          ),
          child: const SizedBox.square(
            dimension: _markSize,
            child: Center(
              child: ExcludeSemantics(
                child: Icon(AppIcons.spin, size: AppIconSize.lg),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Text(
            AppConstants.appName,
            style: context.text.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const AppBadge(label: 'Beta', tone: AppBadgeTone.highlight),
      ],
    );
  }

  static const double _markSize = 48;
}

/// The pitch, left-aligned as the reference's greeting is.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('What are we\neating tonight?', style: context.text.displayMedium),
        const SizedBox(height: AppSpacing.space4),
        Text(
          // The tagline, and the problem in the user's own words. It is the
          // product's whole reason to exist (docs/app_feature.md, Brand).
          '${AppConstants.tagline} Tell us what you like, and we will decide '
          'in under a minute.',
          style: context.text.bodyLarge.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Spin, agree, eat — three floating cards, flush left.
///
/// These were staggered, each indented 12 px further than the last, on the
/// reasoning that it echoed the reference's overlapping stat cards
/// (docs/design_ui.md §35). It did not. The reference's cards overlap, and
/// overlap is what makes them read as layered; indentation without overlap just
/// makes three cards look misaligned, especially under a headline and a
/// paragraph that both start at the margin.
///
/// They are also the wrong thing to stagger. §35's cards are small decorative
/// figures sitting in front of content; these are three equal promises, and a
/// set of equals should line up.
class _PromiseCluster extends StatelessWidget {
  const _PromiseCluster();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int index, (IconData icon, String title, String body))
            in _promises.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.space3),
          _PromiseCard(icon: icon, title: title, body: body, accentSeed: title),
        ],
      ],
    );
  }

  static const List<(IconData, String, String)> _promises =
      <(IconData, String, String)>[
        (
          AppIcons.spin,
          'Spin',
          'One tap and we pick, from meals you already like.',
        ),
        (
          AppIcons.household,
          'Agree',
          'Cooking for two? We find what you both want.',
        ),
        (AppIcons.meals, 'Eat', 'Costs, timings and a grocery list, sorted.'),
      ];
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentSeed,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Seeds the pastel, so each card keeps its colour between launches
  /// (docs/DESIGN_SYSTEM.md §9).
  final String accentSeed;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(accentSeed);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.borderXl,
        boxShadow: context.shadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.background,
                borderRadius: AppRadius.borderSm,
              ),
              child: SizedBox.square(
                dimension: _tileSize,
                child: Center(
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: AppIconSize.md,
                      color: accent.foreground,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.space1),
                  Text(body, style: context.text.metadata),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _tileSize = 44;
}

/// The two ways in, plus the guest offer.
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const SizedBox(height: AppSpacing.space2),
        // Guest mode is P1 and its route is registered but unbuilt
        // (docs/NAVIGATION_MAP.md §2). Offered and disabled rather than absent,
        // so the layout does not shift when Sprint 29 enables it.
        const AppButton.tertiary(label: 'Try it first', onPressed: null),
      ],
    );
  }
}
