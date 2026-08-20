import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// One item in the "₱220 · 30 min · 2 servings" row (docs/COMPONENTS.md §5).
///
/// Non-interactive by design: the metadata row states facts about a meal, and
/// making any of it tappable would compete with the card's own tap target.
class MetadataPill extends StatelessWidget {
  const MetadataPill({
    required this.label,
    this.icon,
    this.isNumeric = false,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Whether to render in the tabular-figures style.
  ///
  /// True for costs and quantities, so digits do not jitter as a price changes
  /// during the roulette animation (docs/DESIGN_SYSTEM.md §3).
  final bool isNumeric;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final TextStyle style =
        (isNumeric ? context.text.numeric : context.text.labelSmall).copyWith(
          color: colors.textSecondary,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
        child: ConstrainedBox(
          // A minimum rather than a fixed height: at 1.3x text scale the label
          // is taller than 32 and must be allowed to grow rather than clip.
          constraints: const BoxConstraints(minHeight: _height),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppIconSize.xs, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.space1),
              ],
              // Flexible, because a pill lives in a `Wrap` that hands it the
              // full row width as a maximum. A label longer than the row — a
              // four-figure cost at 1.3x text scale on a 320 px screen — used to
              // overflow rather than shorten.
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _height = 32;
}
