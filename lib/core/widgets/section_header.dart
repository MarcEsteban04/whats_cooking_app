import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// A section heading (docs/COMPONENTS.md §17).
///
/// Title in `titleLarge`, an optional trailing text action, and an optional
/// subtitle between the title and the content. The spacing — 32 above, 16 below —
/// is the section gap from docs/DESIGN_SYSTEM.md §4, applied here so screens do
/// not each decide it.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.hasTopSpacing = true,
    super.key,
  });

  final String title;

  /// Sits between the title and the content, in `bodySmall`.
  final String? subtitle;

  /// A trailing text action — "See all", "Edit".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Off for the first header on a screen, which already has the screen's own
  /// top padding above it.
  final bool hasTopSpacing;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasTopSpacing) const SizedBox(height: AppLayout.sectionGap),
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: context.text.titleLarge)),
            if (actionLabel != null && onAction != null)
              AppButton.tertiary(
                label: actionLabel!,
                size: AppButtonSize.small,
                onPressed: onAction,
              ),
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.space1),
          Text(
            subtitle!,
            style: context.text.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.space4),
      ],
    );
  }
}
