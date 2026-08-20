import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A navigable row: tinted glyph tile, title, supporting value, chevron.
///
/// The shape the reference uses for every list on its detail screen — services,
/// settings, anything you tap into. In `core/` because the profile, the couple
/// screen and the meal detail all want the same row, and three copies of it would
/// be three sets of padding to keep in step.
///
/// The value beneath the title is the part that earns its place: a list that shows
/// only labels makes you open every row to find out what anything is set to.
class IconListRow extends StatelessWidget {
  const IconListRow({
    required this.title,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.tone = IconListRowTone.neutral,
    super.key,
  });

  final String title;

  /// A glyph for the leading tile. Content, not iconography
  /// (docs/DESIGN_SYSTEM.md §8).
  /// The glyph for the leading tile.
  ///
  /// An icon, never an emoji: a settings list is the last place that wants
  /// somebody else's full-colour artwork in it.
  final IconData? icon;

  /// The current setting or a one-line summary.
  final String? value;

  /// Replaces the chevron — a switch, a count, a badge.
  final Widget? trailing;

  final VoidCallback? onTap;

  final IconListRowTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final (
      Color tileColour,
      Color glyphColour,
      Color titleColour,
    ) = switch (tone) {
      IconListRowTone.neutral => (
        colors.surfaceMuted,
        colors.textSecondary,
        colors.textPrimary,
      ),
      // The reference tints the glyph tile of a service row green. Used here
      // for the rows that lead somewhere good rather than somewhere
      // administrative.
      IconListRowTone.accent => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        colors.textPrimary,
      ),
      IconListRowTone.destructive => (
        colors.error.surface,
        colors.error.onSurface,
        colors.error.color,
      ),
    };

    return PressFeedback(
      onTap: onTap,
      semanticLabel: value == null ? title : '$title. $value',
      expandTouchTarget: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
        child: Row(
          children: <Widget>[
            // No glyph, no tile. A row given no icon is a plain fact —
            // "Signed in as" — and an empty tinted square in front of it would
            // read as an image that failed to load.
            if (icon case final IconData glyph) ...<Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tileColour,
                  borderRadius: AppRadius.borderSm,
                ),
                child: SizedBox.square(
                  dimension: glyphTileSize,
                  child: Center(
                    child: Icon(
                      glyph,
                      size: AppIconSize.sm,
                      color: glyphColour,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: context.text.titleSmall.copyWith(color: titleColour),
                  ),
                  if (value != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      value!,
                      style: context.text.metadata,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.space2),
              trailing!,
            ] else if (onTap != null) ...<Widget>[
              const SizedBox(width: AppSpacing.space2),
              Icon(
                AppIcons.forward,
                size: AppIconSize.xs,
                color: colors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shared with [IconListCard], which insets its dividers past it.
  static const double glyphTileSize = 36;
}

/// What an [IconListRow] leads to.
enum IconListRowTone { neutral, accent, destructive }

/// A card of [IconListRow]s with inset dividers between them.
class IconListCard extends StatelessWidget {
  const IconListCard({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, Widget row) in rows.indexed) ...<Widget>[
            if (index > 0)
              // Inset to start under the text rather than cutting across the
              // glyph column. The reference separates rows without ever drawing
              // a line edge to edge.
              Padding(
                padding: const EdgeInsets.only(left: _dividerInset),
                child: Divider(height: 1, color: context.colors.outline),
              ),
            row,
          ],
        ],
      ),
    );
  }

  static const double _dividerInset =
      IconListRow.glyphTileSize + AppSpacing.space3;
}
