import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// The "nothing here yet" surface (docs/COMPONENTS.md §12).
///
/// docs/design_ui.md §29 asks for empty states that are "visually beautiful and
/// friendly", and §12 adds the rule that gives them a job: **the action always
/// points back toward the core loop.** An empty favourites screen that only says
/// "no favourites" is a dead end; one that offers a spin is a way back in.
///
/// The named constructors carry the copy from §12's table so the same screen
/// cannot end up with different wording in two places.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  /// Favourites — nothing saved yet.
  const EmptyState.favorites({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'Nothing saved yet',
        body: 'Spin the wheel and find something you love.',
        icon: AppIcons.favorite,
        actionLabel: "What's Cooking?",
        onAction: onSpin,
        key: key,
      );

  /// Meal history — no meals yet.
  const EmptyState.history({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'No meals yet',
        body: 'Your decisions will show up here.',
        icon: AppIcons.plannerActive,
        actionLabel: 'Spin',
        onAction: onSpin,
        key: key,
      );

  /// Pantry — your fridge is empty.
  const EmptyState.pantry({required VoidCallback? onAddIngredient, Key? key})
    : this(
        title: 'Your fridge is empty',
        body: "Add what you have and we'll find something to cook.",
        icon: AppIcons.pantry,
        actionLabel: 'Add ingredient',
        onAction: onAddIngredient,
        key: key,
      );

  /// Grocery list — nothing to buy.
  const EmptyState.grocery({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'Nothing to buy',
        body: "Accept a meal and we'll fill this in for you.",
        icon: AppIcons.grocery,
        actionLabel: 'Spin',
        onAction: onSpin,
        key: key,
      );

  /// Search — no meals found.
  const EmptyState.search({required VoidCallback? onClearFilters, Key? key})
    : this(
        title: 'No meals found',
        body: 'Try a different search, or loosen your filters.',
        icon: AppIcons.search,
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
        key: key,
      );

  /// Hidden meals — nothing hidden.
  const EmptyState.hiddenMeals({required VoidCallback? onBrowse, Key? key})
    : this(
        title: 'Nothing hidden',
        body: 'Meals you hide stop appearing in the feed and the roulette.',
        icon: AppIcons.check,
        actionLabel: 'Browse meals',
        onAction: onBrowse,
        key: key,
      );

  /// My meals — none of your own yet.
  const EmptyState.myMeals({required VoidCallback? onAddMeal, Key? key})
    : this(
        title: 'No meals of your own yet',
        body: 'Add the food you actually cook.',
        icon: AppIcons.meals,
        actionLabel: 'Add a meal',
        onAction: onAddMeal,
        key: key,
      );

  final String title;
  final String body;

  /// The illustration: one glyph, in ink.
  ///
  /// An icon rather than an emoji. Emoji were warmer and cost no asset, which is
  /// why they were here — but they arrive full-colour and platform-specific, and
  /// beside a monochrome palette they read as clip art dropped into a design
  /// system. A themed glyph sits inside the ink instead of on top of it.
  final IconData? icon;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// A quieter second route out of the empty state, or null.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.screenMargin,
          vertical: AppSpacing.space9,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final IconData glyph)
              // Decorative, and larger than an inline icon: this is the
              // illustration, so it is sized like one. Kept out of the semantics
              // tree because the title already carries the meaning (§11).
              ExcludeSemantics(
                child: Icon(
                  glyph,
                  size: _illustrationSize,
                  color: colors.textTertiary,
                ),
              ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              title,
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
              child: Text(
                body,
                style: context.text.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space6),
              AppButton.primary(
                label: actionLabel!,
                size: AppButtonSize.medium,
                onPressed: onAction,
              ),
            ],
            // **A second way in, when there genuinely is one.**
            //
            // Added because the grocery list's import was unreachable from an
            // empty list: it lived in the panel's action row, and that row only
            // renders once there is something to show — so the one feature that
            // fills an empty list was hidden by the list being empty. The same
            // mistake the eat-out roulette made by hiding itself until there were
            // two places.
            //
            // Quieter than the primary, because it is the less common route in and
            // two equal buttons is a question rather than an offer.
            if (secondaryActionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              AppButton.tertiary(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const double _illustrationSize = 48;
  static const double _bodyMaxWidth = 280;
}
