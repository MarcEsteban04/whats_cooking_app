import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The onboarding progress indicator (docs/COMPONENTS.md §18b).
///
/// A 4 px `radiusFull` track above a centred `metadata` counter — "Step 3 of 7".
///
/// **The counter is not decoration.** §18b: "A bar alone tells you how far along
/// you are but not how much remains in units you can reason about; *Step 3 of 7*
/// is what makes seven questions feel finite." The pair is announced **once**,
/// via the counter — the bar is excluded from semantics so a screen reader does
/// not read the same fact twice.
///
/// The fill is `primaryBrand`, the *identity* green rather than the interactive
/// one. §18b explains why that is correct here and nowhere else: the bar is not
/// tappable, so the 4.5:1 floor that governs interactive green does not apply,
/// and the identity colour makes the flow feel like part of the brand rather than
/// part of a form.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    required this.progress,
    required this.label,
    super.key,
  });

  /// 0 to 1.
  final double progress;

  /// The counter beneath the bar, e.g. "Step 3 of 7" or "All done".
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      children: <Widget>[
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: AppRadius.borderFull,
            child: SizedBox(
              height: _trackHeight,
              child: Stack(
                children: <Widget>[
                  ColoredBox(color: colors.surfaceMuted),
                  // A fraction rather than an animated width: the bar has to be
                  // correct at any width, and FractionallySizedBox keeps it so
                  // on a 320 px screen and a tablet alike.
                  AnimatedFractionallySizedBox(
                    duration: AppMotion.resolve(context, AppMotion.normal),
                    curve: AppMotion.curveNormal,
                    widthFactor: progress.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(color: colors.primaryBrand),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(label, style: context.text.metadata, textAlign: TextAlign.center),
      ],
    );
  }

  static const double _trackHeight = 4;
}
