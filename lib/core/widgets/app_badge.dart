import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// What a badge means, which decides its colour.
enum AppBadgeTone {
  /// The gold "Top" pill from the reference. For a standout: a meal both
  /// partners love, a streak worth noticing.
  highlight,

  /// A confirmed, done, agreed thing.
  success,

  /// A neutral fact.
  neutral,
}

/// A small pill carrying one short fact (docs/design_ui.md §35).
///
/// The reference uses two: a gold "⭐ Top" beside a name and a "✓ Confirmed"
/// inside a card. Both are the same shape doing the same job — one word that
/// changes how you read the thing next to it. This app's palette has no green
/// to tint the second with, so it takes ink and leans on its tick.
///
/// Kept deliberately small and wordy-averse. A badge that needs a sentence is a
/// caption, and a screen with five badges has none.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.icon,
    this.tone = AppBadgeTone.neutral,
    super.key,
  });

  final String label;
  final IconData? icon;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final (Color background, Color foreground) = switch (tone) {
      // The butter pastel and its paired foreground, which reach AA together —
      // a gold badge mixed by hand would not (docs/DESIGN_SYSTEM.md §2.3).
      AppBadgeTone.highlight => (
        colors.butter.background,
        colors.butter.foreground,
      ),
      AppBadgeTone.success => (
        colors.success.surface,
        colors.success.onSurface,
      ),
      AppBadgeTone.neutral => (colors.surfaceMuted, colors.textSecondary),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.borderFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: _iconSize, color: foreground),
              const SizedBox(width: AppSpacing.space1),
            ],
            // Flexible, because a badge is often placed beside other content
            // in a row with no room to spare. It stays on one line — a
            // two-line badge is a caption — so at 1.3x on a narrow screen the
            // right degradation is an ellipsis, not an overflow.
            Flexible(
              child: Text(
                label,
                style: context.text.labelSmall.copyWith(color: foreground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Smaller than `iconXs`, because a badge glyph sits beside 13 px text and the
  /// standard small icon overpowers it.
  static const double _iconSize = 12;
}
