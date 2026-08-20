import 'package:flutter/material.dart';

/// The product mark.
///
/// **The one full-colour thing in the app, and deliberately so.** The palette is
/// ink on warm white with a single terracotta accent
/// (docs/DESIGN_SYSTEM.md §2.2), and this mark is green, yellow, white and red.
/// That is not an inconsistency to fix: a logo is a fixed thing that belongs to
/// the product rather than to the interface, and repainting it to match a theme
/// stops it being a logo. The same reasoning is why the launcher icon is
/// full-colour while every glyph inside the app is not.
///
/// **It contains the words "What's Cooking?".** So anywhere this appears, the app
/// name should not appear beside it — a wordmark next to its own wording reads as
/// a mistake. That is the one rule this widget cannot enforce for itself, so it
/// is written here.
///
/// Sized deliberately at each call site rather than defaulting: a wordmark is
/// illegible small, and a 36 px version of this would be a coloured smudge. If a
/// mark is wanted at that size, use two initials or a glyph instead.
class BrandLogo extends StatelessWidget {
  const BrandLogo({required this.height, this.semanticLabel, super.key});

  /// How tall to draw it.
  ///
  /// Height only. The trimmed mark is very slightly taller than it is wide, and
  /// constraining both axes to the same number would squash it by a couple of
  /// per cent — the sort of distortion nobody can name and everybody notices.
  final double height;

  /// What a screen reader says.
  ///
  /// Null makes it decorative, which is right wherever the surrounding copy
  /// already names the product — and wrong on a screen where this *is* the
  /// heading.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      _asset,
      height: height,
      // Contained rather than covered: the mark has transparent margins of its
      // own, and cropping a logo to fill a box is how a cloche loses its lid.
      fit: BoxFit.contain,
      // The bundled asset is 512 px and every use is a downscale of it, where the
      // default leaves the thin highlights on the cutlery aliased.
      filterQuality: FilterQuality.medium,
    );

    if (semanticLabel case final String label) {
      return Semantics(label: label, image: true, child: image);
    }
    return ExcludeSemantics(child: image);
  }

  static const String _asset = 'assets/brand/logo.png';
}
