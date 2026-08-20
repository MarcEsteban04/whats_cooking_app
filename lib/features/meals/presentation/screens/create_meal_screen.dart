import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';

/// The key a number field carries, so a test can find it by label.
String numberFieldKey(String label) => 'number-$label';

/// Write your own meal (docs/USER_FLOWS.md §10).
///
/// The catalogue is sixty meals somebody else chose. This is how a household's
/// own food gets in — and it is the only way a meal is ever written, because the
/// `create own meals` policy accepts an insert only when it is private to the
/// caller's household. Nothing here can add to the public catalogue.
///
/// Presented as a full-screen dialog on the **root** navigator, so the bottom
/// navigation is covered: a half-written recipe should not be one tap on Home
/// away from gone. `AppSlideUpPage` carries the rest of the reasoning, including
/// why this is not a bottom sheet.
///
/// One screen rather than a wizard, grouped into cards. Twelve controls in a
/// flat column is a wall; the same twelve under five headings is a form whose
/// shape you can see.
class CreateMealScreen extends ConsumerStatefulWidget {
  const CreateMealScreen({super.key});

  @override
  ConsumerState<CreateMealScreen> createState() => _CreateMealScreenState();
}

class _CreateMealScreenState extends ConsumerState<CreateMealScreen> {
  MealDraft _draft = const MealDraft();
  AppException? _failure;
  bool _isSaving = false;

  void _update(MealDraft draft) => setState(() => _draft = draft);

  /// Whether anything has been typed.
  ///
  /// Decides whether cancelling has to ask. An untouched form closes without a
  /// dialog, because confirming a decision nobody made is pure friction.
  bool get _isStarted => _draft != const MealDraft();

  Future<void> _cancel() async {
    if (!_isStarted) {
      context.pop();
      return;
    }

    final bool discard = await ConfirmationDialog.show(
      context,
      title: 'Discard this meal?',
      body: 'What you have written will not be saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep writing',
      isDestructive: true,
    );

    if (discard && mounted) {
      context.pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    try {
      final Meal meal = await ref.read(mealRepositoryProvider).create(_draft);

      // The feed is reloaded rather than patched. The new meal has to land in
      // whatever sort and filters are applied, and the server is the only thing
      // that knows where that is — putting it at the top would be wrong under
      // every sort but one.
      await ref.read(mealsControllerProvider.notifier).refresh();

      if (!mounted) {
        return;
      }
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${meal.name} is in your meals')));
    } on Object catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _failure = ErrorMapper.map(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final String? missing = _draft.validate();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(onCancel: _isSaving ? null : _cancel),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.screenMargin,
                      AppSpacing.space4,
                      AppLayout.screenMargin,
                      AppSpacing.space6,
                    ),
                    children: <Widget>[
                      if (_failure case final AppException failure) ...<Widget>[
                        InlineErrorBanner(message: failure.message),
                        const SizedBox(height: AppSpacing.space4),
                      ],

                      _FormSection(
                        title: 'What is it?',
                        children: <Widget>[
                          AppTextField(
                            label: 'Name',
                            hint: 'Tita Baby adobo',
                            textCapitalization: TextCapitalization.words,
                            isEnabled: !_isSaving,
                            onChanged: (String value) =>
                                _update(_draft.copyWith(name: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          AppTextField(
                            label: 'Description',
                            hint: 'What makes it yours?',
                            maxLines: 3,
                            isEnabled: !_isSaving,
                            onChanged: (String value) =>
                                _update(_draft.copyWith(description: value)),
                          ),
                        ],
                      ),

                      _FormSection(
                        title: 'Where does it belong?',
                        children: <Widget>[
                          _ChoiceGroup<Cuisine>(
                            label: 'Cuisine',
                            values: Cuisine.values,
                            selected: _draft.cuisine,
                            name: (Cuisine value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (Cuisine value) =>
                                _update(_draft.copyWith(cuisine: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          _ChoiceGroup<MealCategory>(
                            label: 'Eaten at',
                            values: MealCategory.values,
                            selected: _draft.category,
                            name: (MealCategory value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (MealCategory value) =>
                                _update(_draft.copyWith(category: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          _ChoiceGroup<Difficulty>(
                            label: 'Difficulty',
                            values: Difficulty.values,
                            selected: _draft.difficulty,
                            name: (Difficulty value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (Difficulty value) =>
                                _update(_draft.copyWith(difficulty: value)),
                          ),
                        ],
                      ),

                      _FormSection(
                        title: 'The numbers',
                        subtitle:
                            'Cost is for everyone it feeds, not per plate. The '
                            'app works out the rest.',
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _NumberField(
                                  label: 'Minutes',
                                  value: _draft.cookingTimeMinutes,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    _draft.copyWith(cookingTimeMinutes: value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _NumberField(
                                  label: 'Pesos',
                                  value: _draft.estimatedCost,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    _draft.copyWith(estimatedCost: value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _NumberField(
                                  label: 'Feeds',
                                  value: _draft.servings,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    _draft.copyWith(servings: value ?? 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_draft.costPerServingLabel case final String each)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.space3,
                              ),
                              child: Text(
                                // Shown as it is typed, because cost a head is
                                // what every filter in the app compares and it is
                                // not the number being entered.
                                'That is $each',
                                style: context.text.metadata,
                              ),
                            ),
                        ],
                      ),

                      _FormSection(
                        title: 'Ingredients',
                        subtitle:
                            'Optional. What decides whether you can cook it '
                            'tonight — staples like salt and oil are assumed.',
                        children: <Widget>[
                          _IngredientEditor(
                            ingredients: _draft.ingredients,
                            isEnabled: !_isSaving,
                            onChanged: (List<DraftIngredient> ingredients) =>
                                _update(
                                  _draft.copyWith(ingredients: ingredients),
                                ),
                          ),
                        ],
                      ),

                      _FormSection(
                        title: 'How to cook it',
                        subtitle: 'Optional. One step at a time.',
                        children: <Widget>[
                          _StepEditor(
                            steps: _draft.instructions,
                            isEnabled: !_isSaving,
                            onChanged: (List<String> steps) =>
                                _update(_draft.copyWith(instructions: steps)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SaveBar(
                  missing: missing,
                  isSaving: _isSaving,
                  onSave: missing == null && !_isSaving ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancel on the left, the title centred.
///
/// **Cancel**, not a back arrow. This is a task you are inside rather than a
/// place you navigated to, and the label should say which.
class _Header extends StatelessWidget {
  const _Header({required this.onCancel});

  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.screenMargin,
          AppSpacing.space3,
          AppLayout.screenMargin,
          AppSpacing.space3,
        ),
        child: Row(
          children: <Widget>[
            AppButton.tertiary(
              label: 'Cancel',
              size: AppButtonSize.small,
              onPressed: onCancel,
            ),
            Expanded(
              child: Text(
                'Add a meal',
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            // Balances the Cancel button's width so the title sits actually
            // centred rather than shoved right.
            const Opacity(
              opacity: 0,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: AppButton.tertiary(
                    label: 'Cancel',
                    size: AppButtonSize.small,
                    onPressed: null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of fields on one card.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: context.text.titleMedium),
            if (subtitle case final String text) ...<Widget>[
              const SizedBox(height: AppSpacing.space1),
              Text(
                text,
                style: context.text.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A labelled row of chips for a small fixed set of options.
class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.name,
    required this.isEnabled,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) name;
  final bool isEnabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              for (final T value in values)
                AppFilterChip(
                  label: name(value),
                  isSelected: value == selected,
                  onSelected: isEnabled ? (_) => onSelected(value) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A whole-number field.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.isEnabled,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final bool isEnabled;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      // Keyed by its label so a test can address one number field among several.
      // The label is a sibling of the input rather than inside it, so
      // `widgetWithText` cannot reach it.
      key: ValueKey<String>(numberFieldKey(widget.label)),
      controller: _controller,
      label: widget.label,
      keyboardType: TextInputType.number,
      // Digits only, so the parse below can fail on something missing but never
      // on something typed.
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      isEnabled: widget.isEnabled,
      onChanged: (String value) => widget.onChanged(int.tryParse(value)),
    );
  }
}

/// The ingredient list.
class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({
    required this.ingredients,
    required this.isEnabled,
    required this.onChanged,
  });

  final List<DraftIngredient> ingredients;
  final bool isEnabled;
  final ValueChanged<List<DraftIngredient>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int index, DraftIngredient ingredient)
            in ingredients.indexed) ...<Widget>[
          _IngredientRow(
            key: ValueKey<int>(index),
            ingredient: ingredient,
            isEnabled: isEnabled,
            onChanged: (DraftIngredient updated) => onChanged(<DraftIngredient>[
              ...ingredients.sublist(0, index),
              updated,
              ...ingredients.sublist(index + 1),
            ]),
            onRemoved: () => onChanged(<DraftIngredient>[
              ...ingredients.sublist(0, index),
              ...ingredients.sublist(index + 1),
            ]),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: ingredients.isEmpty ? 'Add an ingredient' : 'Add another',
            size: AppButtonSize.small,
            leadingIcon: AppIcons.add,
            onPressed: isEnabled
                ? () => onChanged(<DraftIngredient>[
                    ...ingredients,
                    const DraftIngredient(name: '', quantity: 1, unit: 'pc'),
                  ])
                : null,
          ),
        ),
      ],
    );
  }
}

/// One ingredient: the name on its own line, the amount beneath it.
///
/// Stacked rather than four controls across a row. Name, quantity, unit and a
/// remove button side by side left the name field about eight characters wide on
/// a phone, and unusable at 1.3x text scale.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.isEnabled,
    required this.onChanged,
    required this.onRemoved,
    super.key,
  });

  final DraftIngredient ingredient;
  final bool isEnabled;
  final ValueChanged<DraftIngredient> onChanged;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'Ingredient',
                    hint: 'chicken thigh',
                    isEnabled: isEnabled,
                    onChanged: (String value) =>
                        onChanged(ingredient.copyWith(name: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                AppIconButton(
                  icon: AppIcons.clear,
                  semanticLabel: ingredient.isBlank
                      ? 'Remove this ingredient'
                      : 'Remove ${ingredient.name}',
                  iconSize: AppIconSize.sm,
                  onPressed: isEnabled ? onRemoved : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: _NumberField(
                    label: 'How much',
                    value: ingredient.quantity.round(),
                    isEnabled: isEnabled,
                    onChanged: (int? value) => onChanged(
                      ingredient.copyWith(quantity: (value ?? 0).toDouble()),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: _UnitPicker(
                    unit: ingredient.unit,
                    isEnabled: isEnabled,
                    onChanged: (String unit) =>
                        onChanged(ingredient.copyWith(unit: unit)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            // "Nice to have" means excluded from the pantry match, not from the
            // recipe — a missing garnish must never stop a meal being offered
            // (docs/USER_FLOWS.md §12).
            Align(
              alignment: Alignment.centerLeft,
              child: AppFilterChip(
                label: 'Nice to have',
                isSelected: ingredient.isOptional,
                onSelected: isEnabled
                    ? (bool value) =>
                          onChanged(ingredient.copyWith(isOptional: value))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed unit vocabulary (docs/DATABASE.md §4.6).
///
/// A menu rather than a text field, because a free-typed unit breaks the grocery
/// list's ability to add two quantities together (Sprint 50).
class _UnitPicker extends StatelessWidget {
  const _UnitPicker({
    required this.unit,
    required this.isEnabled,
    required this.onChanged,
  });

  final String unit;
  final bool isEnabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Unit', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.space2),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: colors.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: unit,
                isExpanded: true,
                onChanged: isEnabled
                    ? (String? value) {
                        if (value != null) {
                          onChanged(value);
                        }
                      }
                    : null,
                borderRadius: AppRadius.borderMd,
                style: context.text.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String value in DraftIngredient.units)
                    DropdownMenuItem<String>(value: value, child: Text(value)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The instructions, one numbered step at a time.
class _StepEditor extends StatelessWidget {
  const _StepEditor({
    required this.steps,
    required this.isEnabled,
    required this.onChanged,
  });

  final List<String> steps;
  final bool isEnabled;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final int index in List<int>.generate(
          steps.length,
          (int i) => i,
        )) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _StepNumber(number: index + 1),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: AppTextField(
                  key: ValueKey<int>(index),
                  hint: 'What happens next?',
                  maxLines: 3,
                  isEnabled: isEnabled,
                  onChanged: (String value) => onChanged(<String>[
                    ...steps.sublist(0, index),
                    value,
                    ...steps.sublist(index + 1),
                  ]),
                ),
              ),
              AppIconButton(
                icon: AppIcons.clear,
                semanticLabel: 'Remove step ${index + 1}',
                iconSize: AppIconSize.sm,
                onPressed: isEnabled
                    ? () => onChanged(<String>[
                        ...steps.sublist(0, index),
                        ...steps.sublist(index + 1),
                      ])
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: steps.isEmpty ? 'Add a step' : 'Add another step',
            size: AppButtonSize.small,
            leadingIcon: AppIcons.add,
            onPressed: isEnabled
                ? () => onChanged(<String>[...steps, ''])
                : null,
          ),
        ),
      ],
    );
  }
}

/// The step's position, as a numbered disc.
class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Padding(
      // Aligns the disc with the field's text rather than with its top edge.
      padding: const EdgeInsets.only(top: AppSpacing.space2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: _diameter,
          child: Center(
            child: Text(
              '$number',
              style: context.text.labelSmall.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _diameter = 28;
}

/// The pinned save action, and what is still stopping it.
///
/// A disabled button with no explanation is the worst state a form can sit in:
/// the reader can see they cannot continue and not why. The validator already
/// returns the first missing thing, so the bar says it.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.missing,
    required this.isSaving,
    required this.onSave,
  });

  final String? missing;
  final bool isSaving;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.screenMargin,
          AppSpacing.space3,
          AppLayout.screenMargin,
          AppSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (missing case final String reason) ...<Widget>[
              Text(
                reason,
                style: context.text.metadata,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space2),
            ],
            AppButton.inverse(
              label: 'Save meal',
              isLoading: isSaving,
              onPressed: onSave,
            ),
          ],
        ),
      ),
    );
  }
}
