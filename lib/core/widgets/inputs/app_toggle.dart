import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// The small pill switch from `docs/reference_design/login_reference.webp`.
///
/// Used for "Remember me" and the terms agreement. Not Material's [Switch]: that
/// one is taller, carries a ripple and an outline, and its thumb grows on
/// selection — three details that read as Material rather than as the reference's
/// flat pill.
///
/// On is the near-black `surfaceInverse`, matching the reference and the CTA it
/// sits above; off is the neutral outline. The knob is always `surface`.
class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;

  /// Null disables the toggle.
  final ValueChanged<bool>? onChanged;

  /// What a screen reader announces. Required, because the toggle carries no
  /// text of its own (docs/DESIGN_SYSTEM.md §11).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isEnabled = onChanged != null;

    final Color track = switch ((isEnabled, value)) {
      (false, _) => colors.outline,
      (true, true) => colors.surfaceInverse,
      (true, false) => colors.outlineStrong,
    };

    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      child: PressFeedback(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        isButton: false,
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.curveFast,
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: track,
            borderRadius: AppRadius.borderFull,
          ),
          child: AnimatedAlign(
            duration: AppMotion.resolve(context, AppMotion.fast),
            curve: AppMotion.curveFast,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(_knobInset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: context.shadows.xs,
                ),
                child: const SizedBox.square(dimension: _knobSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _width = 44;
  static const double _height = 24;
  static const double _knobInset = 2;
  static const double _knobSize = _height - (_knobInset * 2);
}

/// A toggle with a label beside it, as the reference lays out both of its uses.
class AppToggleRow extends StatelessWidget {
  const AppToggleRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.trailing,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Rendered beside the toggle. Rich text so a terms line can carry emphasis.
  final Widget label;

  /// An action on the far right — "Forgot Password?" in the reference.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget toggleAndLabel = AppToggle(
      value: value,
      onChanged: onChanged,
      semanticLabel: _semanticLabelFrom(label),
    );

    if (trailing == null) {
      return Row(
        children: <Widget>[
          toggleAndLabel,
          const SizedBox(width: AppSpacing.space2),
          // Flexible so a two-line terms label wraps rather than overflowing at
          // 1.3x text scale.
          Flexible(child: label),
        ],
      );
    }

    // A [Wrap] rather than a [Row] once there is a trailing action. "Remember
    // me" beside "Forgot Password?" fits comfortably at 1x and overflows a
    // 320 px screen by about 90 px at 1.3x — a Row can only clip, while this
    // drops the trailing action onto a second line and keeps both readable.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            toggleAndLabel,
            const SizedBox(width: AppSpacing.space2),
            label,
          ],
        ),
        trailing!,
      ],
    );
  }

  /// Best-effort label for the toggle, from the text beside it.
  ///
  /// The toggle needs its own announcement, and the visible text is the
  /// truthful source for it.
  static String _semanticLabelFrom(Widget label) {
    if (label is Text) {
      return label.data ?? 'Toggle';
    }
    return 'Toggle';
  }
}
