import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The card that stands in while the assistant is choosing (Sprint 53e).
///
/// **Because the reel was showing an answer it did not have yet.** Making the AI
/// the decider meant holding the roll until it replies, and during that hold the
/// reel rendered its pool at offset zero — so a meal sat in the landing slot,
/// looking exactly like a result, for up to four seconds before the wheel moved.
/// Worse, it was usually the *engine's* pick, which the assistant was in the
/// middle of overruling. A screen that shows one meal and then rolls to a
/// different one has told a small lie twice.
///
/// So nothing nameable is shown until there is something to name. Same footprint
/// as a reel window, so the layout does not jump when the roll takes over.
class PickingCard extends StatefulWidget {
  const PickingCard({super.key});

  @override
  State<PickingCard> createState() => _PickingCardState();
}

class _PickingCardState extends State<PickingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // Reduced motion gets a still card. The pulse is reassurance, not
    // information, so removing it costs nothing (docs/DESIGN_SYSTEM.md §7).
    final bool isStill = AppMotion.prefersReducedMotion(context);
    if (isStill) {
      _pulse.stop();
    }

    return SizedBox(
      height: _windowHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.borderXxl,
            border: Border.all(color: colors.outline),
            boxShadow: context.shadows.md,
          ),
          child: SizedBox(
            height: _cardHeight,
            width: double.infinity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'PICKING',
                    style: context.text.overline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  // Three bars where the name, the cuisine and the metadata will
                  // be. A skeleton rather than a spinner, because it says *what
                  // is coming* as well as that something is — and the card that
                  // replaces it lands in the same three lines.
                  _Bar(pulse: _pulse, isStill: isStill, width: _shortBar),
                  const SizedBox(height: AppSpacing.space3),
                  _Bar(pulse: _pulse, isStill: isStill, width: _longBar),
                  const SizedBox(height: AppSpacing.space3),
                  _Bar(pulse: _pulse, isStill: isStill, width: _mediumBar),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The reel's own window and card heights, so the roll takes over without the
  /// column shifting under the reader.
  static const double _windowHeight = 300;
  static const double _cardHeight = 156;

  static const double _shortBar = 72;
  static const double _longBar = 168;
  static const double _mediumBar = 116;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.pulse, required this.isStill, required this.width});

  final Animation<double> pulse;
  final bool isStill;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: AppRadius.borderXs,
      ),
      child: SizedBox(width: width, height: _height),
    );

    if (isStill) {
      return bar;
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(pulse),
      child: bar,
    );
  }

  static const double _height = 12;
}
