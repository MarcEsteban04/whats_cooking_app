import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A quick-pick category tile (docs/COMPONENTS.md §6, docs/design_ui.md §10).
///
/// Built to the reference's specialty grid, which resolves a disagreement between
/// two of our own documents. §6 and §10 both say the card should be *filled* with
/// a pastel; the reference's cards are **white, with the colour carried by a
/// tinted glyph tile inside**. The reference is right, and for a reason worth
/// keeping: a grid of six saturated blocks fights the white cards around it and
/// makes the whole screen louder, while six white cards with six coloured glyphs
/// reads as one calm set.
///
/// So the pastel stays — it just moves from the card to the tile. §2.3's rule
/// that a pastel never carries text is honoured either way.
///
/// Tapping a category **starts a spin with that filter applied**
/// (docs/USER_FLOWS.md §6) — it is not a browse entry point, which is why the
/// semantic label says so.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.semanticAction = 'spin',
    super.key,
  });

  final String label;

  /// The category's glyph.
  ///
  /// An icon rather than an emoji: §8 called glyphs "content, not iconography",
  /// which was true when the palette had colour of its own to sit beside. It does
  /// not, and a full-colour emoji on a pastel tile now reads as clip art.
  final IconData icon;

  /// The pastel for the glyph tile, from `context.colors.accentFor(...)` so the
  /// same category keeps the same colour everywhere.
  final AppAccent accent;

  final VoidCallback onTap;

  /// What the tap does, for the announcement — "Comfort food, spin".
  final String semanticAction;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: onTap,
      // §6: "The semantic label must say so: *Comfort food — spin*." Otherwise a
      // screen reader user is told this is a category and discovers it was a
      // button that changed their evening.
      semanticLabel: '$label, $semanticAction',
      expandTouchTarget: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.borderXl,
          boxShadow: context.shadows.xs,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        size: AppIconSize.lg,
                        color: accent.foreground,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                label,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _tileSize = 44;
}

/// The category grid (docs/COMPONENTS.md §6: "Three across on compact, four on
/// medium, 12 px gaps").
///
/// Column count comes from the breakpoint helper rather than a raw width, per
/// docs/DESIGN_SYSTEM.md §10.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({required this.cards, super.key});

  final List<CategoryCard> cards;

  @override
  Widget build(BuildContext context) {
    final int columns = AppBreakpoints.of(context).categoryGridColumns;

    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: AppLayout.gridGap,
      crossAxisSpacing: AppLayout.gridGap,
      // Slightly taller than square, so the label has room at 1.3x text scale
      // without the tile shrinking.
      childAspectRatio: _aspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: cards,
    );
  }

  static const double _aspectRatio = 0.88;
}
