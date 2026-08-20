import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/cards/meal_card.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';

/// One meal as a row in a dashboard table.
///
/// Shared by the feed and the favourites list so the two cannot drift: a meal
/// should look the same wherever it is listed, and two copies of this layout
/// would be two places to remember when the cost format changes.
///
/// The heart is a sibling of the tappable region rather than inside it —
/// docs/COMPONENTS.md §4 makes it an independent target, and `DashboardRow`
/// keeps its trailing widget outside the tap region for exactly this.
class MealTableRow extends ConsumerWidget {
  const MealTableRow({required this.meal, super.key});

  final Meal meal;

  /// Where the hairline above a row should start, so it runs under the text
  /// rather than through the cuisine dot.
  static const double ruleInset = _dotSize + AppSpacing.space3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColorScheme colors = context.colors;
    final AsyncValue<Set<String>> favorites = ref.watch(
      favoritesControllerProvider,
    );

    // Null while the set is still loading. The heart is hidden rather than shown
    // empty: an unfilled heart on a meal you saved is a lie, and it only lasts
    // until the first read returns.
    final bool? isFavorite = favorites.value?.contains(meal.id);

    return DashboardRow(
      leading: _CuisineDot(
        color: colors.accentFor(meal.cuisine.label).foreground,
      ),
      title: meal.name,
      subtitle: AppFormat.metadata(<String?>[
        meal.cuisine.label,
        AppFormat.cookingTime(meal.cookingTimeMinutes),
        meal.difficulty.label,
      ]),
      value: AppFormat.peso(meal.costPerServing),
      unit: 'a head',
      trailing: isFavorite == null
          ? null
          : FavoriteButton(
              isFavorite: isFavorite,
              mealName: meal.name,
              onToggled: (_) => _toggle(context, ref),
            ),
      onTap: () => context.goNamed(
        AppRoute.mealDetail.routeName,
        pathParameters: <String, String>{'id': meal.id},
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final AppException? failure = await ref
        .read(favoritesControllerProvider.notifier)
        .toggle(meal.id);

    if (failure == null || !context.mounted) {
      return;
    }

    // The controller has already put the heart back. All that is left is to say
    // why, because a heart that silently returns to where it was reads as the
    // tap having missed.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.displayMessage ?? failure.message)),
    );
  }
}

/// A small coloured dot standing for the cuisine.
///
/// Same cuisine, same colour, every time (docs/DESIGN_SYSTEM.md §9) — the meal
/// card's rail in a tenth of the space.
class _CuisineDot extends StatelessWidget {
  const _CuisineDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: _dotSize),
    );
  }
}

const double _dotSize = 8;
