import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// The content shell for a bottom sheet (docs/COMPONENTS.md §9).
///
/// Sheets are used for filters, budget, cuisine selection, adding ingredients,
/// adding grocery items and household actions — docs/design_ui.md §37 is
/// explicit that a separate screen for every small configuration is the wrong
/// shape.
///
/// docs/NAVIGATION_MAP.md §9 makes sheets **routes**, not imperative calls, so
/// this widget deliberately offers no `show()` helper: Sprint 09 registers them
/// as GoRouter pages, which keeps the back button and deep links working.
///
/// The handle, radius, scrim and elevation all come from `bottomSheetTheme`;
/// this supplies the padding, the title block and the pinned action.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.isScrollable = true,
    super.key,
  });

  final Widget child;

  /// `titleLarge`, left aligned.
  final String? title;

  /// `bodySmall` on `textSecondary`, beneath the title.
  final String? subtitle;

  /// A confirming action, pinned full width above the safe area.
  final Widget? action;

  /// Whether the body scrolls when it outgrows the sheet.
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return ConstrainedBox(
      // §9: at most 90% of the screen, so the sheet always reads as a layer
      // over the app rather than as a new screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFraction,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppLayout.screenMargin,
          right: AppLayout.screenMargin,
          top: AppSpacing.space2,
          // The safe area is added rather than replaced: a home-indicator
          // device needs both the design's 24 and the inset.
          bottom: AppSpacing.space6 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(title!, style: context.text.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space1),
                Text(
                  subtitle!,
                  style: context.text.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space5),
            ],
            Flexible(
              child: isScrollable ? SingleChildScrollView(child: child) : child,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space5),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  static const double _maxHeightFraction = 0.9;
}
