import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// One choice in an [AppSelect].
@immutable
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.detail,
  });

  /// Null is a real option — "Every cuisine", "All", "No limit".
  final T? value;

  final String label;

  /// A second line, when the label alone does not decide it.
  final String? detail;
}

/// How the trigger is drawn.
enum AppSelectStyle {
  /// Text and a chevron, sitting inside a panel header or beside a caps label.
  inline,

  /// A bordered box the width of its parent, matching the text fields it sits
  /// beside in a form.
  field,
}

/// Choosing one of a few things.
///
/// **Replaces Material's [PopupMenuButton] and [DropdownButton] everywhere**, and
/// the reason is that both of them stop looking like this app the moment they
/// open. The stock menu paints its own white sheet over whatever is behind it,
/// with its own type scale, its own 48-pixel rows and a tick in a leading column
/// the app uses for nothing else — so a tap on a quiet caps-label control produced
/// a floating panel that belonged to a different product, covering the content it
/// was filtering.
///
/// This opens a sheet instead: the app's own surface, the app's own hairlines, the
/// tick on the right where every other confirmation in this app puts it, and
/// nothing covered that matters — the list you are filtering stays above it.
/// Bigger targets, too, which is what a phone wants.
///
/// **Imperative rather than a route**, unlike the sheets in `AppRoute`. Those are
/// destinations and have to survive a deep link; this is a *control*, and a link
/// into "the cuisine menu, open" would be a link to a state with nothing behind
/// it.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
    this.style = AppSelectStyle.inline,
    this.labelOverride,
    this.labelColor,
    this.isEnabled = true,
    super.key,
  });

  /// What the sheet is titled — "Cuisine", "Sort by", "Unit".
  final String title;

  /// The current value. Matched against [AppSelectOption.value].
  final T? value;

  final List<AppSelectOption<T>> options;

  /// Called with the chosen value, which may be null.
  final ValueChanged<T?> onSelected;

  final AppSelectStyle style;

  /// What the trigger says, when the value alone cannot say it.
  ///
  /// The cuisine filter needs this: its state is a *set*, so "three cuisines" is a
  /// state no single option describes, and falling back to the first option would
  /// have the control read "Every cuisine" while three were applied.
  final String? labelOverride;

  /// Overrides the trigger's text colour, for a control that reads as *active*
  /// when it is not on its default — the cuisine filter does this.
  final Color? labelColor;

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final String label =
        labelOverride ??
        options
            .where((AppSelectOption<T> option) => option.value == value)
            .map((AppSelectOption<T> option) => option.label)
            .firstOrNull ??
        (options.isEmpty ? '' : options.first.label);

    return Semantics(
      button: true,
      label: '$title: $label. Tap to change',
      excludeSemantics: true,
      child: PressFeedback(
        onTap: isEnabled ? () => _open(context) : null,
        child: switch (style) {
          AppSelectStyle.inline => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: context.text.labelSmall.copyWith(
                  color: isEnabled
                      ? labelColor ?? colors.textSecondary
                      : colors.textDisabled,
                ),
              ),
              Icon(
                _chevron,
                size: AppIconSize.xs,
                color: isEnabled ? colors.textTertiary : colors.textDisabled,
              ),
            ],
          ),
          AppSelectStyle.field => DecoratedBox(
            decoration: BoxDecoration(
              color: isEnabled ? colors.surface : colors.surfaceMuted,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: colors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space3,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: context.text.bodyMedium.copyWith(
                        color: isEnabled
                            ? labelColor ?? colors.textPrimary
                            : colors.textDisabled,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _chevron,
                    size: AppIconSize.sm,
                    color: isEnabled
                        ? colors.textTertiary
                        : colors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final AppColorScheme colors = context.colors;

    final ({T? value})? chosen = await showModalBottomSheet<({T? value})>(
      context: context,
      // **The root navigator, always.** A sheet on a branch navigator renders
      // under the floating bottom navigation, which this app has now shipped
      // twice — once for the pantry sheet and once before that.
      useRootNavigator: true,
      backgroundColor: colors.surface,
      // Tall lists scroll rather than being cut off — `Unit` has six entries and
      // `Cuisine` has nine, and on a short phone the ninth was the one that
      // mattered.
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.top(AppRadius.xl)),
      builder: (BuildContext sheetContext) =>
          _SelectSheet<T>(title: title, value: value, options: options),
    );

    if (chosen != null) {
      onSelected(chosen.value);
    }
  }

  /// The same chevron the app uses for "there is more here".
  static const IconData _chevron = Icons.keyboard_arrow_down_rounded;
}

/// The sheet itself.
///
/// Returns a record rather than the value, so that *choosing null* — "Every
/// cuisine" — is distinguishable from dismissing the sheet without choosing.
/// Popping with a bare null would make those the same event, and the first one
/// has to clear the filter.
class _SelectSheet<T> extends StatelessWidget {
  const _SelectSheet({
    required this.title,
    required this.value,
    required this.options,
  });

  final String title;
  final T? value;
  final List<AppSelectOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The grabber, so the sheet reads as something you can push away.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.space3,
                  bottom: AppSpacing.space3,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.outlineStrong,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: const SizedBox(
                    width: _grabberWidth,
                    height: _grabberHeight,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.screenMargin,
              ),
              child: Text(title.toUpperCase(), style: context.text.overline),
            ),
            const SizedBox(height: AppSpacing.space2),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final AppSelectOption<T> option = options[index];
                  return _OptionRow<T>(
                    option: option,
                    isSelected: option.value == value,
                    isFirst: index == 0,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _grabberWidth = 36;
  static const double _grabberHeight = 4;
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.isFirst,
  });

  final AppSelectOption<T> option;
  final bool isSelected;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!isFirst)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.screenMargin,
            ),
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: colors.outline),
            ),
          ),
        InkWell(
          onTap: () =>
              Navigator.of(context).pop<({T? value})>((value: option.value)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.screenMargin,
              vertical: AppSpacing.space4,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        option.label,
                        style: context.text.titleSmall.copyWith(
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                      if (option.detail case final String detail) ...<Widget>[
                        const SizedBox(height: AppSpacing.space1),
                        Text(detail, style: context.text.metadata),
                      ],
                    ],
                  ),
                ),
                // On the right, where every other confirmation in this app puts
                // it — and nothing is reserved on the left, so eight unselected
                // rows are eight names rather than eight names and a gutter.
                if (isSelected)
                  Icon(
                    AppIcons.check,
                    size: AppIconSize.sm,
                    color: colors.textPrimary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
