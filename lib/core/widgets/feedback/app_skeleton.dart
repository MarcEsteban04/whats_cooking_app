import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// A shimmering placeholder (docs/COMPONENTS.md §11).
///
/// Base `neutral100`, highlight `neutral200`, sweeping left-to-right over
/// 1200 ms with an 800 ms pause. Never a full-screen spinner
/// (docs/design_ui.md §30).
///
/// The rule that matters is one line of the spec: "Every list has a matching
/// skeleton that **mirrors its real layout** — same card heights, same gaps — so
/// nothing shifts when content arrives. A skeleton that doesn't match its
/// content is worse than none." That is why this is a primitive with a settable
/// radius and size rather than a single canned card shape: the caller builds the
/// skeleton to match its own layout.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.widthFactor = 1,
    super.key,
  });

  /// A text line: 12 px tall at `radiusXs`, optionally narrowed.
  ///
  /// The final line of a paragraph is conventionally 60% wide, which is what
  /// makes a block of them read as text rather than as bars.
  const AppSkeleton.textLine({this.widthFactor = 1, super.key})
    : width = null,
      height = _textLineHeight,
      borderRadius = AppRadius.borderXs,
      shape = BoxShape.rectangle;

  /// A circle, for avatar placeholders.
  const AppSkeleton.circle({required double diameter, Key? key})
    : this(width: diameter, height: diameter, shape: BoxShape.circle, key: key);

  /// Null fills the available space, which is what an image placeholder wants.
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  /// A fraction of the available width. 0.6 for the closing line of a text
  /// block, which is what makes a stack of lines read as a paragraph.
  final double widthFactor;

  static const double _textLineHeight = 12;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Duration _sweep = Duration(milliseconds: 1200);
  static const Duration _pause = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    // The pause is folded into the cycle rather than scheduled with a timer:
    // one controller running over sweep+pause, with the sweep occupying the
    // first fraction of it, cannot drift out of step with itself.
    _controller = AnimationController(duration: _sweep + _pause, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final Widget base = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.skeletonBase,
        borderRadius: widget.shape == BoxShape.circle
            ? null
            : (widget.borderRadius ?? AppRadius.borderMd),
        shape: widget.shape,
      ),
    );

    // Reduce-motion keeps the placeholder but drops the sweep: the shimmer is
    // decoration, the placeholder is information.
    if (AppMotion.prefersReducedMotion(context)) {
      return _sized(base);
    }

    return _sized(
      AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double sweepFraction =
              _sweep.inMilliseconds / (_sweep + _pause).inMilliseconds;
          // Beyond the sweep the gradient is parked off-screen, which is the
          // pause.
          final double progress = (_controller.value / sweepFraction).clamp(
            0.0,
            1.0,
          );

          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  colors.skeletonBase,
                  colors.skeletonHighlight,
                  colors.skeletonBase,
                ],
                stops: const <double>[0, 0.5, 1],
                transform: _SweepTransform(progress),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: base,
      ),
    );
  }

  Widget _sized(Widget child) {
    Widget result = child;

    if (widget.width != null || widget.height != null) {
      result = SizedBox(
        width: widget.width,
        height: widget.height,
        child: result,
      );
    }
    if (widget.widthFactor != 1) {
      result = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.widthFactor,
        child: result,
      );
    }

    return result;
  }
}

/// Slides a gradient from fully off the left to fully off the right.
class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double dx = bounds.width * (progress * 2 - 1);
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// The inline indicator from docs/COMPONENTS.md §11.
///
/// 20 px, 2 px stroke, `primary`. Used inside buttons and for pagination
/// footers only — anywhere else, a skeleton is the right answer.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({this.size = AppIconSize.sm, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: _stroke,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? context.colors.primary,
          ),
        ),
      ),
    );
  }

  static const double _stroke = 2;
}
