import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/features/ai/domain/entities/generated_recipe.dart';
import 'package:whats_cooking/features/ai/presentation/providers/recipe_generator_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// Ask for a recipe, then keep it (Sprint 48).
///
/// **This is the answer to the emptiest library.** Sixty catalogue meals is what
/// the app ships with; a household's own food gets in through a twelve-field form,
/// which is why it mostly does not. Here the ingredients are already on screen
/// because the pantry knows them, the recipe arrives written, and the only typing
/// is whatever somebody wants to correct.
///
/// **Two steps, not one, and the second is deliberate.** The recipe is shown here
/// to be read, and keeping it opens the ordinary meal form pre-filled. It would be
/// fewer taps to drop straight into the form — but the form is a column of input
/// fields, which is a bad way to read a recipe and an expensive way to reject one:
/// backing out of it asks "discard this meal?" where the button here just says try
/// another.
class RecipeGeneratorScreen extends ConsumerStatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  ConsumerState<RecipeGeneratorScreen> createState() =>
      _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends ConsumerState<RecipeGeneratorScreen> {
  final TextEditingController _note = TextEditingController();

  /// Which ingredients to build around. Null until the pantry has loaded and the
  /// default selection has been seeded.
  Set<String>? _picked;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final RecipeIdea idea = ref.watch(recipeGeneratorProvider);

    final List<PantryItem> pantry =
        ref.watch(pantryControllerProvider).value ?? const <PantryItem>[];

    final List<String> names = _names(pantry);
    _picked ??= names.take(_seedCount).toSet();

    // Anything picked that has since left the kitchen is dropped, so a chip that
    // is no longer on screen cannot still be in the request.
    final Set<String> picked = _picked!.intersection(names.toSet());

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Invent a meal'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenMargin,
                AppSpacing.space4,
                AppLayout.screenMargin,
                AppSpacing.space8,
              ),
              children: <Widget>[
                if (idea.failure case final AppException failure) ...<Widget>[
                  InlineErrorBanner(
                    // The Edge Function writes these sentences, so this shows
                    // theirs rather than inventing a second wording.
                    message: failure.displayMessage ?? failure.message,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],

                _Brief(
                  names: names,
                  picked: picked,
                  note: _note,
                  isBusy: idea.isWriting,
                  onToggle: (String name) => setState(() {
                    if (!_picked!.remove(name)) {
                      _picked!.add(name);
                    }
                  }),
                ),

                const SizedBox(height: AppSpacing.space4),

                AppButton.inverse(
                  label: idea.attempts == 0 ? 'Write a recipe' : 'Try another',
                  isLoading: idea.isWriting,
                  onPressed: idea.isWriting
                      ? null
                      : () {
                          AppHaptics.spinBegun();
                          ref.read(recipeGeneratorProvider.notifier).write(
                            ingredients: picked.toList(),
                            note: _note.text,
                          );
                        },
                ),

                if (idea.recipe case final GeneratedRecipe recipe) ...<Widget>[
                  const SizedBox(height: AppSpacing.space5),
                  // Dimmed while the next one is written. The recipe stays put
                  // rather than being blanked, because a tap on "try another"
                  // should not throw away a good suggestion before knowing
                  // whether the replacement arrives.
                  Opacity(
                    opacity: idea.isWriting ? _fadedWhileWriting : 1,
                    child: _RecipeCard(
                      recipe: recipe,
                      onSave: idea.isWriting ? null : () => _keep(recipe),
                    ),
                  ),
                ] else if (!idea.isWriting)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.space6),
                    child: _WhatThisIs(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hands the recipe to the meal form.
  ///
  /// **Nothing is written to the library here.** The form is the confirmation step
  /// — see [GeneratedRecipe.toDraft] — and it is also the only create path, so a
  /// generated meal is saved by exactly the same code as a typed one.
  ///
  /// The generator is cleared on the way, so coming back lands on a fresh brief
  /// rather than on a recipe that has already been dealt with.
  void _keep(GeneratedRecipe recipe) {
    final MealDraft draft = recipe.toDraft();
    ref.read(recipeGeneratorProvider.notifier).clear();
    context.pushNamed(AppRoute.mealCreate.routeName, extra: draft);
  }

  /// The kitchen, in the order worth cooking.
  ///
  /// Whatever needs using comes first — which is the whole argument for asking the
  /// app rather than a chat app, and it should be the first thing the chips say.
  List<String> _names(List<PantryItem> pantry) {
    final DateTime now = DateTime.now();
    final List<PantryItem> sorted = <PantryItem>[...pantry]
      ..sort((PantryItem a, PantryItem b) {
        final bool aUrgent = a.statusAsOf(now).needsAttention;
        final bool bUrgent = b.statusAsOf(now).needsAttention;
        if (aUrgent != bUrgent) {
          return aUrgent ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    // Deduplicated by name, because two jars of the same thing is one ingredient
    // as far as a recipe is concerned.
    final Set<String> seen = <String>{};
    return <String>[
      for (final PantryItem item in sorted)
        if (seen.add(item.name.toLowerCase())) item.name,
    ];
  }

  /// How many chips start ticked.
  ///
  /// Six is about a dish. Past that the model starts picking its favourites out of
  /// the list anyway, and the choosing may as well be somebody's.
  static const int _seedCount = 6;

  static const double _fadedWhileWriting = 0.4;
}

/// What to build around.
class _Brief extends StatelessWidget {
  const _Brief({
    required this.names,
    required this.picked,
    required this.note,
    required this.isBusy,
    required this.onToggle,
  });

  final List<String> names;
  final Set<String> picked;
  final TextEditingController note;
  final bool isBusy;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'What have we got?',
      icon: AppIcons.pantry,
      trailing: names.isEmpty
          ? null
          : Text('${picked.length} picked', style: context.text.metadata),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (names.isEmpty)
            Text(
              // Not an error. A recipe with nothing to go on is a perfectly good
              // request — it just becomes "surprise us", and saying so is better
              // than a disabled button with no explanation.
              'Nothing in the kitchen yet, so this will be a surprise. Add what '
              'you have and it will build around that instead.',
              style: context.text.bodyMedium,
            )
          else ...<Widget>[
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                for (final String name in names)
                  AppFilterChip(
                    label: name,
                    isSelected: picked.contains(name),
                    onSelected: isBusy ? null : (_) => onToggle(name),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Tap to include or leave out. Salt, oil, garlic and soy sauce are '
              'assumed.',
              style: context.text.metadata,
            ),
          ],

          const SizedBox(height: AppSpacing.space5),
          AppTextField(
            controller: note,
            label: 'Anything else?',
            hint: 'Nothing fried, and no rice',
            maxLines: 2,
            isEnabled: !isBusy,
          ),
        ],
      ),
    );
  }
}

/// The recipe, laid out to be read.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onSave});

  final GeneratedRecipe recipe;

  /// Null while another recipe is being written.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles text = context.text;
    final String? perHead = _perHead(recipe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashboardPanel(
          title: recipe.name,
          icon: AppIcons.invent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StatTrio(
                columns: <StatColumnData>[
                  StatColumnData(
                    label: 'Ready in',
                    value: '${recipe.cookingTimeMinutes}',
                    unit: 'min',
                  ),
                  StatColumnData(
                    label: 'A head',
                    // Per head, never per pot — the same rule the rest of the app
                    // follows, and the reason the model is asked for the whole
                    // dish and the division happens here.
                    value: perHead ?? '—',
                    unit: perHead == null ? 'unknown' : 'pesos',
                  ),
                  StatColumnData(
                    label: 'Serves',
                    value: '${recipe.servings}',
                    unit: recipe.servings == 1 ? 'person' : 'people',
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.space5),
              const DashboardRule(),

              for (final DraftIngredient item in recipe.ingredients)
                DashboardRow(
                  title: item.name,
                  value: _amount(item),
                  unit: item.unit,
                ),

              const SizedBox(height: AppSpacing.space5),
              Text('How to cook it', style: text.label),
              const SizedBox(height: AppSpacing.space3),

              for (final (int index, String step) in recipe.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: _stepNumberWidth,
                        child: Text('${index + 1}', style: text.numeric),
                      ),
                      Expanded(child: Text(step, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space4),
        AppButton.inverse(label: 'Keep it', onPressed: onSave),
        const SizedBox(height: AppSpacing.space2),
        Text(
          // Says what the button does, because "keep it" landing on a form is a
          // surprise otherwise — and the form is where a wrong quantity gets
          // fixed, which is worth knowing before tapping.
          'You will see it as a meal you can edit before it is saved.',
          style: text.metadata,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Cost per head, rounded, or null when the model did not say.
  static String? _perHead(GeneratedRecipe recipe) {
    if (recipe.estimatedCost case final int cost when recipe.servings > 0) {
      return '${(cost / recipe.servings).round()}';
    }
    return null;
  }

  /// `2` rather than `2.0`, and `1.5` when it matters.
  static String _amount(DraftIngredient item) {
    final double quantity = item.quantity;
    return quantity == quantity.roundToDouble()
        ? '${quantity.round()}'
        : quantity.toStringAsFixed(1);
  }

  static const double _stepNumberWidth = 24;
}

/// The empty state, before anything has been asked for.
///
/// Says what this is for rather than showing an illustration. The feature is not
/// self-explanatory — "invent a meal" could plausibly mean the roulette — and one
/// sentence about the library is what makes the difference between somebody using
/// this once and using it every time the fridge is odd.
class _WhatThisIs extends StatelessWidget {
  const _WhatThisIs();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(
          AppIcons.invent,
          size: AppIconSize.xl,
          color: context.colors.textTertiary,
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          'Anything you keep goes into your meals, so the roulette can land on '
          'it later.',
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
