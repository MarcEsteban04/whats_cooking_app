import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/widgets/meal_table_row.dart';

/// One row of the list, which doubles as a checkbox once selecting has started.
///
/// **Long-press to begin, tap to add or remove.** A permanent row of checkboxes
/// turns a list you read into a form you fill in, and this list is mostly read —
/// so the selection only appears once somebody has asked for it. Until then a tap
/// opens the meal, which is what a row of a list does everywhere else in the app.
class SelectableMealRow extends StatelessWidget {
  const SelectableMealRow({
    required this.meal,
    required this.isSelected,
    required this.isSelecting,
    required this.isBusy,
    required this.onToggle,
    super.key,
  });

  final Meal meal;
  final bool isSelected;
  final bool isSelecting;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final Widget row = MealTableRow(meal: meal);

    return GestureDetector(
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
  }

  static const double _boxSize = 18;
  static const double _boxBorder = 1.5;
  static const double _tickSize = 16;
}
