/// The dashboard vocabulary from `docs/reference_design/dashboards_ref.webp`.
///
/// That reference is a different composition from `reference_img.webp`, and the
/// difference is worth naming, because it is what the app's data screens were
/// missing. `reference_img.webp` is a *browse* language: soft cards, pastel
/// tiles, imagery, generous air. The dashboards reference is a *reading*
/// language, and it is built from six repeated moves:
///
/// 1. **One figure, set huge.** Every panel leads with a single number in
///    display type — not a label and a value on one line, but the number as the
///    headline and everything else subordinate to it.
/// 2. **Tiny caps labels.** `overline` above or below the figure, wide-tracked
///    and grey. The label never competes with the number.
/// 3. **A unit word, small and separate.** "ticket", "a head" — set at metadata
///    size right after the figure, so `10.750 received` reads as one phrase
///    with two weights.
/// 4. **Hairline division instead of boxes.** Columns and rows are separated by
///    one-pixel rules, not by nested cards. It is what makes the reference read
///    as dense rather than cluttered.
/// 5. **A thin progress bar under a figure.** Two or three pixels tall, one
///    series colour against a grey track — a share made visible without a chart.
/// 6. **Segmented controls, not pill rows.** A light track with the active
///    option as a filled dark pill. One control, one answer, no row of things
///    that are not selected.
///
/// These are in `core/` because every data screen wants them: the Meals feed
/// now, Home's spin summary (Sprint 28), and the profile statistics (Sprint 31).
///
/// The colours come from `series1`, `series2` and `seriesTrack` rather than from
/// the brand. A chart segment is not an action, and painting one in primary
/// green would make it compete with the SPIN button.
library;

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/brand_logo.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// A number as a headline, with its label and unit subordinate to it.
///
/// The reference's central move. `184.160` with a tiny "Details" pill under it,
/// or `10.750 received` — the figure carries the weight and the words explain it.
class BigFigure extends StatelessWidget {
  const BigFigure({
    required this.value,
    this.label,
    this.unit,
    this.trailing,
    this.isCompact = false,
    super.key,
  });

  /// The number, already formatted. Formatting is the caller's job: this widget
  /// should not have an opinion about thousands separators or currency.
  final String value;

  /// The tiny caps line above the figure.
  final String? label;

  /// The small word after the figure — "received", "a head", "meals".
  final String? unit;

  /// A delta badge or a small action, level with the figure.
  final Widget? trailing;

  /// Sets the figure at headline rather than display size, for a panel that
  /// carries several figures rather than one.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles text = context.text;

    final TextStyle figure =
        (isCompact ? text.headlineMedium : text.displayLarge).copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label case final String caps) ...<Widget>[
          Text(caps.toUpperCase(), style: text.overline),
          const SizedBox(height: AppSpacing.space1),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Flexible(
              child: Text(
                value,
                style: figure,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit case final String suffix) ...<Widget>[
              const SizedBox(width: AppSpacing.space2),
              Text(suffix, style: text.metadata),
            ],
            if (trailing case final Widget widget) ...<Widget>[
              const SizedBox(width: AppSpacing.space2),
              widget,
            ],
          ],
        ),
      ],
    );
  }
}

/// A small pill carrying a change — `+2,7%` green, `-0,4%` pink.
///
/// The reference puts one beside almost every figure. Two colours only, and the
/// sign is always printed: docs/DESIGN_SYSTEM.md §11 forbids colour carrying a
/// meaning on its own, so the arrow and the sign do the work for anyone who
/// cannot separate the two hues.
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({required this.label, required this.isPositive, super.key});

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppSemanticColor tone = isPositive ? colors.success : colors.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: AppRadius.borderFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: _iconSize,
              color: tone.onSurface,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: context.text.overline.copyWith(color: tone.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  static const double _iconSize = 10;
}

/// A share, as a two-pixel bar.
///
/// The reference's quietest device and one of its most useful: a figure with a
/// thin bar beneath it says "this much of the whole" without a chart, a legend
/// or an axis.
class MiniBar extends StatelessWidget {
  const MiniBar({required this.fraction, this.color, super.key});

  /// Clamped, so a caller that divides by a stale total cannot draw past the
  /// end of the track.
  final double fraction;

  /// Defaults to `series1`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return ClipRRect(
      borderRadius: AppRadius.borderFull,
      child: SizedBox(
        height: _height,
        child: Stack(
          children: <Widget>[
            ColoredBox(color: colors.seriesTrack),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? colors.series1),
            ),
          ],
        ),
      ),
    );
  }

  static const double _height = 4;
}

/// One column of a [StatTrio].
@immutable
class StatColumnData {
  const StatColumnData({
    required this.label,
    required this.value,
    this.unit,
    this.fraction,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;

  /// Draws a [MiniBar] beneath the figure when set.
  final double? fraction;
  final Color? color;

  /// Makes the column tappable — the reference's stat columns double as filters.
  final VoidCallback? onTap;
}

/// Two or three figures across, divided by hairlines.
///
/// The reference's signature block: `Ducktiket 64.640 ticket` beside two
/// siblings, each with a thin bar beneath, separated by one-pixel rules rather
/// than by nested cards.
class StatTrio extends StatelessWidget {
  const StatTrio({required this.columns, super.key});

  final List<StatColumnData> columns;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // `IntrinsicHeight` because the dividers stretch to the tallest column, and
    // stretch needs a bounded height — inside a `ListView` there is none, and the
    // Row hands its children h=Infinity instead. That threw "BoxConstraints
    // forces an infinite height" and took the whole panel down with it.
    //
    // Affordable here in a way it would not be in a list: this is one row of
    // three short columns per panel, not one per item.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, StatColumnData column) in columns.indexed) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                ),
                child: SizedBox(
                  width: 1,
                  child: ColoredBox(color: colors.outline),
                ),
              ),
            Expanded(child: _StatColumn(data: column)),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.data});

  final StatColumnData data;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles text = context.text;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          data.label.toUpperCase(),
          style: text.overline,
          // Two lines, because a third of a phone-width panel is not enough for
          // a two-word caps label and the alternative was "NO LONGER …".
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space1),
        // The unit sits **under** the figure, not beside it. Beside it, the two
        // shared a third of the panel and the figure lost: "₱150 a head" came
        // out as "₱1… a head", which is the one part of a budget nobody can
        // guess. Stacked, the figure gets the whole column — and it matches
        // `DashboardRow`, which has always put its unit on the line below.
        Text(
          data.value,
          style: text.titleLarge.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (data.unit case final String unit)
          Text(
            unit,
            style: text.metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (data.fraction case final double fraction) ...<Widget>[
          const SizedBox(height: AppSpacing.space2),
          MiniBar(fraction: fraction, color: data.color),
        ],
      ],
    );

    if (data.onTap == null) {
      return content;
    }

    return PressFeedback(
      onTap: data.onTap,
      semanticLabel: '${data.label}: ${data.value} ${data.unit ?? ''}'.trim(),
      expandTouchTarget: false,
      child: content,
    );
  }
}

/// A light track with the selected option as a filled dark pill.
///
/// The reference's `Daily / Weekly / Monthly / Annually`. Used wherever the
/// answer is exactly one of a short list — which is most of what a pill row was
/// being asked to do, badly: a row of pills spends its width showing the options
/// that are *not* chosen.
///
/// Scrolls horizontally rather than compressing, so a fifth option shortens
/// nothing (docs/DESIGN_SYSTEM.md §10's 320 px floor).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Value and label, in the order they should appear.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderFull,
      ),
      child: Padding(
        padding: const EdgeInsets.all(_trackPadding),
        // **Equal shares when they fit, scrolling when they do not.**
        //
        // Neither alone works, because this control has two very different uses.
        // Cook / Eat out is two words and has to fill the track — sized to their
        // own labels they drew a small pill, a word beside it, and a third of the
        // track left empty, which read as a broken row rather than a switch. The
        // meal-type row is six labels on the same track, and forcing equal shares
        // there gave every one of them a sixth of the width: "Br…", "L…", "Di…".
        //
        // So the width decides. Each segment needs enough room for its label; if
        // an equal share is not enough, the row keeps intrinsic widths and
        // scrolls. Measured against the *scaled* text size, so the same control
        // makes the same decision at 1.3x that it makes at 1x.
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double share = options.isEmpty
                ? 0
                : constraints.maxWidth / options.length;

            final double needed = MediaQuery.textScalerOf(
              context,
            ).scale(_minSegmentWidth);

            if (share >= needed) {
              return Row(
                children: <Widget>[
                  for (final (T value, String label) in options)
                    Expanded(
                      child: _Segment<T>(
                        label: label,
                        isSelected: value == selected,
                        onTap: () => onSelected(value),
                      ),
                    ),
                ],
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final (T value, String label) in options)
                    _Segment<T>(
                      label: label,
                      isSelected: value == selected,
                      onTap: () => onSelected(value),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static const double _trackPadding = 4;

  /// The narrowest a segment can be and still read.
  ///
  /// Roughly the width of "Breakfast" in `labelSmall` plus the segment's own
  /// horizontal padding. Below this a label is an abbreviation, and a row of
  /// abbreviations is worse than a row you have to scroll.
  static const double _minSegmentWidth = 92;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return PressFeedback(
      onTap: onTap,
      semanticLabel: label,
      semanticHint: isSelected ? 'Selected' : null,
      expandTouchTarget: false,
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.curveFast,
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
        decoration: BoxDecoration(
          // Near-black, as the reference's active segment is — not the brand
          // green, which belongs to actions.
          color: isSelected ? colors.series2 : null,
          borderRadius: AppRadius.borderFull,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.text.labelSmall.copyWith(
            color: isSelected ? colors.surface : colors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static const double _height = 34;
}

/// A white panel with a titled header.
///
/// The reference's card: a small dark disc holding a glyph, the title beside it,
/// and an optional control on the right — `Today's Increase` with
/// `Get Report for ⌄`. The header is separated from the body by air rather than
/// by a rule, and the rules are saved for dividing the body's own rows.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;

  /// A menu chip, a link, or a delta — whatever the panel's one control is.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title case final String heading) ...<Widget>[
            _PanelHeader(title: heading, icon: icon, trailing: trailing),
            const SizedBox(height: AppSpacing.space5),
          ],
          child,
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Row(
      children: <Widget>[
        if (icon case final IconData glyph) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.series2,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: _discSize,
              child: Center(
                child: Icon(glyph, size: AppIconSize.xs, color: colors.surface),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
        ],
        Expanded(
          child: Text(
            title,
            style: context.text.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing case final Widget widget) ...<Widget>[
          const SizedBox(width: AppSpacing.space2),
          widget,
        ],
      ],
    );
  }

  static const double _discSize = 26;
}

/// A hairline, for dividing rows inside a panel.
class DashboardRule extends StatelessWidget {
  const DashboardRule({this.inset = 0, super.key});

  /// Indents the rule, so it starts under the text rather than cutting across a
  /// leading glyph.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: context.colors.outline),
      ),
    );
  }
}

/// One row of a dashboard table.
///
/// The reference's country rows: a flag, a name, then the figure right-aligned
/// with its unit beneath and a share beside it. Everything optional except the
/// name, because the same row serves a table of platforms, of countries and of
/// meals.
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.unit,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;

  /// A glyph, an avatar, or a coloured series dot.
  final Widget? leading;

  /// The tiny caps line under the name.
  final String? subtitle;

  /// The figure, right-aligned.
  final String? value;

  /// The small word under the figure.
  final String? unit;

  /// A delta badge or a chevron.
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles text = context.text;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      child: Row(
        children: <Widget>[
          if (leading case final Widget widget) ...<Widget>[
            widget,
            const SizedBox(width: AppSpacing.space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle case final String caps) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    caps.toUpperCase(),
                    style: text.overline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (value case final String figure) ...<Widget>[
            const SizedBox(width: AppSpacing.space3),
            // **`Flexible`, or the value starves the title.**
            //
            // This was a bare `Column`, which in a `Row` is a non-flex child and
            // therefore takes its full intrinsic width — leaving the `Expanded`
            // title whatever is left. With a short figure like "₱84" that is
            // invisible; with a long one it is brutal. "Food preferences" beside
            // "Filipino, Japanese · 1 avoided" rendered as "Food pr / efere…",
            // two characters a line.
            //
            // Loose flex, so a short figure still takes only what it needs and the
            // title keeps the rest — the common case is unchanged.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    figure,
                    style: text.titleMedium.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (unit case final String suffix) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(suffix, style: text.overline, maxLines: 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return _withTrailing(content);
    }

    // The trailing widget is a **sibling** of the tapped region, not a child of
    // it. A heart there is an independent target and must not open the meal
    // (docs/COMPONENTS.md §4) — and inside `PressFeedback` it would do both,
    // exactly as it did when the meal card briefly nested one.
    return _withTrailing(
      PressFeedback(
        onTap: onTap,
        semanticLabel: <String?>[
          title,
          subtitle,
          value == null ? null : '$value ${unit ?? ''}'.trim(),
        ].whereType<String>().join('. '),
        expandTouchTarget: false,
        child: content,
      ),
    );
  }

  /// Places [trailing] beside [row], outside whatever tap region [row] carries.
  Widget _withTrailing(Widget row) {
    if (trailing case final Widget widget) {
      return Row(
        children: <Widget>[
          Expanded(child: row),
          const SizedBox(width: AppSpacing.space2),
          widget,
        ],
      );
    }
    return row;
  }
}

/// Three actions across the foot of a panel, divided by hairlines.
///
/// The reference's `Billing & Transactions | Top Performing Countries | Target
/// Sales Breakdown`: a small dark rounded square holding a glyph, then a label
/// of one or two lines, centred.
class DashboardActionRow extends StatelessWidget {
  const DashboardActionRow({required this.actions, super.key});

  final List<DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // Same reason as `StatTrio`: full-height dividers need a bounded height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int index, DashboardAction action)
              in actions.indexed) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                ),
                child: SizedBox(
                  width: 1,
                  child: ColoredBox(color: colors.outline),
                ),
              ),
            Expanded(child: _ActionTile(action: action)),
          ],
        ],
      ),
    );
  }
}

/// One entry in a [DashboardActionRow].
@immutable
class DashboardAction {
  const DashboardAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final DashboardAction action;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isEnabled = action.onTap != null;

    return PressFeedback(
      onTap: action.onTap,
      semanticLabel: action.label,
      expandTouchTarget: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: isEnabled ? colors.series2 : colors.surfaceMuted,
                borderRadius: AppRadius.borderSm,
              ),
              child: SizedBox.square(
                dimension: _tileSize,
                child: Center(
                  child: Icon(
                    action.icon,
                    size: AppIconSize.xs,
                    color: isEnabled ? colors.surface : colors.textDisabled,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              action.label,
              style: context.text.overline.copyWith(
                color: isEnabled ? colors.textSecondary : colors.textDisabled,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static const double _tileSize = 30;
}

/// The screen header from the reference.
///
/// The product mark, the screen's name beside it, a tappable context line
/// beneath, and circular actions on the right — the reference's `GC Global
/// Connect / 37 Members ⌄` with its settings and member buttons.
///
/// The reference puts an organisation's monogram in that first slot, and this
/// carried two initials there for the same reason. It now carries [BrandLogo]
/// instead, because a monogram of the product is a worse thing than the product's
/// own mark: the mark is the only place the app is ever branded inside itself,
/// and the two dashboards are the screens a signed-in household actually lives
/// on. Every other placement — welcome, onboarding, the launch window — is
/// somewhere they pass once.
///
/// The lettering inside it is not legible at [_markSize] and is not meant to be.
/// What reads at this size is the silhouette: a dark green roundel under a white
/// dome. That is what makes it recognisable in a header, the same way an icon on
/// a home screen is recognised by its shape long before anything written on it.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.title,
    this.subtitle,
    this.onSubtitleTap,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSubtitleTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Row(
      children: <Widget>[
        // Drawn plain, with nothing behind it. The mark is already a roundel, so
        // a filled chip would put a square behind a circle and read as two marks
        // fighting rather than one — and the fill it used to have was the accent,
        // which the mark's own green then sat inside.
        //
        // Decorative, so no semantic label: the title next to it is what a screen
        // reader needs from this row, and announcing the product on every
        // dashboard would be noise before the useful part.
        const BrandLogo(height: _markSize),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: context.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle case final String line)
                PressFeedback(
                  onTap: onSubtitleTap,
                  semanticLabel: onSubtitleTap == null ? null : line,
                  expandTouchTarget: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // **`Flexible`, and it is load-bearing.** A `Row` hands its
                      // non-flex children an *unbounded* main-axis constraint, so
                      // this `Text` measured at its full intrinsic width and the
                      // `maxLines`/`ellipsis` above never came into play — the Row
                      // simply reported a size wider than the `Expanded` that
                      // contains it, and the subtitle ran underneath the action
                      // circles to its right.
                      //
                      // Visible on a phone as "the catalogue and yours" printed
                      // under a search button. The same unbounded-constraints
                      // family as the `stretch`-inside-a-`ListView` bugs, and
                      // invisible in a release build because Flutter's overflow
                      // stripe is a debug-only paint.
                      Flexible(
                        child: Text(
                          line,
                          style: context.text.metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onSubtitleTap != null)
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: AppIconSize.xs,
                          color: colors.textTertiary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final Widget action in actions) ...<Widget>[
          const SizedBox(width: AppSpacing.space2),
          action,
        ],
      ],
    );
  }

  /// A shade over the 36 the reference's monogram uses.
  ///
  /// A solid tile carries visual weight from its fill, and this has none — a
  /// transparent mark in the same box reads smaller than the square it replaced.
  /// 40 still fits the row, whose height comes from the title and context line
  /// beside it rather than from here.
  static const double _markSize = 40;
}
