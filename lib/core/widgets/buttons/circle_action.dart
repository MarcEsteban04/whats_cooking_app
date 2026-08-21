import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A circular action in a dashboard header's trailing slot.
///
/// The reference's `GC Global Connect / 37 Members ⌄` header carries two of these —
/// a settings and a member button — and every dashboard in this app follows it.
///
/// **Promoted from private copies in three screens.** Meals, the pantry and the
/// grocery list each grew their own `_CircleAction`, identical down to the shadow;
/// the restaurant library needed a fourth. Three copies is a coincidence and four
/// is a component, so this is the one.
///
/// Deliberately unlabelled on screen. A circle in a header is a guess unless the
/// glyph is obvious, which is why `DashboardActionRow` exists for anything that
/// needs a word — these are for the two or three actions whose icons genuinely
/// carry: search, add, close.
class AppCircleAction extends StatelessWidget {
  const AppCircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;

  /// What a screen reader says. Required, not optional: an icon-only control with
  /// no label is a control somebody using TalkBack cannot find.
  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: label,
      expandTouchTarget: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: context.shadows.sm,
        ),
        child: SizedBox.square(
          dimension: _size,
          child: Center(
            child: Icon(icon, size: AppIconSize.sm, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }

  /// Forty. The minimum touch target is 44 (docs/DESIGN_SYSTEM.md §11), which
  /// `PressFeedback` supplies around this — the circle itself is the visible part
  /// and is sized to sit level with a two-line header.
  static const double _size = 40;
}
