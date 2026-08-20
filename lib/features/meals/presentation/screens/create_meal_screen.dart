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
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';

/// Write your own meal (docs/USER_FLOWS.md §10, docs/project_dev.md Sprint 26).
///
/// The catalogue is sixty meals somebody else chose. This is how a household's
/// own food gets in — and it is the only way a meal is ever written, because the
/// `create own meals` policy accepts an insert only when it is private to the
/// caller's household. Nothing here can add to the public catalogue.
///
/// One screen rather than a wizard. Seven fields and two lists is a form, and a
/// form you can see all of is faster to fill than four screens you cannot.
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

  Future<void> _save() async {
    final String? problem = _draft.validate();
    if (problem != null) {
      setState(
        () => _failure = ValidationException(message: problem, field: 'draft'),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    try {
      final Meal meal = await ref.read(mealRepositoryProvider).create(_draft);

      // The feed is reloaded rather than patched. The new meal has to land in
      // whatever sort and filters are currently applied, and the server is the
      // only thing that knows where that is — inserting it at the top would put
      // it in the wrong place under every sort but one.
      await ref.read(mealsControllerProvider.notifier).refresh();

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenMargin,
                    AppSpacing.space4,
                    AppLayout.screenMargin,
                    AppSpacing.space4,
                  ),
                  child: Row(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          boxShadow: context.shadows.xs,
                        ),
                        child: AppIconButton(
                          icon: AppIcons.back,
                          semanticLabel: 'Back',
                          iconSize: AppIconSize.sm,
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Text(
                          'Add a meal',
                          style: context.text.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.screenMargin,
                      0,
                      AppLayout.screenMargin,
                      AppSpacing.space7,
                    ),
                    children: <Widget>[
                      if (_failure case final AppException failure) ...<Widget>[
                        InlineErrorBanner(message: failure.message),
                        const SizedBox(height: AppSpacing.space4),
                      ],
                      AppTextField(
                        label: 'Name',
                        hint: 'Tita Baby’s adobo',
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

                      const SectionHeader(title: 'Cuisine'),
                      _ChoiceWrap<Cuisine>(
                        values: Cuisine.values,
                        selected: _draft.cuisine,
                        label: (Cuisine value) => value.label,
                        onSelected: (Cuisine value) =>
                            _update(_draft.copyWith(cuisine: value)),
                      ),

                      const SectionHeader(title: 'When is it eaten?'),
                      _ChoiceWrap<MealCategory>(
                        values: MealCategory.values,
                        selected: _draft.category,
                        label: (MealCategory value) => value.label,
                        onSelected: (MealCategory value) =>
                            _update(_draft.copyWith(category: value)),
                      ),

                      const SectionHeader(title: 'How hard is it?'),
                      _ChoiceWrap<Difficulty>(
                        values: Difficulty.values,
                        selected: _draft.difficulty,
                        label: (Difficulty value) => value.label,
                        onSelected: (Difficulty value) =>
                            _update(_draft.copyWith(difficulty: value)),
                      ),

                      const SectionHeader(
                        title: 'The numbers',
                        subtitle:
                            'Cost is for everyone it feeds, not per plate — the '
                            'app works out the rest.',
                      ),
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

                      const SectionHeader(
                        title: 'Ingredients',
                        subtitle:
                            'Optional. Add what decides whether you can '
                            'cook it tonight.',
                      ),
                      _IngredientEditor(
                        ingredients: _draft.ingredients,
                        isEnabled: !_isSaving,
                        onChanged: (List<DraftIngredient> ingredients) =>
                            _update(_draft.copyWith(ingredients: ingredients)),
                      ),

                      const SectionHeader(
                        title: 'How to cook it',
                        subtitle: 'Optional. One step per line.',
                      ),
                      _StepEditor(
                        steps: _draft.instructions,
                        isEnabled: !_isSaving,
                        onChanged: (List<String> steps) =>
                            _update(_draft.copyWith(instructions: steps)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.screenMargin,
                    AppSpacing.space3,
                    AppLayout.screenMargin,
                    AppSpacing.space5,
                  ),
                  child: AppButton.inverse(
                    label: 'Save meal',
                    isLoading: _isSaving,
                    // Disabled until it could actually be saved, so the button
                    // never promises something the validator will refuse.
                    onPressed: _draft.isValid && !_isSaving ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips for a small fixed set of options.
class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final T value in values)
          AppFilterChip(
            label: label(value),
            isSelected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// The key a number field carries, so a test can find it by label.
String numberFieldKey(String label) => 'number-$label';

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
      // The label itself is a sibling of the input rather than inside it, so
      // `widgetWithText` cannot reach it.
      key: ValueKey<String>(numberFieldKey(widget.label)),
      controller: _controller,
      label: widget.label,
      keyboardType: TextInputType.number,
      // Digits only, so the parse below cannot fail on something typed rather
      // than on something missing.
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      isEnabled: widget.isEnabled,
      onChanged: (String value) => widget.onChanged(int.tryParse(value)),
    );
  }
}

/// The ingredient list, one row at a time.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: AppTextField(
            label: 'Ingredient',
            hint: 'chicken thigh',
            isEnabled: isEnabled,
            onChanged: (String value) =>
                onChanged(ingredient.copyWith(name: value)),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          flex: 2,
          child: _NumberField(
            label: 'Qty',
            value: ingredient.quantity.round(),
            isEnabled: isEnabled,
            onChanged: (int? value) => onChanged(
              ingredient.copyWith(quantity: (value ?? 0).toDouble()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        _UnitPicker(
          unit: ingredient.unit,
          isEnabled: isEnabled,
          onChanged: (String unit) =>
              onChanged(ingredient.copyWith(unit: unit)),
        ),
        AppIconButton(
          icon: AppIcons.clear,
          semanticLabel: 'Remove ${ingredient.name} from the list',
          iconSize: AppIconSize.sm,
          onPressed: isEnabled ? onRemoved : null,
        ),
      ],
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

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: unit,
        onChanged: isEnabled
            ? (String? value) {
                if (value != null) {
                  onChanged(value);
                }
              }
            : null,
        borderRadius: AppRadius.borderMd,
        style: context.text.bodyMedium.copyWith(color: colors.textPrimary),
        items: <DropdownMenuItem<String>>[
          for (final String value in DraftIngredient.units)
            DropdownMenuItem<String>(value: value, child: Text(value)),
        ],
      ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  key: ValueKey<int>(index),
                  label: 'Step ${index + 1}',
                  maxLines: 2,
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
