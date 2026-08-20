import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// What the sheet is reporting.
enum AuthSheetTone {
  /// Something finished. Green disc, check mark, confetti.
  celebrate,

  /// Something is waiting on the user. Same layout, no celebration.
  awaiting,
}

/// The success screen from the middle panel of
/// `docs/reference_design/login_reference.webp`.
///
/// A green circle with a white check, a light scatter of confetti behind it, a
/// centred headline and subtitle, and a near-black pill pinned at the bottom.
///
/// This is the one place green is a *fill* outside the SPIN button, and it is the
/// right one: docs/DESIGN_SYSTEM.md §2.4 gives `success` its own role, and the
/// check mark on top is white at over 4.5:1 on it.
///
/// [AuthSheetTone.awaiting] reuses the same layout without the celebration. The
/// arrangement is right for any "here is what just happened, here is the one
/// thing to do next" moment; the confetti is right for exactly one of them.
class AuthSuccessSheet extends StatefulWidget {
  const AuthSuccessSheet({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.tone = AuthSheetTone.celebrate,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final AuthSheetTone tone;

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
                    if (!reduceMotion && widget.tone == AuthSheetTone.celebrate)
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
                      child: _Emblem(tone: widget.tone),
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

/// The disc at the top of the sheet.
///
/// Green with a white check when something finished; the butter pastel with a
/// mail glyph when the user still has something to do. The pastel is the right
/// choice for the waiting state because it is the one palette role that reads as
/// "attention, not alarm" — an amber warning colour would imply something went
/// wrong, and nothing has (docs/DESIGN_SYSTEM.md §2.3).
class _Emblem extends StatelessWidget {
  const _Emblem({required this.tone});

  final AuthSheetTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final (
      Color background,
      Color foreground,
      IconData icon,
      String label,
    ) = switch (tone) {
      AuthSheetTone.celebrate => (
        colors.success.color,
        colors.success.onColor,
        AppIcons.check,
        'Success',
      ),
      AuthSheetTone.awaiting => (
        colors.butter.background,
        colors.butter.foreground,
        AppIcons.mail,
        'Waiting for you',
      ),
    };

    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: _diameter,
          child: Center(
            child: Icon(icon, size: AppIconSize.lg, color: foreground),
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
