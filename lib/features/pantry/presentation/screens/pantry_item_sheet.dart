import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// Putting something in the kitchen, or changing what is there (Sprint 39).
///
/// One sheet for both, because they are the same three fields and the same write —
/// `pantry_items` is unique on `(household_id, ingredient_id)`, so adding chicken
/// when chicken is already in *is* an edit. A separate edit screen would be a
/// second form to keep in step with the first, for a difference the database does
/// not make.
///
/// **The name is the only required field**, and the amount is deliberately
/// optional. Somebody standing at an open fridge is answering *is there chicken*,
/// and a required quantity makes the fast answer the slow one — see
/// [PantryItem]'s own note on why null is the common case rather than a gap.
class PantryItemSheet extends ConsumerStatefulWidget {
  const PantryItemSheet({this.existing, super.key});

  /// The item being changed, or null when adding.
  final PantryItem? existing;

  @override
  ConsumerState<PantryItemSheet> createState() => _PantryItemSheetState();
}

class _PantryItemSheetState extends ConsumerState<PantryItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;

  /// What the suggestion list is currently answering.
  String _term = '';

  bool _isSaving = false;
  AppException? _failure;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final PantryItem? existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _quantity = TextEditingController(
      // The stored double, printed the way the row prints it — so opening the
      // sheet on "4 pc" shows "4" rather than "4.0".
      text: switch (existing?.quantity) {
        final double value when value == value.roundToDouble() =>
          value.toStringAsFixed(0),
        final double value => value.toStringAsFixed(1),
        null => '',
      },
    );
    _unit = TextEditingController(text: existing?.unit ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only asked for while adding. Editing already has its ingredient resolved,
    // and offering to change the name would be offering to turn the chicken row
    // into a rice row — which is a delete and an add, not an edit.
    final AsyncValue<List<IngredientSuggestion>> suggestions = _isEditing
        ? const AsyncData<List<IngredientSuggestion>>(
            <IngredientSuggestion>[],
          )
        : ref.watch(ingredientSuggestionsProvider(_term));

    return Padding(
      padding: EdgeInsets.only(
        left: AppLayout.screenMargin,
        right: AppLayout.screenMargin,
        top: AppSpacing.space5,
        // Clears the keyboard. Without this the unit field sits behind it on a
        // short screen, which is the field somebody is most likely to be in.
        bottom:
            AppSpacing.space5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _isEditing ? 'How much is left?' : 'What do you have?',
            style: context.text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space5),

          AppTextField(
            controller: _name,
            label: 'Ingredient',
            hint: 'Chicken, soy sauce, kangkong',
            autofocus: !_isEditing,
            // Locked while editing rather than hidden, so the sheet still says
            // what is being changed.
            isReadOnly: _isEditing,
            textCapitalization: TextCapitalization.none,
            onChanged: (String value) => setState(() => _term = value),
          ),

          if (!_isEditing) ...<Widget>[
            const SizedBox(height: AppSpacing.space3),
            _Suggestions(
              suggestions: suggestions,
              onPicked: (IngredientSuggestion picked) {
                setState(() {
                  _name.text = picked.name;
                  _term = picked.name;
                  // Only pre-filled when empty, so a unit already typed is never
                  // overwritten by a tap meant to fix a spelling.
                  if (_unit.text.trim().isEmpty) {
                    _unit.text = picked.defaultUnit;
                  }
                });
                AppHaptics.reelTick();
              },
            ),
          ],

          const SizedBox(height: AppSpacing.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _quantity,
                  label: 'How much',
                  hint: 'Leave blank for "some"',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    // Digits and at most one separator. A pantry amount is never
                    // negative and never an expression.
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: AppTextField(
                  controller: _unit,
                  label: 'Unit',
                  hint: 'g, pc, bottle',
                ),
              ),
            ],
          ),

          if (_failure case final AppException problem) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            InlineErrorBanner(
              message: problem.displayMessage ?? problem.message,
              onRetry: _save,
            ),
          ],

          const SizedBox(height: AppSpacing.space5),
          AppButton.primary(
            label: _isEditing ? 'Save' : 'Add to the kitchen',
            size: AppButtonSize.large,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),

          if (_isEditing) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Align(
              child: AppButton.tertiary(
                // "Some" is a real amount, so going back to it needs its own way
                // out — an empty quantity field cannot mean it, because an empty
                // field is also what somebody sees before they type.
                label: 'Just say we have some',
                size: AppButtonSize.small,
                onPressed: _isSaving ? null : () => _save(clearQuantity: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save({bool clearQuantity = false}) async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _failure = const ValidationException(
          message: 'Give the ingredient a name.',
        ),
      );
      return;
    }

    final double? quantity = clearQuantity
        ? null
        : double.tryParse(_quantity.text.trim());

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final PantryController controller = ref.read(
      pantryControllerProvider.notifier,
    );

    final AppException? failure = switch (widget.existing) {
      final PantryItem existing => await controller.updateAmount(
        existing,
        quantity: quantity,
        unit: _unit.text.trim(),
        clearQuantity: clearQuantity || quantity == null,
      ),
      null => await controller.add(
        name: name,
        quantity: quantity,
        unit: _unit.text.trim(),
      ),
    };

    if (!mounted) {
      return;
    }

    if (failure != null) {
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      return;
    }

    AppHaptics.reveal();
    context.pop();
  }
}

/// Names the vocabulary already knows.
///
/// Chips rather than a dropdown list. The list is at most eight short words, and a
/// row of chips is one tap from anywhere in it — where a dropdown asks somebody to
/// stop typing, look down, and aim.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPicked});

  final AsyncValue<List<IngredientSuggestion>> suggestions;
  final ValueChanged<IngredientSuggestion> onPicked;

  @override
  Widget build(BuildContext context) {
    final List<IngredientSuggestion> found =
        suggestions.value ?? const <IngredientSuggestion>[];

    // Nothing at all rather than an empty row. A blank strip that appears and
    // disappears under the field while typing is more distracting than useful,
    // and "no suggestions" is not information anybody needs — whatever they typed
    // will be created for them.
    if (found.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final IngredientSuggestion suggestion in found)
          AppFilterChip(
            label: suggestion.name,
            isSelected: false,
            onSelected: (_) => onPicked(suggestion),
          ),
      ],
    );
  }
}
