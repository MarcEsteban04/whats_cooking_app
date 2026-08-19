import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// The success screen from the middle panel of
/// `docs/reference_design/login_reference.webp`.
///
/// A green circle with a white check, a light scatter of confetti behind it, a
/// centred headline and subtitle, and a near-black pill pinned at the bottom.
///
/// This is the one place green is a *fill* outside the SPIN button, and it is the
/// right one: docs/DESIGN_SYSTEM.md §2.4 gives `success` its own role, and the
/// check mark on top is white at over 4.5:1 on it.
class AuthSuccessSheet extends StatefulWidget {
  const AuthSuccessSheet({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  State<AuthSuccessSheet> createState() => _AuthSuccessSheetState();
}

class _AuthSuccessSheetState extends State<AuthSuccessSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.celebrate,
      vsync: this,
    );

    // Started in initState rather than on a post-frame callback: the sheet
    // replaces the form the moment sign-up returns, so the animation should
    // already be running when it first paints.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool reduceMotion = AppMotion.prefersReducedMotion(context);

    final Animation<double> entrance = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curveCelebrate,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenMargin,
            vertical: AppSpacing.space6,
          ),
          child: Column(
            children: <Widget>[
              const Spacer(),
              SizedBox.square(
                dimension: _celebrationSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (!reduceMotion)
                      // Suppressed under reduce-motion, per
                      // docs/DESIGN_SYSTEM.md §7: "confetti is suppressed".
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, Widget? child) {
                          return CustomPaint(
                            painter: _ConfettiPainter(
                              progress: _controller.value,
                              colors: <Color>[
                                colors.primaryBrand,
                                colors.peach.foreground,
                                colors.butter.foreground,
                                colors.lavender.foreground,
                                colors.coral.foreground,
                              ],
                            ),
                            size: const Size.square(_celebrationSize),
                          );
                        },
                      ),
                    ScaleTransition(
                      scale: reduceMotion
                          ? const AlwaysStoppedAnimation<double>(1)
                          : entrance,
                      child: const _SuccessCheck(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space7),
              Text(
                widget.title,
                style: context.text.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _messageMaxWidth),
                child: Text(
                  widget.message,
                  style: context.text.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              AppButton.inverse(
                label: widget.actionLabel,
                onPressed: widget.onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _celebrationSize = 160;
  static const double _messageMaxWidth = 280;
}

/// The green disc and its white check.
class _SuccessCheck extends StatelessWidget {
  const _SuccessCheck();

  @override
  Widget build(BuildContext context) {
    final AppSemanticColor success = context.colors.success;

    return Semantics(
      label: 'Success',
      child: DecoratedBox(
        decoration: BoxDecoration(color: success.color, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: _diameter,
          child: Center(
            child: Icon(
              AppIcons.check,
              size: AppIconSize.lg,
              color: success.onColor,
            ),
          ),
        ),
      ),
    );
  }

  static const double _diameter = 88;
}

/// A light scatter of confetti.
///
/// Deterministic: the positions come from a fixed seed, so the celebration looks
/// the same every time rather than occasionally landing badly. Drawn rather than
/// packaged — a dozen rotating rectangles do not justify a dependency.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  static const int _pieceCount = 28;
  static const double _pieceWidth = 4;
  static const double _pieceHeight = 9;

  @override
  void paint(Canvas canvas, Size size) {
    // A fixed seed, so this is a stable pattern and not a different one per
    // frame — the progress value alone animates it.
    final math.Random random = math.Random(_seed);
    final Offset centre = size.center(Offset.zero);
    final Paint paint = Paint();

    for (int index = 0; index < _pieceCount; index++) {
      final double angle = random.nextDouble() * math.pi * 2;
      final double maxDistance =
          (size.shortestSide / 2) * (0.55 + random.nextDouble() * 0.45);
      final double spin = random.nextDouble() * math.pi;

      // Each piece starts slightly later than the last, so the burst reads as a
      // spray rather than a ring expanding in lockstep.
      final double delay = index / (_pieceCount * 2);
      final double local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local == 0) {
        continue;
      }

      final double eased = Curves.easeOutCubic.transform(local);
      final Offset position =
          centre +
          Offset(math.cos(angle), math.sin(angle)) * (maxDistance * eased);

      // Fades over the second half, so the confetti settles instead of freezing
      // mid-air.
      paint.color = colors[index % colors.length].withValues(
        alpha: (1 - local).clamp(0.0, 1.0) * 0.9 + 0.1,
      );

      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(spin + eased * math.pi)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(
              -_pieceWidth / 2,
              -_pieceHeight / 2,
              _pieceWidth,
              _pieceHeight,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;

  static const int _seed = 20260820;
}
