import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// One navigable row inside a profile card.
///
/// docs/design_ui.md §25 lays the profile out as cards of rows: a leading tinted
/// glyph, a title, the current value beneath it, and a chevron. The value is the
/// point — a settings list that shows only labels makes you open every row to
/// find out what anything is set to.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    required this.title,
    required this.emoji,
    this.value,
    this.onTap,
    this.isDestructive = false,
    super.key,
  });

  final String title;

  /// The leading glyph. Content, not iconography
  /// (docs/DESIGN_SYSTEM.md §8).
  final String emoji;

  /// The current setting, shown beneath the title.
  final String? value;

  final VoidCallback? onTap;

  /// Renders the title in the error colour, for sign-out and deletion.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final Color titleColour = isDestructive
        ? colors.error.color
        : colors.textPrimary;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: value == null ? title : '$title. $value',
      expandTouchTarget: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.borderSm,
              ),
              child: SizedBox.square(
                dimension: _glyphSize,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: AppIconSize.sm),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
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
            if (onTap != null) ...<Widget>[
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

  static const double _glyphSize = 36;
}

/// A card of [ProfileRow]s with dividers between them.
class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.rows, super.key});

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
              // Inset so the divider starts under the text rather than cutting
              // across the glyph column — the reference separates rows without
              // drawing a full-width line.
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

  static const double _dividerInset = 36 + AppSpacing.space3;
}
