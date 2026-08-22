import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/swipe_action.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';

/// One row of a meal list: swipeable, and a checkbox once selecting has started.
///
/// **Long-press to begin, tap to add or remove.** A permanent row of checkboxes
/// turns a list you read into a form you fill in, and these lists are mostly
/// read — so the selection only appears once somebody has asked for it. Until
/// then a tap opens the meal, which is what a row of a list does everywhere else.
///
/// **Right to edit, left to delete**, matching the kitchen and the shopping list.
/// One gesture across every list in the app is the only version of it worth
/// having: a row that swipes on one screen and not on the next teaches nothing.
/// Edit does not dismiss — `confirmDismiss` returns false so the row springs
/// back, which is the truthful animation for an action that leaves the row where
/// it was.
///
/// Both swipes are suppressed while selecting. A batch delete is already in
/// progress conceptually, and a stray drag removing a *different* meal than the
/// ones ticked is the worst thing this row could do.
class SelectableMealRow extends StatelessWidget {
  const SelectableMealRow({
    required this.meal,
    required this.isSelected,
    required this.isSelecting,
    required this.isBusy,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final Meal meal;
  final bool isSelected;
  final bool isSelecting;
  final bool isBusy;
  final VoidCallback onToggle;

  /// Null where swiping is not offered — which is nowhere now, but the row is
  /// shared and a caller that cannot delete should not draw a red panel.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final Widget row = MealTableRow(meal: meal);

    final Widget selectable = GestureDetector(
      // Opaque, so a tap anywhere on the row counts rather than only on its text.
      behavior: HitTestBehavior.opaque,
      onLongPress: isBusy ? null : onToggle,
      // While selecting, a tap toggles rather than navigating — otherwise a
      // mis-tap during a bulk delete opens a meal and loses the whole selection.
      onTap: isSelecting && !isBusy ? onToggle : null,
      child: Row(
        children: <Widget>[
          if (isSelecting) ...<Widget>[
            // The same square the fridge scan and the list import use, because
            // this is the third confirmation list in the app and a third shape
            // would read as a third product.
            DecoratedBox(
              decoration: BoxDecoration(
                color: isSelected ? colors.surfaceInverse : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colors.surfaceInverse
                      : colors.outlineStrong,
                  width: _boxBorder,
                ),
                borderRadius: AppRadius.borderSm,
              ),
              child: SizedBox.square(
                dimension: _boxSize,
                child: isSelected
                    ? Icon(
                        AppIcons.check,
                        size: _tickSize,
                        color: colors.textOnInverse,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
          ],
          // `IgnorePointer` while selecting, so the row's own heart and its tap
          // target do not compete with the selection underneath them.
          Expanded(child: IgnorePointer(ignoring: isSelecting, child: row)),
        ],
      ),
    );

    final bool canSwipe =
        !isSelecting && !isBusy && (onEdit != null || onDelete != null);

    if (!canSwipe) {
      return selectable;
    }

    return Dismissible(
      key: ValueKey<String>('swipe-${meal.id}'),
      direction: switch ((onEdit, onDelete)) {
        (null, _) => DismissDirection.endToStart,
        (_, null) => DismissDirection.startToEnd,
        _ => DismissDirection.horizontal,
      },
      background: onEdit == null
          ? null
          : AppSwipeAction(
              alignment: Alignment.centerLeft,
              icon: AppIcons.edit,
              tone: colors.info,
            ),
      secondaryBackground: onDelete == null
          ? null
          : AppSwipeAction(
              alignment: Alignment.centerRight,
              icon: AppIcons.delete,
              tone: colors.error,
            ),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit?.call();
          return false;
        }

        // **Also false, and this one is not obvious.** The delete goes through a
        // confirmation and can be refused outright — `meal_history` will not let
        // go of a meal that has been eaten — so the row must not vanish on the
        // gesture. The caller deletes, the list reloads, and the row leaves
        // because it is gone rather than because it was swiped.
        onDelete?.call();
        return false;
      },
      child: selectable,
    );
  }

  static const double _boxSize = 18;
  static const double _boxBorder = 1.5;
  static const double _tickSize = 16;
}
