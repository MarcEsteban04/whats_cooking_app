import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/app_colors.dart';

/// Elevation tokens from docs/DESIGN_SYSTEM.md §6.
///
/// Large blur, very low opacity, no visible edge — the floating-card look of the
/// reference comes from shadows you cannot quite see. The shadow colour is
/// always the warm `neutral900`, never pure black; black shadows over a warm
/// background read as grey smudges.
///
/// **In dark mode every token resolves to an empty list.** Shadows are invisible
/// on a dark ground, so elevation is carried by `surface` → `surfaceMuted` →
/// `surfaceHigh` instead. §6 is explicit that Sprint 07 must branch on
/// brightness rather than reuse the light list at a lower alpha, which is why
/// this is a [ThemeExtension] and not a set of constants.
@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.scrim,
  });

  /// The light set.
  factory AppShadows.light() {
    return AppShadows(
      xs: _shadow(dy: 1, blur: 2, spread: 0, alpha: 0.04),
      sm: _shadow(dy: 2, blur: 8, spread: 0, alpha: 0.05),
      md: _shadow(dy: 4, blur: 16, spread: -2, alpha: 0.06),
      lg: _shadow(dy: 8, blur: 28, spread: -4, alpha: 0.08),
      xl: _shadow(dy: 16, blur: 40, spread: -8, alpha: 0.10),
      scrim: AppColors.neutral900.withValues(
        alpha: AppColors.scrimOpacityLight,
      ),
    );
  }

  /// The dark set: no shadows at all.
  factory AppShadows.dark() {
    return AppShadows(
      xs: const <BoxShadow>[],
      sm: const <BoxShadow>[],
      md: const <BoxShadow>[],
      lg: const <BoxShadow>[],
      xl: const <BoxShadow>[],
      scrim: AppColors.neutral900.withValues(alpha: AppColors.scrimOpacityDark),
    );
  }

  /// Chips, small pills.
  final List<BoxShadow> xs;

  /// Standard cards, text fields.
  final List<BoxShadow> sm;

  /// Raised cards, floating badges.
  final List<BoxShadow> md;

  /// Bottom navigation, feature cards.
  final List<BoxShadow> lg;

  /// Sheets, dialogs, the roulette card.
  final List<BoxShadow> xl;

  /// Scrim behind sheets and dialogs.
  final Color scrim;

  static List<BoxShadow> _shadow({
    required double dy,
    required double blur,
    required double spread,
    required double alpha,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: AppColors.neutral900.withValues(alpha: alpha),
        offset: Offset(0, dy),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  @override
  AppShadows copyWith({
    List<BoxShadow>? xs,
    List<BoxShadow>? sm,
    List<BoxShadow>? md,
    List<BoxShadow>? lg,
    List<BoxShadow>? xl,
    Color? scrim,
  }) {
    return AppShadows(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppShadows lerp(covariant AppShadows? other, double t) {
    if (other == null) {
      return this;
    }
    return AppShadows(
      xs: BoxShadow.lerpList(xs, other.xs, t)!,
      sm: BoxShadow.lerpList(sm, other.sm, t)!,
      md: BoxShadow.lerpList(md, other.md, t)!,
      lg: BoxShadow.lerpList(lg, other.lg, t)!,
      xl: BoxShadow.lerpList(xl, other.xl, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
