import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A selectable filter (docs/COMPONENTS.md §5, docs/design_ui.md §16).
///
/// Named `AppFilterChip` rather than `FilterChip` to avoid colliding with
/// Material's widget of that name, which this deliberately does not use — the
/// Material chip brings its own ripple, elevation and checkmark, all three of
/// which this design system removes.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.count,
    super.key,
  });

  final String label;
  final bool isSelected;

  /// Null disables the chip.
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  /// An optional trailing count, as in "Filipino 12".
  final int? count;

  bool get _isEnabled => onSelected != null;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final (Color background, Color foreground, BorderSide? border) = switch ((
      _isEnabled,
      isSelected,
    )) {
      (false, _) => (colors.surfaceMuted, colors.textDisabled, null),
      (true, true) => (colors.primary, colors.textOnPrimary, null),
      (true, false) => (
        colors.surface,
        colors.textSecondary,
        BorderSide(color: colors.outline),
      ),
    };

    return PressFeedback(
      onTap: _isEnabled ? () => onSelected!(!isSelected) : null,
      semanticLabel: label,
      // Announced as a toggle so a screen reader states the current state
      // rather than leaving selection to be inferred from colour.
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
                if (icon != null) ...<Widget>[
                  Icon(icon, size: AppIconSize.xs, color: foreground),
                  const SizedBox(width: AppSpacing.space1),
                ],
                Text(
                  label,
                  style: context.text.labelSmall.copyWith(color: foreground),
                  maxLines: 1,
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    '$count',
                    style: context.text.labelSmall.copyWith(
                      color: foreground.withValues(alpha: _countOpacity),
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _height = 36;
  static const double _countOpacity = 0.7;
}
