import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// A small floating figure card (docs/design_ui.md §26 and §35).
///
/// The reference's signature move: little white cards carrying one number each,
/// slightly overlapping the content behind them so the surface reads as layered
/// rather than flat. §35 is explicit that the effect is worth having and worth
/// rationing — "do not overuse this effect".
///
/// The number leads and the label follows, because the number is what someone
/// came to read. §26: "Keep analytics visually simple. Avoid creating a
/// complicated analytics dashboard."
class StatCard extends StatelessWidget {
  const StatCard({
    required this.value,
    required this.label,
    this.emoji,
    this.isRaised = false,
    super.key,
  });

  /// The figure — "32", "₱187", "87%".
  final String value;

  /// What it counts.
  final String label;

  /// An optional glyph above the figure.
  final String? emoji;

  /// Lifts the card with `shadowMd` instead of `shadowSm`.
  ///
  /// For the one card in a row that overlaps its neighbour, which needs the extra
  /// separation to read as being in front rather than merely beside.
  final bool isRaised;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.borderMd,
          boxShadow: isRaised ? context.shadows.md : context.shadows.sm,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (emoji != null) ...<Widget>[
                Text(emoji!, style: const TextStyle(fontSize: AppIconSize.sm)),
                const SizedBox(height: AppSpacing.space1),
              ],
              Text(
                value,
                style: context.text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                label,
                style: context.text.metadata,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of [StatCard]s that wraps rather than squeezing.
///
/// The reference staggers three of these across the width. A [Wrap] keeps that
/// arrangement on a normal phone and lets the third drop to a second line at
/// 1.3x text scale, instead of the row clipping — which is what a fixed
/// three-across layout would do on a 320 px screen.
class StatCardRow extends StatelessWidget {
  const StatCardRow({required this.cards, super.key});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space3,
      runSpacing: AppSpacing.space3,
      children: cards,
    );
  }
}
