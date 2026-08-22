import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
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

  /// The chosen date, or null for "no date" (Sprint 40).
  DateTime? _expiresOn;

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
    _expiresOn = existing?.expiresOn;
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
    // Offered on an edit too, now that the name is editable — a rename is
    // exactly when somebody wants the vocabulary's spelling rather than their
    // own. Empty until the field is touched, so opening the sheet on an existing
    // item does not fire a query for a name that has not changed.
    final AsyncValue<List<IngredientSuggestion>> suggestions =
        _isEditing && _term.isEmpty
        ? const AsyncData<List<IngredientSuggestion>>(
            <IngredientSuggestion>[],
          )
        : ref.watch(ingredientSuggestionsProvider(_term));

    // **Scrollable, and it has to be.** The sheet's height is capped by its
    // parent, and this Column is not a fixed height: the suggestion chips appear
    // and wrap onto a second line while somebody types, the error banner appears
    // on a failure, and the edit variant carries an extra button. It overflowed by
    // 38 pixels the moment the expiry row was added — which is the same
    // unbounded-content-in-a-bounded-box mistake the dashboard components made
    // three times, and the reason a variable-height sheet should never be a bare
    // Column.
    return SingleChildScrollView(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _isEditing
                          ? AppFormat.sentenceCase(widget.existing!.name)
                          : 'What do you have?',
                      style: context.text.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      // The subtitle carries the instruction, so the heading can
                      // carry the *subject*. On an edit that subject is the
                      // ingredient's own name, which is the one thing the sheet
                      // previously never said.
                      _isEditing
                          ? 'Fix the name, the amount, or when it goes off.'
                          : 'Anything in the kitchen. The amount is optional.',
                      style: context.text.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              // A named way out, because a sheet dismissed only by dragging is a
              // sheet somebody has to discover how to leave.
              AppButton.tertiary(
                label: 'Close',
                size: AppButtonSize.small,
                onPressed: _isSaving ? null : () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),

          // **The name is editable now, on an edit as well as an add.**
          //
          // It used to be hidden while editing, on the argument that the heading
          // already said the name so a field underneath was the same fact twice.
          // The fact was right and the conclusion was wrong: a heading is not a
          // control, and there was no way at all to fix "Garlick" short of
          // deleting the row and adding it again.
          //
          // Not autofocused on an edit. Somebody who opened this sheet from a
          // swipe or a tap is usually here for the amount, and a keyboard over
          // the quantity field is the wrong opening move.
          AppTextField(
            controller: _name,
            label: 'Ingredient',
            hint: 'Chicken, soy sauce, kangkong',
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.none,
            onChanged: (String value) => setState(() => _term = value),
          ),
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

          const SizedBox(height: AppSpacing.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _quantity,
                  label: 'How much',
                  // Two words. The old hint read `Leave blank for "..."` on a
                  // real device — a hint that needs more room than the field it
                  // is in tells the reader nothing at all.
                  hint: 'Optional',
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
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.space4),
          Text('Goes off', style: context.text.label),
          const SizedBox(height: AppSpacing.space2),
          _ExpiryField(
            value: _expiresOn,
            isStaple: widget.existing?.isStaple ?? false,
            onChanged: (DateTime? date) => setState(() => _expiresOn = date),
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

    final PantryItem? existing = widget.existing;

    // Whether this edit changed which *ingredient* the row points at.
    //
    // `pantry_items` is one row per `(household, ingredient)`, so a rename is not
    // an update — it is a different ingredient, resolved or created in the shared
    // vocabulary. Done as **add then remove**, in that order: `add` is idempotent
    // by name and carries the amount over, so if it fails nothing has been lost
    // and the original row is still there.
    final bool isRename =
        existing != null &&
        name.toLowerCase() != existing.name.toLowerCase();

    final AppException? failure = switch ((existing, isRename)) {
      (final PantryItem row, true) => await controller.rename(
        row,
        name: name,
        quantity: quantity,
        unit: _unit.text.trim(),
        expiresOn: _expiresOn,
      ),
      (final PantryItem row, false) => await controller.updateAmount(
        row,
        quantity: quantity,
        unit: _unit.text.trim(),
        expiresOn: _expiresOn,
        clearQuantity: clearQuantity || quantity == null,
        clearExpiry: _expiresOn == null,
      ),
      _ => await controller.add(
        name: name,
        quantity: quantity,
        unit: _unit.text.trim(),
        expiresOn: _expiresOn,
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

/// When it goes off, if anybody wants to say (Sprint 40).
///
/// **A row that reads as a sentence, not a labelled date field.** Most items will
/// never get a date — rice, salt, a bottle of vinegar have no honest answer — so
/// the unset state has to look finished rather than blank. "No date" is the
/// default and says so.
///
/// Shown but disabled on a staple, with the reason. Hiding it would leave somebody
/// wondering why the field they used yesterday has gone; saying "staples never
/// expire here" answers it once (docs/USER_FLOWS.md §12).
class _ExpiryField extends StatelessWidget {
  const _ExpiryField({
    required this.value,
    required this.isStaple,
    required this.onChanged,
  });

  final DateTime? value;
  final bool isStaple;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isStaple) {
      return Row(
        children: <Widget>[
          Icon(
            AppIcons.check,
            size: AppIconSize.xs,
            color: context.colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Text(
              'A staple — we assume this is always in.',
              style: context.text.metadata,
            ),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: AppButton.secondary(
            label: value == null
                ? 'Not tracked'
                : AppFormat.calendarDate(value!),
            leadingIcon: AppIcons.expiring,
            size: AppButtonSize.small,
            onPressed: () => _pick(context),
          ),
        ),
        if (value != null) ...<Widget>[
          const SizedBox(width: AppSpacing.space2),
          AppButton.tertiary(
            label: 'Clear',
            size: AppButtonSize.small,
            onPressed: () => onChanged(null),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime today = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value ?? today.add(const Duration(days: 3)),
      // Backwards as well as forwards. Something already past its date is a thing
      // to record and throw out, and a picker that refuses yesterday makes that
      // impossible to say.
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
      helpText: 'When does it go off?',
    );

    if (picked != null) {
      onChanged(picked);
    }
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
