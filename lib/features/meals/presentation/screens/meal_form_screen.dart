import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_select.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_detail_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/providers/my_meals_controller.dart';

/// The key a number field carries, so a test can find it by label.
String numberFieldKey(String label) => 'number-$label';

/// Write your own meal, or rewrite one (docs/USER_FLOWS.md §10).
///
/// The catalogue is sixty meals somebody else chose. This is how a household's
/// own food gets in — and it is the only way a meal is ever written, because the
/// `create own meals` policy accepts an insert only when it is private to the
/// caller's household. Nothing here can add to the public catalogue.
///
/// **One form for both directions** (Sprint 26). Editing a recipe is the same
/// twelve questions as writing one; a second screen would be the same twelve
/// controls with a different verb, and the two would drift the first time a
/// field was added. Passing [mealId] seeds the draft from the stored meal and
/// switches the verb — nothing else changes.
///
/// Presented as a full-screen dialog on the **root** navigator, so the bottom
/// navigation is covered: a half-written recipe should not be one tap on Home
/// away from gone. `AppSlideUpPage` carries the rest of the reasoning, including
/// why this is not a bottom sheet.
///
/// One screen rather than a wizard, grouped into cards. Twelve controls in a
/// flat column is a wall; the same twelve under five headings is a form whose
/// shape you can see.
class MealFormScreen extends ConsumerStatefulWidget {
  const MealFormScreen({this.mealId, this.initialDraft, super.key});

  /// The meal being rewritten, or null when writing a new one.
  final String? mealId;

  /// What the form opens filled in with, when something else wrote it.
  ///
  /// **This is the confirmation step for a generated recipe** (Sprint 48). The
  /// assistant can write a meal, and nothing it writes reaches the library without
  /// passing through this screen — which means it also passes through
  /// [MealDraft.validate] and the one create path, exactly like a meal somebody
  /// typed. There is no second way in to keep in step.
  ///
  /// Ignored when [mealId] is set: a stored meal is the truth about itself, and a
  /// draft arriving alongside it could only overwrite what is already there.
  final MealDraft? initialDraft;

  bool get isEditing => mealId != null;

  @override
  ConsumerState<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends ConsumerState<MealFormScreen> {
  /// Null until there is something to edit.
  ///
  /// A new meal starts from a blank draft immediately. An edit has to wait for
  /// the meal, and a form that renders blank fields and fills them a moment
  /// later is one that loses whatever was typed in between.
  MealDraft? _draft;

  /// What the meal said when it was loaded, for spotting an untouched form.
  MealDraft? _original;

  AppException? _failure;
  bool _isSaving = false;

  void _update(MealDraft draft) => setState(() => _draft = draft);

  /// Whether anything has been typed since the form opened.
  ///
  /// Decides whether cancelling has to ask. An untouched form closes without a
  /// dialog, because confirming a decision nobody made is pure friction — and on
  /// an edit that means comparing against what was loaded rather than against
  /// blank, or backing out of a recipe you only looked at would always ask.
  bool get _isStarted => _draft != null && _draft != (_original ?? _blank);

  Future<void> _cancel() async {
    if (!_isStarted) {
      context.pop();
      return;
    }

    final bool discard = await ConfirmationDialog.show(
      context,
      title: widget.isEditing ? 'Discard your changes?' : 'Discard this meal?',
      body: widget.isEditing
          ? 'The meal will stay as it was.'
          : 'What you have written will not be saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep writing',
      isDestructive: true,
    );

    if (discard && mounted) {
      context.pop();
    }
  }

  Future<void> _save() async {
    final MealDraft? draft = _draft;
    if (draft == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    try {
      final MealRepository repository = ref.read(mealRepositoryProvider);
      final Meal meal = switch (widget.mealId) {
        final String id => await repository.update(id, draft),
        null => await repository.create(draft),
      };

      // The feed is reloaded rather than patched. A new or renamed meal has to
      // land in whatever sort and filters are applied, and the server is the
      // only thing that knows where that is — putting it at the top would be
      // wrong under every sort but one.
      await ref.read(mealsControllerProvider.notifier).refresh();

      // The two lists that show it, and the detail screen behind this one. All
      // invalidated rather than patched, for the same reason.
      ref.invalidate(myMealsProvider);
      if (widget.mealId case final String id) {
        ref.invalidate(mealDetailProvider(id));
      }

      if (!mounted) {
        return;
      }
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? '${meal.name} is updated'
                : '${meal.name} is in your meals',
          ),
        ),
      );
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

    // Seeded here rather than in `initState`, because the meal arrives
    // asynchronously and this is the first frame that has it. Assigned once and
    // never again: re-seeding on a later rebuild would throw away typing.
    if (widget.mealId case final String id) {
      final AsyncValue<Meal> stored = ref.watch(mealDetailProvider(id));

      if (_draft == null) {
        if (stored case AsyncError<Meal>(:final Object error)) {
          return _FormLoadFailure(
            failure: error is AppException ? error : const UnknownException(),
            onRetry: () => ref.invalidate(mealDetailProvider(id)),
          );
        }
        if (stored.value case final Meal meal) {
          _original = MealDraft.fromMeal(meal);
          _draft = _original;
        } else {
          return const _FormLoading();
        }
      }
    } else {
      // A generated recipe counts as *started*, so backing out asks before
      // throwing it away — it took a round trip and somebody chose to keep it.
      // That falls out of comparing against `_blank`, which is why the seed goes
      // into `_draft` and never into `_original`.
      _draft ??= widget.initialDraft ?? _blank;
    }

    final MealDraft draft = _draft!;
    final String? missing = draft.validate();

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
                _Header(
                  // Three verbs, because the job is different in each case. A
                  // generated recipe says "check" rather than "add": the fields
                  // are already filled and what is being asked for is a read, not
                  // a write.
                  title: switch ((widget.isEditing, widget.initialDraft)) {
                    (true, _) => 'Edit meal',
                    (false, final MealDraft? seed) when seed != null =>
                      'Check this over',
                    _ => 'Add a meal',
                  },
                  onCancel: _isSaving ? null : _cancel,
                ),
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
                            // `initialValue`, not `controller`: the field owns
                            // its text and the draft owns the value, so an edit
                            // opens filled in without the two fighting over the
                            // cursor on every keystroke.
                            initialValue: draft.name,
                            textCapitalization: TextCapitalization.words,
                            isEnabled: !_isSaving,
                            onChanged: (String value) =>
                                _update(draft.copyWith(name: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          AppTextField(
                            label: 'Description',
                            hint: 'What makes it yours?',
                            initialValue: draft.description,
                            maxLines: 3,
                            isEnabled: !_isSaving,
                            onChanged: (String value) =>
                                _update(draft.copyWith(description: value)),
                          ),

                          // Shared or ours (Sprint 53c).
                          //
                          // **Only when adding.** Editing does not move a meal
                          // between the catalogue and a household: the update
                          // policy would refuse it, and a control that silently
                          // relocates a meal is not what "edit" means.
                          if (!widget.isEditing) ...<Widget>[
                            const SizedBox(height: AppSpacing.space5),
                            AppSegmentedControl<bool>(
                              options: const <(bool, String)>[
                                (true, 'A common meal'),
                                (false, 'Just ours'),
                              ],
                              selected: draft.isShared,
                              onSelected: (bool value) =>
                                  _update(draft.copyWith(isShared: value)),
                            ),
                            const SizedBox(height: AppSpacing.space2),
                            Text(
                              draft.isShared
                                  // Says where it lands rather than what a flag
                                  // is called. "Public" is a database word and
                                  // means nothing in a house with two people.
                                  ? 'Goes in the list with everything else.'
                                  : 'Kept under Yours, out of the main list.',
                              style: context.text.metadata,
                            ),
                          ],
                        ],
                      ),

                      _FormSection(
                        title: 'Where does it belong?',
                        children: <Widget>[
                          _ChoiceGroup<Cuisine>(
                            label: 'Cuisine',
                            values: Cuisine.values,
                            selected: draft.cuisine,
                            name: (Cuisine value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (Cuisine value) =>
                                _update(draft.copyWith(cuisine: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          _ChoiceGroup<MealCategory>(
                            label: 'Eaten at',
                            values: MealCategory.values,
                            selected: draft.category,
                            name: (MealCategory value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (MealCategory value) =>
                                _update(draft.copyWith(category: value)),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          _ChoiceGroup<Difficulty>(
                            label: 'Difficulty',
                            values: Difficulty.values,
                            selected: draft.difficulty,
                            name: (Difficulty value) => value.label,
                            isEnabled: !_isSaving,
                            onSelected: (Difficulty value) =>
                                _update(draft.copyWith(difficulty: value)),
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
                                  value: draft.cookingTimeMinutes,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    draft.copyWith(cookingTimeMinutes: value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _NumberField(
                                  label: 'Pesos',
                                  value: draft.estimatedCost,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    draft.copyWith(estimatedCost: value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _NumberField(
                                  label: 'Feeds',
                                  value: draft.servings,
                                  isEnabled: !_isSaving,
                                  onChanged: (int? value) => _update(
                                    draft.copyWith(servings: value ?? 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (draft.costPerServingLabel case final String each)
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
                            ingredients: draft.ingredients,
                            isEnabled: !_isSaving,
                            onChanged: (List<DraftIngredient> ingredients) =>
                                _update(
                                  draft.copyWith(ingredients: ingredients),
                                ),
                          ),
                        ],
                      ),

                      _FormSection(
                        title: 'How to cook it',
                        subtitle: 'Optional. One step at a time.',
                        children: <Widget>[
                          _StepEditor(
                            steps: draft.instructions,
                            isEnabled: !_isSaving,
                            onChanged: (List<String> steps) =>
                                _update(draft.copyWith(instructions: steps)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SaveBar(
                  label: widget.isEditing ? 'Save changes' : 'Save meal',
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
  const _Header({required this.title, required this.onCancel});

  final String title;
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
                title,
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
                    initialValue: ingredient.name,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Unit', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.space2),
        // `AppSelect`, not `DropdownButton` (Sprint 49b). The stock dropdown
        // opened a floating menu with Material's own metrics right next to two of
        // this app's text fields, which made the row look like three controls
        // from two different products.
        AppSelect<String>(
          title: 'Unit',
          value: unit,
          isEnabled: isEnabled,
          style: AppSelectStyle.field,
          options: <AppSelectOption<String>>[
            for (final String value in DraftIngredient.units)
              AppSelectOption<String>(value: value, label: value),
          ],
          onSelected: (String? value) {
            if (value != null) {
              onChanged(value);
            }
          },
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
                  initialValue: steps[index],
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
    required this.label,
    required this.missing,
    required this.isSaving,
    required this.onSave,
  });

  final String label;
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
              label: label,
              isLoading: isSaving,
              onPressed: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

/// Waiting for the meal an edit is about.
///
/// The header is drawn already, so cancelling works before the meal arrives —
/// a form you cannot back out of while it loads is a trap on a slow connection.
class _FormLoading extends StatelessWidget {
  const _FormLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(title: 'Edit meal', onCancel: () async => context.pop()),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

/// The meal could not be read, so there is nothing to edit.
class _FormLoadFailure extends StatelessWidget {
  const _FormLoadFailure({required this.failure, required this.onRetry});

  final AppException failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(title: 'Edit meal', onCancel: () async => context.pop()),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppLayout.screenMargin),
                  child: ErrorState(
                    kind: failure.errorStateKind,
                    body: failure.displayMessage,
                    errorCode: failure.supportCode,
                    onRetry: failure.shouldOfferRetry ? onRetry : null,
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

/// An untouched draft, named so the comparison in `_isStarted` reads as one.
const MealDraft _blank = MealDraft();
