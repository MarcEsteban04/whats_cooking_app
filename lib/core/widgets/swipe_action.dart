import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// What a row reveals as it is swiped.
///
/// **Its own widget because two lists grew the same fifteen lines** — the kitchen
/// and the shopping list both draw a coloured panel with one glyph pinned to the
/// edge the swipe came from, and both now do it twice each (edit one way, delete
/// the other). Four copies of a shape is where the shapes start to diverge.
///
/// The colour is the whole point of it. A grey affordance behind a row says
/// something is happening; a red one says *this deletes* before the finger has
/// committed, which is the only moment that warning is useful.
class AppSwipeAction extends StatelessWidget {
  const AppSwipeAction({
    required this.alignment,
    required this.icon,
    required this.tone,
    super.key,
  });

  /// Which edge the glyph sits against — the edge the swipe started from, so it
  /// appears under the thumb rather than running away from it.
  final Alignment alignment;

  final IconData icon;

  /// `colors.error` for a delete, `colors.info` for an edit.
  final AppSemanticColor tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.color,
        borderRadius: AppRadius.borderMd,
      ),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Icon(icon, color: tone.onColor, size: AppIconSize.sm),
        ),
      ),
    );
  }
}
