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
import 'package:whats_cooking/features/grocery/domain/entities/grocery_item.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// Adding something to buy, or changing how much (Sprint 42).
///
/// One sheet for both, like the pantry's — same three fields, same write, and the
/// list merges by name anyway, so adding chicken when chicken is on the list *is*
/// an edit.
///
/// **The name field accepts anything.** Suggestions come from the shared
/// vocabulary, but a word it does not know is stored as free text rather than
/// filed into the catalogue — the opposite of what the pantry does, and
/// deliberately: a pantry entry is a standing fact about the kitchen, while "the
/// good soy sauce" written at a shelf is a note to self, and adding it to the
/// shared ingredient list would slowly turn that list into shopping shorthand.
class GroceryItemSheet extends ConsumerStatefulWidget {
  const GroceryItemSheet({this.existing, super.key});

  /// The line being changed, or null when adding.
  final GroceryItem? existing;

  @override
  ConsumerState<GroceryItemSheet> createState() => _GroceryItemSheetState();
}

class _GroceryItemSheetState extends ConsumerState<GroceryItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;

  String _term = '';
  bool _isSaving = false;
  AppException? _failure;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final GroceryItem? existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _quantity = TextEditingController(
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
    final List<IngredientSuggestion> suggestions = _isEditing
        ? const <IngredientSuggestion>[]
        : ref.watch(ingredientSuggestionsProvider(_term)).value ??
              const <IngredientSuggestion>[];

    // Scrollable, for the reason the pantry's sheet is: the chips wrap onto a
    // second line while somebody types and the error banner appears on a failure,
    // so the content is not a fixed height and a bare Column overflows.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppLayout.screenMargin,
        right: AppLayout.screenMargin,
        top: AppSpacing.space5,
        bottom: AppSpacing.space5 + MediaQuery.viewInsetsOf(context).bottom,
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
                          : 'What do we need?',
                      style: context.text.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      _isEditing
                          // It said "change how much we need", which was an
                          // accurate description of a sheet that could not do the
                          // other thing anybody opens it for.
                          ? 'Fix the name or the amount.'
                          : 'Anything at all. The amount is optional.',
                      style: context.text.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              AppButton.tertiary(
                label: 'Close',
                size: AppButtonSize.small,
                onPressed: _isSaving ? null : () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),

          // **Shown on an edit too now** (Sprint 57c).
          //
          // It was add-only, on the reasoning that the heading already says the
          // name so a field underneath would be the same fact twice. That was the
          // same mistake the pantry sheet made and it is the same answer: a
          // heading is not a control. A line imported from a photo lands
          // misspelled, a line typed one-handed in a shop lands wrong, and the
          // only way to correct either was to delete it and start again.
          //
          // `autofocus` only when adding. On an edit the name is usually right
          // and the amount is what is being changed, so opening the keyboard on
          // the wrong field would cost a tap every time.
          AppTextField(
            controller: _name,
            label: 'Item',
            hint: 'Chicken, bay leaves, the good soy sauce',
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.none,
            onChanged: (String value) => setState(() => _term = value),
          ),
          // On an edit as well, and it matters more there than on an add: picking
          // a suggestion resolves the new name against the shared vocabulary,
          // which is what decides the aisle. A renamed line that misses the
          // vocabulary lands in "Everything else".
          //
          // Empty until something is typed — `_term` only moves `onChanged` — so
          // opening the sheet to change an amount shows no chips at all.
          if (suggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.space3),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                for (final IngredientSuggestion suggestion in suggestions)
                  AppFilterChip(
                    label: suggestion.name,
                    isSelected: false,
                    onSelected: (_) {
                      setState(() {
                        _name.text = suggestion.name;
                        _term = suggestion.name;
                        if (_unit.text.trim().isEmpty) {
                          _unit.text = suggestion.defaultUnit;
                        }
                      });
                      AppHaptics.reelTick();
                    },
                  ),
              ],
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
                  hint: 'Optional',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
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

          if (_failure case final AppException problem) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            InlineErrorBanner(
              message: problem.displayMessage ?? problem.message,
              onRetry: _save,
            ),
          ],

          const SizedBox(height: AppSpacing.space5),
          AppButton.primary(
            label: _isEditing ? 'Save' : 'Add to the list',
            size: AppButtonSize.large,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _failure = const ValidationException(
          message: 'Give the item a name.',
        ),
      );
      return;
    }

    final double? quantity = double.tryParse(_quantity.text.trim());

    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final GroceryController controller = ref.read(
      groceryControllerProvider.notifier,
    );

    // Whether this edit changed what the line is called. Case-insensitive, so
    // fixing a capital is not a rename — `add` would resolve to the same
    // ingredient and the round trip would buy nothing.
    final GroceryItem? existing = widget.existing;
    final bool isRename =
        existing != null && name.toLowerCase() != existing.name.toLowerCase();

    final AppException? failure = switch ((existing, isRename)) {
      (final GroceryItem line, true) => await controller.rename(
        line,
        name: name,
        quantity: quantity,
        unit: _unit.text.trim(),
      ),
      (final GroceryItem line, false) => await controller.updateAmount(
        line,
        quantity: quantity,
        unit: _unit.text.trim(),
        clearQuantity: quantity == null,
      ),
      _ => await controller.add(
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
