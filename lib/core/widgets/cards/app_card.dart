import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// The four card treatments from docs/COMPONENTS.md §3.
enum AppCardVariant {
  /// The default: `radiusXl`, 24 padding, `shadowSm`.
  standard,

  /// Denser: `radiusMd`, 16 padding.
  compact,

  /// A hero surface: `radius2xl`, `shadowLg`, may carry imagery.
  feature,

  /// Raised above its neighbours: `shadowMd`.
  raised;

  double get radius => switch (this) {
    AppCardVariant.standard => AppRadius.xl,
    AppCardVariant.compact => AppRadius.md,
    AppCardVariant.feature => AppRadius.xxl,
    AppCardVariant.raised => AppRadius.xl,
  };

  double get padding => switch (this) {
    AppCardVariant.compact => AppLayout.cardPaddingCompact,
    _ => AppLayout.cardPadding,
  };
}

/// The foundational surface (docs/design_ui.md §34).
///
/// A white card with a large radius and a shadow you can barely see, floating
/// above the warm background. Borders are deliberately absent — elevation does
/// the separating, which is what keeps the interface from looking like a form.
///
/// Passing [onTap] makes the whole card a button: it gains press feedback and a
/// semantic button role.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.variant = AppCardVariant.standard,
    this.onTap,
    this.padding,
    this.semanticLabel,
    this.clipContent = false,
    super.key,
  });

  final Widget child;
  final AppCardVariant variant;

  /// Null leaves the card non-interactive.
  final VoidCallback? onTap;

  /// Overrides the variant's padding. [EdgeInsets.zero] for a card whose child
  /// paints to the edge, such as a meal card image.
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  /// Whether to clip the child to the card's radius. Needed whenever the child
  /// paints into a corner.
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(variant.radius);

    Widget content = Padding(
      padding: padding ?? EdgeInsets.all(variant.padding),
      child: child,
    );

    if (clipContent) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: borderRadius,
        boxShadow: _shadow(context),
      ),
      child: content,
    );

    if (onTap == null) {
      return surface;
    }

    return PressFeedback(
      onTap: onTap,
      semanticLabel: semanticLabel,
      // A card is already far larger than the minimum, and padding it out would
      // add stray space inside a list.
      expandTouchTarget: false,
      child: surface,
    );
  }

  List<BoxShadow> _shadow(BuildContext context) {
    final AppShadows shadows = context.shadows;

    return switch (variant) {
      AppCardVariant.standard => shadows.sm,
      AppCardVariant.compact => shadows.sm,
      AppCardVariant.feature => shadows.lg,
      AppCardVariant.raised => shadows.md,
    };
  }
}
