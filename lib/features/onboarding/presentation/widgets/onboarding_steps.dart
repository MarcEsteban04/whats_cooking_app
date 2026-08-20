import 'package:flutter/material.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/chips/cuisine_chip.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/preferences/selectable_tile.dart';
import 'package:whats_cooking/features/onboarding/domain/entities/onboarding_answers.dart';

/// The seven question bodies.
///
/// Two shapes, chosen by the rule in docs/COMPONENTS.md §18b: **chips where the
/// answer set is large and multi-select, tiles where the answers are few and each
/// deserves reading.** "A chip row reads as *pick several from many* and a tile
/// list reads as *pick one, and read it properly*."
///
/// So cuisines, dislikes and dietary needs are chips; budget, cooking time and
/// who-you-cook-for are tiles.

/// Step 1 — the name.
class NameStep extends StatelessWidget {
  const NameStep({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'Your name',
      hint: 'Marc',
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      // No validator. The step is skippable, and a required-field error on a
      // question nobody has to answer is the kind of friction §5 warns costs
      // you the user.
      onChanged: (_) => onChanged(),
    );
  }
}

/// Step 2 — favourite cuisines.
class CuisinesStep extends StatelessWidget {
  const CuisinesStep({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<Cuisine> selected;
  final ValueChanged<Set<Cuisine>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final Cuisine cuisine in Cuisine.values)
          CuisineChip(
            cuisine: cuisine.label,
            emoji: cuisine.emoji,
            isSelected: selected.contains(cuisine),
            onSelected: (bool isSelected) {
              onChanged(
                <Cuisine>{...selected, if (isSelected) cuisine}..removeWhere(
                  (Cuisine item) => !isSelected && item == cuisine,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Step 3 — foods to avoid.
///
/// Free text rather than a list to pick from, because the ingredient catalogue
/// cannot cover what people actually avoid on their first day — "bagoong",
/// "cilantro", "anything with bones". §5 calls a disliked food "the single most
/// valuable thing a user can tell us", so the input must not be narrower than
/// their vocabulary.
class DislikesStep extends StatefulWidget {
  const DislikesStep({required this.foods, required this.onChanged, super.key});

  final List<String> foods;
  final ValueChanged<List<String>> onChanged;

  @override
  State<DislikesStep> createState() => _DislikesStepState();
}

class _DislikesStepState extends State<DislikesStep> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final String value = _controller.text.trim();

    // Silently ignores blanks and duplicates. The schema rejects both anyway
    // (supabase/migrations/…_onboarding_dislikes.sql), and an error message for
    // adding the same thing twice is noise.
    if (value.isEmpty ||
        widget.foods.any(
          (String food) => food.toLowerCase() == value.toLowerCase(),
        ) ||
        widget.foods.length >= _maxFoods) {
      _controller.clear();
      return;
    }

    widget.onChanged(<String>[...widget.foods, value]);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: _controller,
          label: 'Something you avoid',
          hint: 'Fish, coriander, anything spicy…',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          onChanged: (_) => setState(() {}),
          suffix: AppIconButton(
            icon: AppIcons.add,
            semanticLabel: 'Add this food',
            iconSize: AppIconSize.sm,
            onPressed: _controller.text.trim().isEmpty ? null : _add,
          ),
        ),
        if (widget.foods.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              for (final String food in widget.foods)
                AppFilterChip(
                  label: food,
                  icon: AppIcons.clear,
                  isSelected: true,
                  // Selected-looking and tapping removes it: these are things
                  // the user added, so the only action left is to take one back.
                  onSelected: (_) => widget.onChanged(
                    widget.foods.where((String item) => item != food).toList(),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// The schema's ceiling.
  static const int _maxFoods = 50;
}

/// Step 4 — dietary needs.
class DietaryStep extends StatelessWidget {
  const DietaryStep({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Set<DietaryTag> selected;
  final ValueChanged<Set<DietaryTag>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final DietaryTag tag in DietaryTag.values)
          AppFilterChip(
            label: tag.label,
            isSelected: selected.contains(tag),
            onSelected: (bool isSelected) {
              onChanged(
                <DietaryTag>{
                  ...selected,
                  if (isSelected) tag,
                }..removeWhere((DietaryTag item) => !isSelected && item == tag),
              );
            },
          ),
      ],
    );
  }
}

/// Step 5 — the default budget.
class BudgetStep extends StatelessWidget {
  const BudgetStep({required this.budget, required this.onChanged, super.key});

  final int? budget;

  /// Null clears the budget, which means *no preference* rather than zero.
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final int preset in AppConstants.budgetPresets) ...<Widget>[
          SelectableTile(
            title: AppFormat.peso(preset),
            caption: _captionFor(preset),
            emoji: '💰',
            isSelected: budget == preset,
            onSelected: () => onChanged(budget == preset ? null : preset),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        SelectableTile(
          title: 'No budget in mind',
          caption: 'Show me everything',
          emoji: '🤷',
          isSelected: budget == null,
          onSelected: () => onChanged(null),
        ),
      ],
    );
  }

  String _captionFor(int preset) => switch (preset) {
    100 => 'Cheap and cheerful',
    200 => 'A normal weeknight',
    300 => 'A bit of a treat',
    _ => 'Going all out',
  };
}

/// Step 6 — maximum cooking time.
class CookingTimeStep extends StatelessWidget {
  const CookingTimeStep({
    required this.minutes,
    required this.onChanged,
    super.key,
  });

  final int? minutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int option, String caption) in _options) ...<Widget>[
          SelectableTile(
            title: AppFormat.cookingTime(option),
            caption: caption,
            emoji: '⏱️',
            isSelected: minutes == option,
            onSelected: () => onChanged(minutes == option ? null : option),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        SelectableTile(
          title: 'However long it takes',
          caption: 'No limit',
          emoji: '🍲',
          isSelected: minutes == null,
          onSelected: () => onChanged(null),
        ),
      ],
    );
  }

  static const List<(int, String)> _options = <(int, String)>[
    (15, 'Barely cooking'),
    (30, 'A normal weeknight'),
    (45, 'I have some time'),
    (90, 'A proper cook'),
  ];
}

/// Step 7 — who you cook for.
class CookingForStep extends StatelessWidget {
  const CookingForStep({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final CookingFor? selected;
  final ValueChanged<CookingFor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final CookingFor option in CookingFor.values) ...<Widget>[
          SelectableTile(
            title: option.label,
            caption: option.caption,
            emoji: switch (option) {
              CookingFor.justMe => '🍽️',
              CookingFor.withPartner => '❤️',
              CookingFor.family => '👨‍👩‍👧',
            },
            isSelected: selected == option,
            onSelected: () => onChanged(option),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}
