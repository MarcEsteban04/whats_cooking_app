import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A selectable row (docs/COMPONENTS.md §18b).
///
/// In `core/widgets/preferences/` because §18b puts it there: onboarding
/// introduced it and the profile screen shares it, and "a user must meet the
/// same cuisine grid on day one and on day thirty".
///
/// **Selection is carried by the border and the mark, not by flooding the tile
/// with colour.** §18b calls that out as "the same mistake the first pass at this
/// design system made" — a screen of filled cards loses the hierarchy that makes
/// the chosen one obvious.
///
/// Used where the answers are few and each deserves reading — budget, cooking
/// time, who you cook for. Where the answer set is large and multi-select, a chip
/// row is the right shape instead: a chip row reads as "pick several from many"
/// and a tile list reads as "pick one, and read it properly".
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    required this.title,
    required this.isSelected,
    required this.onSelected,
    this.caption,
    this.icon,
    super.key,
  });

  final String title;

  /// The supporting line, in `metadata`.
  final String? caption;

  /// A leading icon, shown in the tinted square.
  ///
  /// An icon rather than an emoji. Emoji are somebody else's artwork: they
  /// arrive full-colour, they render differently on every platform, and next to
  /// a monochrome palette they read as clip art dropped into a design system.
  /// A themed glyph inherits the ink and stays consistent.
  final IconData? icon;

  final bool isSelected;

  /// Null disables the tile.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isEnabled = onSelected != null;

    return PressFeedback(
      onTap: onSelected,
      semanticLabel: caption == null ? title : '$title. $caption',
      semanticHint: isSelected ? 'Selected' : 'Not selected',
      expandTouchTarget: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            // 2 px primary when selected, 1 px outline otherwise (§18b). The
            // border does the work that a colour flood would otherwise do.
            color: isSelected ? colors.primary : colors.outline,
            width: isSelected ? _selectedBorder : _border,
          ),
        ),
        child: Padding(
          // Constant, and it has to be. A [DecoratedBox] paints its border
          // *over* the child without reserving space for it, so the 1 px to 2 px
          // change on selection costs no layout — compensating for it would
          // introduce exactly the 1 px shift the compensation was meant to
          // prevent.
          padding: const EdgeInsets.all(AppSpacing.space3),
          child: Row(
            children: <Widget>[
              if (icon case final IconData glyph) ...<Widget>[
                _LeadingSquare(icon: glyph, isSelected: isSelected),
                const SizedBox(width: AppSpacing.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.text.titleSmall.copyWith(
                        color: isEnabled
                            ? colors.textPrimary
                            : colors.textDisabled,
                      ),
                    ),
                    if (caption != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.space1),
                      Text(caption!, style: context.text.metadata),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              _SelectionMark(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }

  static const double _border = 1;
  static const double _selectedBorder = 2;
}

/// The 44 px tinted square holding the icon.
class _LeadingSquare extends StatelessWidget {
  const _LeadingSquare({required this.icon, required this.isSelected});

  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? colors.primaryContainer : colors.surfaceMuted,
        borderRadius: AppRadius.borderSm,
      ),
      child: SizedBox.square(
        dimension: _size,
        child: Center(
          child: Icon(
            icon,
            size: AppIconSize.sm,
            // Follows the ink rather than carrying a colour of its own. The
            // tile's label already says what it is; the glyph is there to be
            // recognised at a glance, not to be looked at.
            color: isSelected
                ? colors.onPrimaryContainer
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  static const double _size = 44;
}

/// The 24 px selection mark.
///
/// It occupies its space whether or not it is selected (§18b), so choosing an
/// option does not shift the text beside it — the kind of jitter that makes a
/// list of options feel unfinished.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return SizedBox.square(
      dimension: _size,
      child: isSelected
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  AppIcons.check,
                  size: _checkSize,
                  color: colors.textOnPrimary,
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.outlineStrong, width: 1.5),
              ),
            ),
    );
  }

  static const double _size = 24;
  static const double _checkSize = 16;
}
