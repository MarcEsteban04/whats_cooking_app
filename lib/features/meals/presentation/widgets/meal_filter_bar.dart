import 'package:flutter/material.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';

/// The two rows of filter pills above the feed (docs/design_ui.md §16).
///
/// Categories first, cuisines second, because that is the order the question
/// arrives in: people decide *when* they are eating before they decide *what
/// kind* of food it is. Both scroll horizontally rather than wrapping — a
/// wrapping filter bar changes height as you tap it, and the list underneath
/// jumps.
///
/// Each row leads with **All**, which is not a filter but the absence of one.
/// Selected means "the set is empty", so tapping it is how you clear a row
/// without hunting for the pill you turned on (docs/USER_FLOWS.md §7 requires a
/// clear-all; this is the per-row half of it).
class MealFilterBar extends StatelessWidget {
  const MealFilterBar({
    required this.query,
    required this.onCategoryToggled,
    required this.onCuisineToggled,
    required this.onCategoriesCleared,
    required this.onCuisinesCleared,
    super.key,
  });

  final MealQuery query;
  final ValueChanged<MealCategory> onCategoryToggled;
  final ValueChanged<Cuisine> onCuisineToggled;
  final VoidCallback onCategoriesCleared;
  final VoidCallback onCuisinesCleared;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ChipRow(
          semanticLabel: 'Meal type',
          children: <Widget>[
            AppFilterChip(
              label: 'All meals',
              isSelected: query.categories.isEmpty,
              onSelected: (_) => onCategoriesCleared(),
            ),
            for (final MealCategory category in MealCategory.values)
              AppFilterChip(
                label: category.label,
                isSelected: query.categories.contains(category),
                onSelected: (_) => onCategoryToggled(category),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        _ChipRow(
          semanticLabel: 'Cuisine',
          children: <Widget>[
            AppFilterChip(
              label: 'Any cuisine',
              isSelected: query.cuisines.isEmpty,
              onSelected: (_) => onCuisinesCleared(),
            ),
            for (final Cuisine cuisine in _offeredCuisines)
              AppFilterChip(
                label: cuisine.label,
                isSelected: query.cuisines.contains(cuisine),
                onSelected: (_) => onCuisineToggled(cuisine),
              ),
          ],
        ),
      ],
    );
  }

  /// The cuisines the catalogue actually holds.
  ///
  /// `Cuisine.values` has twelve entries and the seed fills seven of them
  /// (supabase/seed/02_meals.sql). Offering Thai as a filter that always returns
  /// nothing teaches people not to trust the filters, so the five empty ones are
  /// left out until there is food behind them.
  static const List<Cuisine> _offeredCuisines = <Cuisine>[
    Cuisine.filipino,
    Cuisine.japanese,
    Cuisine.korean,
    Cuisine.chinese,
    Cuisine.italian,
    Cuisine.mexican,
    Cuisine.american,
  ];
}

/// One horizontally scrolling row of chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.semanticLabel, required this.children});

  final String semanticLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Bleeds to the screen edge so the last chip is visibly cut off rather
        // than sitting flush against the margin, which is what tells you the row
        // scrolls.
        padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenMargin),
        child: Row(
          children: <Widget>[
            for (final (int index, Widget chip)
                in children.indexed) ...<Widget>[
              if (index > 0) const SizedBox(width: AppSpacing.space2),
              chip,
            ],
          ],
        ),
      ),
    );
  }
}
