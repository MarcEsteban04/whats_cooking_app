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
import 'package:whats_cooking/features/meals/presentation/providers/dislikes_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/favorites_controller.dart';

/// One meal as a row in a dashboard table.
///
/// Shared by the feed and by the Saved, Hidden and Your-meals lists, so the four
/// cannot drift: a meal should look the same wherever it is listed, and four
/// copies of this layout would be four places to remember when the cost format
/// changes.
///
/// The trailing control is a sibling of the tappable region rather than inside
/// it — docs/COMPONENTS.md §4 makes the heart an independent target, and
/// `DashboardRow` keeps its trailing widget outside the tap region for exactly
/// this.
class MealTableRow extends ConsumerWidget {
  const MealTableRow({
    required this.meal,
    this.trailing,
    this.showHiddenMarker = true,
    super.key,
  });

  final Meal meal;

  /// Replaces the heart.
  ///
  /// The hidden list puts a restore control here instead: a heart on a meal the
  /// user has hidden offers the two contradictory things at once.
  final Widget? trailing;

  /// Whether to say so when this meal is hidden.
  ///
  /// True on the feed and the favourites list, where a hidden meal is the
  /// exception worth flagging — you can favourite a meal and hide it, and a
  /// saved meal that never appears anywhere needs to explain itself. False on
  /// the hidden list, where every row is hidden and the marker is noise.
  final bool showHiddenMarker;

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

    final bool isHidden =
        showHiddenMarker &&
        (ref.watch(dislikesControllerProvider).value?.contains(meal.id) ??
            false);

    return DashboardRow(
      leading: _CuisineDot(
        color: colors.accentFor(meal.cuisine.label).foreground,
      ),
      title: meal.name,
      subtitle: AppFormat.metadata(<String?>[
        // First, because it changes what the rest of the row means: this meal
        // will not be suggested, however cheap or quick it is.
        if (isHidden) 'Hidden',
        meal.cuisine.label,
        AppFormat.cookingTime(meal.cookingTimeMinutes),
        meal.difficulty.label,
      ]),
      value: AppFormat.peso(meal.costPerServing),
      unit: 'a head',
      trailing:
          trailing ??
          (isFavorite == null
              ? null
              : FavoriteButton(
                  isFavorite: isFavorite,
                  mealName: meal.name,
                  onToggled: (_) => _toggleFavorite(context, ref),
                )),
      // `push`, not `go`: from Saved, Hidden or Your meals, `go` would rewrite
      // the stack as feed → meal and send Back to the feed rather than to the
      // list the reader came from. From the feed itself the two are identical.
      onTap: () => context.pushNamed(
        AppRoute.mealDetail.routeName,
        pathParameters: <String, String>{'id': meal.id},
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
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
