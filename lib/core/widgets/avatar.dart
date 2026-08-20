import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The avatar sizes from docs/COMPONENTS.md §16.
enum AvatarSize {
  /// Home header, list rows.
  small(32),

  /// Couple screen, member lists.
  medium(48),

  /// Profile header.
  large(96);

  const AvatarSize(this.diameter);

  final double diameter;

  /// Text style for the initials fallback, scaled to the circle.
  double get initialsSize => diameter * _initialsRatio;

  static const double _initialsRatio = 0.36;
}

/// A user's avatar (docs/COMPONENTS.md §16).
///
/// Circular, and **falls back to initials rather than to a generic silhouette**:
/// §16 specifies "initials in `titleMedium` on `primary100` with `primary800`
/// text". Most users never upload a photo, so the fallback is the common case and
/// deserves to look deliberate rather than absent.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.name,
    this.imageUrl,
    this.size = AvatarSize.medium,
    this.hasRing = false,
    super.key,
  });

  /// Used for the initials, and for the semantic label.
  final String name;

  /// Null or empty falls back to initials.
  final String? imageUrl;

  final AvatarSize size;

  /// A 2 px `surface` ring, for overlapping avatars (§16's CoupleAvatars).
  final bool hasRing;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final String? url = imageUrl;

    return Semantics(
      label: name.trim().isEmpty ? 'Profile photo' : name,
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
          border: hasRing
              ? Border.all(color: colors.surface, width: _ringWidth)
              : null,
        ),
        child: SizedBox.square(
          dimension: size.diameter,
          child: ClipOval(
            child: url == null || url.isEmpty
                ? _Initials(name: name, size: size)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    fadeInDuration: AppMotion.resolve(
                      context,
                      AppMotion.normal,
                    ),
                    // Initials both while loading and if it fails, so the circle
                    // never renders as a hole and never shifts size.
                    placeholder: (BuildContext context, String _) =>
                        _Initials(name: name, size: size),
                    errorWidget: (BuildContext context, String _, Object _) =>
                        _Initials(name: name, size: size),
                  ),
          ),
        ),
      ),
    );
  }

  static const double _ringWidth = 2;
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.size});

  final String name;
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          initialsFor(name),
          style: context.text.titleMedium.copyWith(
            color: colors.onPrimaryContainer,
            fontSize: size.initialsSize,
          ),
        ),
      ),
    );
  }

  /// Up to two initials from [name].
  ///
  /// Falls back to a food glyph rather than a letter for an empty name: a blank
  /// circle reads as broken, and "?" reads as an error.
  static String initialsFor(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '🍽️';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Exposed for tests and for anywhere initials are needed without the circle.
String avatarInitialsFor(String name) => _Initials.initialsFor(name);
