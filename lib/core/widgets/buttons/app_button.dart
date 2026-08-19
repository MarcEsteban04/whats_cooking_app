import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// The five button roles from docs/COMPONENTS.md §1.
enum AppButtonVariant {
  /// The one main action per screen.
  primary,

  /// Alternative actions.
  secondary,

  /// Low-emphasis, inline.
  tertiary,

  /// Delete, leave household, remove.
  destructive,

  /// SPIN only. Brand green with dark text.
  brand,
}

/// The three button sizes from docs/COMPONENTS.md §1.
enum AppButtonSize {
  large(height: 56, horizontalPadding: AppSpacing.space7),
  medium(height: 48, horizontalPadding: AppSpacing.space6),
  small(height: 40, horizontalPadding: AppSpacing.space4);

  const AppButtonSize({required this.height, required this.horizontalPadding});

  final double height;
  final double horizontalPadding;

  double get iconSize => switch (this) {
    AppButtonSize.large => AppIconSize.md,
    AppButtonSize.medium => AppIconSize.sm,
    AppButtonSize.small => AppIconSize.xs,
  };
}

/// The application's button.
///
/// docs/design_ui.md §36: the primary CTA is the strongest element on any screen
/// it appears on. `large` is the default because that is the size the reference
/// uses for a screen's main action.
///
/// Every variant is a pill ([AppRadius.full]) and takes its press feedback from
/// [PressFeedback], so a button feels the same wherever it appears.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  });

  /// The primary action, at the default size.
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  }) : variant = AppButtonVariant.primary;

  /// An alternative action, quieter than [AppButton.primary].
  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  /// A low-emphasis, inline action.
  const AppButton.tertiary({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  }) : variant = AppButtonVariant.tertiary;

  /// An action that removes something. Always names the consequence.
  const AppButton.destructive({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  }) : variant = AppButtonVariant.destructive;

  /// SPIN, and nothing else.
  ///
  /// The brand green carries dark text at 4.81:1. It is reserved for the
  /// signature action so that seeing it means exactly one thing.
  const AppButton.brand({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
    super.key,
  }) : variant = AppButtonVariant.brand;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  /// Overrides the announced label where [label] alone is not descriptive.
  final String? semanticLabel;

  /// A loading button is not tappable, whatever was passed in.
  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final _ButtonPalette palette = _paletteFor(colors);

    final Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: size.horizontalPadding),
      child: _AppButtonContent(
        label: label,
        size: size,
        foreground: palette.foreground,
        textStyle: _textStyle(context),
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon,
        isLoading: isLoading,
        isFullWidth: isFullWidth,
      ),
    );

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadius.borderFull,
        border: palette.border == null
            ? null
            : Border.fromBorderSide(palette.border!),
        // §1: shadow on `primary` and `brand` only, and never while disabled.
        boxShadow: palette.hasShadow ? context.shadows.sm : null,
      ),
      child: SizedBox(
        height: size.height,
        width: isFullWidth ? double.infinity : null,
        child: content,
      ),
    );

    return PressFeedback(
      onTap: _isEnabled ? onPressed : null,
      scale: AppMotion.pressScaleButton,
      semanticLabel: semanticLabel ?? label,
      // Loading is announced rather than left to the spinner, which a screen
      // reader cannot see.
      semanticHint: isLoading ? 'Loading' : null,
      minTouchTarget: AppLayout.minTouchTarget,
      child: isFullWidth
          ? SizedBox(width: double.infinity, child: surface)
          : surface,
    );
  }

  TextStyle _textStyle(BuildContext context) {
    return size == AppButtonSize.small
        ? context.text.labelSmall
        : context.text.label;
  }

  _ButtonPalette _paletteFor(AppColorScheme colors) {
    if (!_isEnabled) {
      // One disabled treatment for every variant (§1). A disabled destructive
      // button that still reads as dangerous is a needless second signal.
      return _ButtonPalette(
        // A tertiary button has no fill to grey out, so it stays unfilled.
        background: variant == AppButtonVariant.tertiary
            ? null
            : colors.outline,
        foreground: colors.textDisabled,
      );
    }

    return switch (variant) {
      AppButtonVariant.primary => _ButtonPalette(
        background: colors.primary,
        foreground: colors.textOnPrimary,
        hasShadow: true,
      ),
      AppButtonVariant.secondary => _ButtonPalette(
        background: colors.surface,
        foreground: colors.textPrimary,
        border: BorderSide(color: colors.outline),
      ),
      AppButtonVariant.tertiary => _ButtonPalette(foreground: colors.primary),
      AppButtonVariant.destructive => _ButtonPalette(
        background: colors.error.color,
        foreground: colors.error.onColor,
      ),
      AppButtonVariant.brand => _ButtonPalette(
        background: colors.primaryBrand,
        foreground: colors.onPrimaryBrand,
        hasShadow: true,
      ),
    };
  }
}

@immutable
class _ButtonPalette {
  const _ButtonPalette({
    required this.foreground,
    this.background,
    this.border,
    this.hasShadow = false,
  });

  /// Null paints no fill at all, which is how `tertiary` stays transparent
  /// without naming a colour literal outside the theme layer.
  final Color? background;
  final Color foreground;
  final BorderSide? border;
  final bool hasShadow;
}

/// The label, its optional icons, and the loading indicator that replaces them.
///
/// docs/COMPONENTS.md §1: "Width must not change on entering the loading state —
/// a button that resizes under the thumb causes mis-taps." A [Stack] holding
/// both layers is what keeps the width: the label stays laid out and merely
/// invisible, so the button measures the same either way.
class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.size,
    required this.foreground,
    required this.textStyle,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.isLoading,
    required this.isFullWidth,
  });

  final String label;
  final AppButtonSize size;
  final Color foreground;
  final TextStyle textStyle;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget labelRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          Icon(leadingIcon, size: size.iconSize, color: foreground),
          const SizedBox(width: AppSpacing.space2),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle.copyWith(color: foreground),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: AppSpacing.space2),
          Icon(trailingIcon, size: size.iconSize, color: foreground),
        ],
      ],
    );

    if (!isLoading) {
      return _align(labelRow);
    }

    return _align(
      Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Holds the width, contributes nothing to semantics or paint.
          Opacity(opacity: 0, child: ExcludeSemantics(child: labelRow)),
          SizedBox.square(
            dimension: _indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: _indicatorStroke,
              // The indicator takes the text colour so it reads as the label's
              // replacement rather than as a separate element (§11).
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          ),
        ],
      ),
    );
  }

  /// Centres the content only when the button spans its parent.
  ///
  /// A [Center] applied unconditionally makes the button expand to fill the
  /// available width, which silently turns every button into a full-width one.
  Widget _align(Widget child) => isFullWidth ? Center(child: child) : child;

  static const double _indicatorSize = AppIconSize.sm;
  static const double _indicatorStroke = 2;
}
