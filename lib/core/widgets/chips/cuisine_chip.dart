import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A cuisine filter, carrying that cuisine's pastel when selected
/// (docs/COMPONENTS.md §5).
///
/// This is the **one** place a pastel carries a selected state. Everywhere else
/// selection is the interactive green, because selection is binary; cuisine is
/// categorical, and a colour per category is what makes a row of them scannable
/// rather than a row of identical green pills.
///
/// The accent is derived from the cuisine name rather than passed in, so the
/// same cuisine is the same colour on every screen and after every restart.
class CuisineChip extends StatelessWidget {
  const CuisineChip({
    required this.cuisine,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  /// The cuisine's display name, which also seeds its accent.
  final String cuisine;
  final bool isSelected;

  /// Null disables the chip.
  final ValueChanged<bool>? onSelected;

  bool get _isEnabled => onSelected != null;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(cuisine);

    final (Color background, Color foreground, BorderSide? border) = switch ((
      _isEnabled,
      isSelected,
    )) {
      (false, _) => (colors.surfaceMuted, colors.textDisabled, null),
      (true, true) => (accent.background, accent.foreground, null),
      (true, false) => (
        colors.surface,
        colors.textSecondary,
        BorderSide(color: colors.outline),
      ),
    };

    return PressFeedback(
      onTap: _isEnabled ? () => onSelected!(!isSelected) : null,
      semanticLabel: cuisine,
      semanticHint: isSelected ? 'Selected' : 'Not selected',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.borderFull,
          border: border == null ? null : Border.fromBorderSide(border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  cuisine,
                  style: context.text.labelSmall.copyWith(color: foreground),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _height = 36;
}
