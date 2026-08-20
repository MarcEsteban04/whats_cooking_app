import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/app_badge.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

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
                      minHeight:
                          constraints.maxHeight - (AppSpacing.space5 * 2),
                    ),
                    child: const IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Spacer(),
                          _Wordmark(),
                          SizedBox(height: AppSpacing.space7),
                          _Headline(),
                          SizedBox(height: AppSpacing.space7),
                          _PromiseCluster(),
                          Spacer(),
                          SizedBox(height: AppSpacing.space7),
                          _Actions(),
                        ],
                      ),
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
/// An emoji on a pastel disc rather than an asset: docs/DESIGN_SYSTEM.md §8
/// treats emoji as content, and the app icon is Sprint 69's job — a placeholder
/// PNG shipped now would be a second thing to remember to replace.
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
                child: Text('🎰', style: TextStyle(fontSize: AppIconSize.lg)),
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

/// Spin, decide, eat — as three staggered floating cards.
///
/// Staggered rather than aligned, following the reference's overlapping stat
/// cards (docs/design_ui.md §35). Each is offset a little further than the last,
/// which reads as depth without any of them actually overlapping — overlap on a
/// 320 px screen would clip.
class _PromiseCluster extends StatelessWidget {
  const _PromiseCluster();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int index, (String emoji, String title, String body))
            in _promises.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.space3),
          Padding(
            // The stagger. Held to three steps of 12 px, so the last card is
            // still comfortably inside the screen margin.
            padding: EdgeInsets.only(left: index * AppSpacing.space3),
            child: _PromiseCard(
              emoji: emoji,
              title: title,
              body: body,
              accentSeed: title,
            ),
          ),
        ],
      ],
    );
  }

  static const List<(String, String, String)> _promises =
      <(String, String, String)>[
        ('🎰', 'Spin', 'One tap and we pick, from meals you already like.'),
        ('❤️', 'Agree', 'Cooking for two? We find what you both want.'),
        ('🍳', 'Eat', 'Costs, timings and a grocery list, sorted.'),
      ];
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accentSeed,
  });

  final String emoji;
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
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: AppIconSize.md),
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
