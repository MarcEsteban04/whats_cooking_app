import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// How an [AppIconButton] is filled.
enum AppIconButtonStyle {
  /// No fill. App-bar actions, inline controls.
  plain,

  /// A `surface` circle with `shadowXs`. The floating controls of the reference
  /// — the heart on a meal card, the back button over a hero image.
  floating,

  /// A `surfaceMuted` circle. Quiet controls inside a card.
  muted,
}

/// An icon-only control.
///
/// [semanticLabel] is required, not optional: docs/DESIGN_SYSTEM.md §8 and §11
/// both state that an icon-only control always carries a label, and a required
/// parameter is the only version of that rule which cannot be forgotten.
///
/// The visual is [visualSize]; the touch target is always at least
/// [AppLayout.minTouchTarget], so a 36 px heart is still comfortably tappable.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.style = AppIconButtonStyle.plain,
    this.iconSize = AppIconSize.md,
    this.visualSize,
    this.color,
    super.key,
  });

  final IconData icon;

  /// What a screen reader announces. Describes the *action*, not the glyph:
  /// "Save to favourites", never "heart".
  final String semanticLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppIconButtonStyle style;
  final double iconSize;

  /// Diameter of the filled circle. Defaults to a comfortable ring around
  /// [iconSize] for the filled styles, and to the glyph itself for the plain style.
  final double? visualSize;

  /// Overrides the icon colour. Defaults to `textSecondary`, per §8.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isEnabled = onPressed != null;
    final Color iconColor = isEnabled
        ? (color ?? colors.textSecondary)
        : colors.textDisabled;

    final double diameter =
        visualSize ??
        (style == AppIconButtonStyle.plain
            ? iconSize
            : iconSize + AppSpacing.space3);

    Widget visual = Icon(icon, size: iconSize, color: iconColor);

    if (style != AppIconButtonStyle.plain) {
      visual = DecoratedBox(
        decoration: BoxDecoration(
          color: style == AppIconButtonStyle.floating
              ? colors.surface
              : colors.surfaceMuted,
          shape: BoxShape.circle,
          boxShadow: style == AppIconButtonStyle.floating
              ? context.shadows.xs
              : null,
        ),
        child: SizedBox.square(
          dimension: diameter,
          child: Center(child: visual),
        ),
      );
    }

    return PressFeedback(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      child: visual,
    );
  }
}
