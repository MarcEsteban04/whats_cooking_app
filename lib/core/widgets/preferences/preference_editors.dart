import 'package:flutter/material.dart';
import 'package:whats_cooking/core/constants/app_constants.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/chips/cuisine_chip.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/preferences/selectable_tile.dart';

/// The six preference editors.
///
/// In `core/widgets/preferences/` because docs/COMPONENTS.md §18b puts them
/// there: "Onboarding introduced these; profile now shares them… once a second
/// feature needed them — a user must meet the same cuisine grid on day one and on
/// day thirty."
///
/// Each takes a plain value and reports a plain value. None of them knows about
/// onboarding's step model or the profile's save button, which is what lets both
/// use them unchanged.
///
/// The shape of each follows §18b's rule: **chips where the answer set is large
/// and multi-select, tiles where the answers are few and each deserves reading.**
/// "A chip row reads as *pick several from many* and a tile list reads as *pick
/// one, and read it properly*."

/// Favourite cuisines — many, multi-select, so chips.
class CuisinePicker extends StatelessWidget {
  const CuisinePicker({
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
            isSelected: selected.contains(cuisine),
            onSelected: (bool isSelected) =>
                onChanged(_toggled<Cuisine>(selected, cuisine, isSelected)),
          ),
      ],
    );
  }
}

/// Dietary needs — many, multi-select, so chips.
class DietaryPicker extends StatelessWidget {
  const DietaryPicker({
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
            onSelected: (bool isSelected) =>
                onChanged(_toggled<DietaryTag>(selected, tag, isSelected)),
          ),
      ],
    );
  }
}

/// Foods to avoid — free text, because the answer set is the user's vocabulary.
///
/// A list to pick from cannot cover what people actually avoid on their first
/// day: "bagoong", "coriander", "anything with bones". docs/USER_FLOWS.md §5
/// calls a disliked food "the single most valuable thing a user can tell us", so
/// the input must not be narrower than what they would say.
class DislikesEditor extends StatefulWidget {
  const DislikesEditor({
    required this.foods,
    required this.onChanged,
    super.key,
  });

  final List<String> foods;
  final ValueChanged<List<String>> onChanged;

  @override
  State<DislikesEditor> createState() => _DislikesEditorState();
}

class _DislikesEditorState extends State<DislikesEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final String value = _controller.text.trim();

    // Blanks, duplicates and anything past the ceiling are ignored in silence.
    // The schema rejects all three anyway
    // (supabase/migrations/…_onboarding_dislikes.sql), and an error message for
    // adding the same thing twice is noise rather than help.
    final bool isDuplicate = widget.foods.any(
      (String food) => food.toLowerCase() == value.toLowerCase(),
    );

    if (value.isEmpty || isDuplicate || widget.foods.length >= maxFoods) {
      _controller.clear();
      setState(() {});
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
                  // Rendered selected, and tapping removes it: these are things
                  // the user added, so taking one back is the only action left.
                  isSelected: true,
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

  /// The schema's ceiling on the array.
  static const int maxFoods = 50;
}

/// Default budget — few options, each worth reading, so tiles.
class BudgetPicker extends StatelessWidget {
  const BudgetPicker({
    required this.budget,
    required this.onChanged,
    super.key,
  });

  final int? budget;

  /// Null clears it, which means *no preference* rather than zero.
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
            icon: AppIcons.budget,
            isSelected: budget == preset,
            onSelected: () => onChanged(budget == preset ? null : preset),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        SelectableTile(
          title: 'No budget in mind',
          caption: 'Show me everything',
          icon: AppIcons.more,
          isSelected: budget == null,
          onSelected: () => onChanged(null),
        ),
      ],
    );
  }

  static String _captionFor(int preset) => switch (preset) {
    100 => 'Cheap and cheerful',
    200 => 'A normal weeknight',
    300 => 'A bit of a treat',
    _ => 'Going all out',
  };
}

/// Maximum cooking time — few options, so tiles.
class CookingTimePicker extends StatelessWidget {
  const CookingTimePicker({
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
            icon: AppIcons.cookingTime,
            isSelected: minutes == option,
            onSelected: () => onChanged(minutes == option ? null : option),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        SelectableTile(
          title: 'However long it takes',
          caption: 'No limit',
          icon: AppIcons.meals,
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

/// Who you cook for — three options, so tiles.
class CookingForPicker extends StatelessWidget {
  const CookingForPicker({
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
            icon: _cookingForIcon(option),
            isSelected: selected == option,
            onSelected: () => onChanged(option),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}

/// [source] with [value] added or removed.
Set<T> _toggled<T>(Set<T> source, T value, bool isSelected) {
  final Set<T> next = <T>{...source};
  if (isSelected) {
    next.add(value);
  } else {
    next.remove(value);
  }
  return next;
}

/// How long before the roulette may offer the same meal again (Sprint 32).
///
/// A choice rather than a number field, because the question is not "how many
/// days" — it is "how often do you mind repeating". Households differ more here
/// than anywhere else in these preferences: one cooks a rotation of six things
/// and wants three days, another never repeats inside a month.
///
/// **"We do not mind" is a real option, not an absent one.** Somebody cooking for
/// one may genuinely be happy eating the same thing twice, and an app that
/// treated that as unset would keep overriding them. Zero is stored, and the
/// engine honours it.
class RepetitionWindowPicker extends StatelessWidget {
  const RepetitionWindowPicker({
    required this.days,
    required this.onChanged,
    super.key,
  });

  /// Null means the app's default. Zero means no exclusion at all.
  final int? days;

  /// Called with null to go back to the default.
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectableTile(
          title: 'Use the default',
          caption: 'A couple of days',
          icon: AppIcons.spin,
          isSelected: days == null,
          onSelected: () => onChanged(null),
        ),
        const SizedBox(height: AppSpacing.space3),
        for (final (int option, String title, String caption)
            in _options) ...<Widget>[
          SelectableTile(
            title: title,
            caption: caption,
            icon: option == 0 ? AppIcons.refresh : AppIcons.plannerActive,
            isSelected: days == option,
            onSelected: () => onChanged(option),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }

  /// Deliberately coarse. "Six days or seven" is not a distinction anybody has
  /// an opinion about, and offering it would imply the engine is more precise
  /// than it is.
  static const List<(int, String, String)> _options = <(int, String, String)>[
    (0, 'We do not mind', 'Repeats are fine'),
    (3, 'Three days', 'A short rotation'),
    (7, 'A week', 'One of each, most weeks'),
    (30, 'A month', 'Never the same thing twice'),
  ];
}

/// The glyph for each [CookingFor] option.
///
/// Mapped here rather than on the enum because `core/domain` imports nothing —
/// it is pure Dart on purpose — and pulling Flutter into it for one `IconData`
/// would be a poor trade for a glyph a single widget needs.
IconData _cookingForIcon(CookingFor option) => switch (option) {
  CookingFor.justMe => Icons.person_outline_rounded,
  CookingFor.withPartner => Icons.people_outline_rounded,
  CookingFor.family => Icons.groups_outlined,
};
