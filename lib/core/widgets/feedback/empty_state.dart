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
    this.emoji,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Favourites — nothing saved yet.
  const EmptyState.favorites({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'Nothing saved yet',
        body: 'Spin the wheel and find something you love.',
        emoji: '🍽️',
        actionLabel: "What's Cooking?",
        onAction: onSpin,
        key: key,
      );

  /// Meal history — no meals yet.
  const EmptyState.history({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'No meals yet',
        body: 'Your decisions will show up here.',
        emoji: '📖',
        actionLabel: 'Spin',
        onAction: onSpin,
        key: key,
      );

  /// Pantry — your fridge is empty.
  const EmptyState.pantry({required VoidCallback? onAddIngredient, Key? key})
    : this(
        title: 'Your fridge is empty',
        body: "Add what you have and we'll find something to cook.",
        emoji: '🧊',
        actionLabel: 'Add ingredient',
        onAction: onAddIngredient,
        key: key,
      );

  /// Grocery list — nothing to buy.
  const EmptyState.grocery({required VoidCallback? onSpin, Key? key})
    : this(
        title: 'Nothing to buy',
        body: "Accept a meal and we'll fill this in for you.",
        emoji: '🛒',
        actionLabel: 'Spin',
        onAction: onSpin,
        key: key,
      );

  /// Search — no meals found.
  const EmptyState.search({required VoidCallback? onClearFilters, Key? key})
    : this(
        title: 'No meals found',
        body: 'Try a different search, or loosen your filters.',
        emoji: '🔍',
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
        key: key,
      );

  /// My meals — none of your own yet.
  const EmptyState.myMeals({required VoidCallback? onAddMeal, Key? key})
    : this(
        title: 'No meals of your own yet',
        body: 'Add the food you actually cook.',
        emoji: '🍳',
        actionLabel: 'Add a meal',
        onAction: onAddMeal,
        key: key,
      );

  final String title;
  final String body;

  /// A 48 px emoji. Preferred over [icon] — warmer, and it costs no asset.
  final String? emoji;

  /// An `iconXl` glyph in `textTertiary`, when no emoji suits.
  final IconData? icon;

  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (emoji != null)
              // Decorative: the title already carries the meaning, so the
              // emoji is kept out of the semantics tree (§11).
              ExcludeSemantics(
                child: Text(
                  emoji!,
                  style: const TextStyle(fontSize: _illustrationSize),
                ),
              )
            else if (icon != null)
              Icon(icon, size: AppIconSize.xl, color: colors.textTertiary),
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
          ],
        ),
      ),
    );
  }

  static const double _illustrationSize = 48;
  static const double _bodyMaxWidth = 280;
}
