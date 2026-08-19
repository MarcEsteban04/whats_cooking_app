import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The press interaction every tappable surface in the app shares.
///
/// docs/DESIGN_SYSTEM.md §7 replaces Material's ink ripple with a scale: down to
/// [AppMotion.pressScale] over [AppMotion.pressIn], back over
/// [AppMotion.pressOut]. Doing it in one place is what stops nine components
/// each inventing a slightly different feel.
///
/// It also enforces two of the universal requirements from docs/COMPONENTS.md:
/// a touch target of at least [AppLayout.minTouchTarget] regardless of how small
/// the visual is, and a disabled state that is excluded from the semantics tree
/// as tappable rather than merely painted grey.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.semanticLabel,
    this.semanticHint,
    this.isButton = true,
    this.minTouchTarget = AppLayout.minTouchTarget,
    this.expandTouchTarget = true,
    super.key,
  });

  final Widget child;

  /// Null disables the control.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the surface scales while held.
  final double scale;

  /// Required for icon-only controls (docs/DESIGN_SYSTEM.md §11).
  final String? semanticLabel;
  final String? semanticHint;

  /// Whether to announce this as a button. False for whole-card taps that
  /// already carry a richer label.
  final bool isButton;

  final double minTouchTarget;

  /// Whether to pad the hit area out to [minTouchTarget].
  ///
  /// Off for surfaces that are already comfortably large — a meal card does not
  /// need a minimum, and padding one would add stray space inside a list.
  final bool expandTouchTarget;

  bool get isEnabled => onTap != null || onLongPress != null;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.isEnabled;
    final bool shouldScale = _isPressed && isEnabled;

    Widget result = AnimatedScale(
      scale: shouldScale ? widget.scale : 1,
      // Reduce-motion removes the scale but keeps the control fully functional
      // (docs/DESIGN_SYSTEM.md §7).
      duration: AppMotion.resolve(
        context,
        shouldScale ? AppMotion.pressIn : AppMotion.pressOut,
      ),
      curve: AppMotion.curveFast,
      child: widget.child,
    );

    if (widget.expandTouchTarget) {
      result = _MinimumTouchTarget(
        minimum: widget.minTouchTarget,
        child: result,
      );
    }

    result = GestureDetector(
      onTap: isEnabled ? widget.onTap : null,
      onLongPress: isEnabled ? widget.onLongPress : null,
      onTapDown: isEnabled ? (TapDownDetails _) => _setPressed(true) : null,
      onTapUp: isEnabled ? (TapUpDetails _) => _setPressed(false) : null,
      onTapCancel: isEnabled ? () => _setPressed(false) : null,
      // Opaque so the padded-out area is part of the target, not a dead zone.
      behavior: HitTestBehavior.opaque,
      child: result,
    );

    return Semantics(
      button: widget.isButton,
      enabled: isEnabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      // A disabled control must not read as tappable, however it looks.
      excludeSemantics: widget.semanticLabel != null,
      child: result,
    );
  }
}

/// Grows its hit area to [minimum] without growing the visual.
///
/// A 36 px heart on a meal card stays 36 px and gains a 48 px target — the
/// alternative, sizing the visual up to the target, is how a design ends up with
/// oversized controls purely to satisfy an accessibility rule.
///
/// The `widthFactor`/`heightFactor` of 1 make [Align] shrink-wrap its child; the
/// surrounding minimum constraints then lift that result to [minimum] when the
/// child is smaller, and leave it alone when it is not.
class _MinimumTouchTarget extends StatelessWidget {
  const _MinimumTouchTarget({required this.minimum, required this.child});

  final double minimum;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minimum, minHeight: minimum),
      child: Align(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
