import 'package:flutter/material.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/features/home/presentation/providers/home_dashboard.dart';

/// Six weeks of food spend, a head (Sprint 47b).
///
/// **The one chart a household watching its money reads more than once.** A list of
/// numbers answers "what did this week cost"; only a shape answers "is it getting
/// worse", which is the question that changes whether somebody cooks tonight.
///
/// **Stacked, cooked under out.** The split is the whole point — two ₱1,400 weeks
/// are different weeks if one of them was four nights out, and that difference is
/// the thing this app can actually do something about. Cooked sits at the bottom
/// because it is the baseline a household always has; eating out is what stacks on
/// top of it.
///
/// Hand-drawn rather than a charting package. Six bars and a baseline is less code
/// than the configuration a library would need, and it inherits the app's palette
/// and its dark mode for free instead of being themed twice.
class SpendChart extends StatelessWidget {
  const SpendChart({required this.weeks, super.key});

  final List<WeekSpend> weeks;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    // Scaled to the tallest bar, not to a round number. A fixed ceiling would make
    // a quiet month look like nothing happened, and the shape is what this is for.
    final double peak = weeks.fold<double>(
      0,
      (double most, WeekSpend week) => week.total > most ? week.total : most,
    );

    if (peak <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('Spend a head', style: context.text.overline)),
            // The axis, as a sentence. A y-axis with four labelled gridlines on a
            // phone is four rows of six-point type nobody reads; the peak is the
            // only number needed to make the bars mean something.
            Text(
              'peak ${AppFormat.peso(peak.round())}',
              style: context.text.metadata,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final (int index, WeekSpend week)
                  in weeks.indexed) ...<Widget>[
                if (index > 0) const SizedBox(width: _gap),
                Expanded(
                  child: _Bar(
                    week: week,
                    peak: peak,
                    cookedColor: colors.series2,
                    outColor: colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Row(
          children: <Widget>[
            // Only the ends are labelled. Six week labels on a phone is a row of
            // abbreviations, and "six weeks ago" to "this week" is the whole axis.
            Expanded(child: Text('6 weeks ago', style: context.text.metadata)),
            Text('this week', style: context.text.metadata),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          children: <Widget>[
            _Key(color: colors.series2, label: 'cooked'),
            const SizedBox(width: AppSpacing.space4),
            _Key(color: colors.primary, label: 'eaten out'),
          ],
        ),
      ],
    );
  }

  /// Tall enough for a difference to be visible, short enough not to push the
  /// action row off a small screen.
  static const double _height = 96;
  static const double _gap = AppSpacing.space2;
}

/// One week.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.week,
    required this.peak,
    required this.cookedColor,
    required this.outColor,
  });

  final WeekSpend week;
  final double peak;
  final Color cookedColor;
  final Color outColor;

  @override
  Widget build(BuildContext context) {
    final double fraction = (week.total / peak).clamp(0.0, 1.0);

    return Semantics(
      label: week.weeksAgo == 0
          ? 'This week, ${AppFormat.peso(week.total.round())} a head'
          : '${week.weeksAgo} weeks ago, '
                '${AppFormat.peso(week.total.round())} a head',
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        // A floor, so a week with a little spend is a visible sliver rather than
        // nothing. A bar of zero height and a week that did not happen look
        // identical, and they are not the same thing.
        heightFactor: week.total > 0 ? fraction.clamp(_minimum, 1) : 0,
        child: ClipRRect(
          borderRadius: AppRadius.borderXs,
          child: Column(
            children: <Widget>[
              if (week.eatenOut > 0)
                Expanded(
                  flex: (week.eatenOut * 100).round().clamp(1, 100000),
                  child: ColoredBox(color: outColor),
                ),
              if (week.cooked > 0)
                Expanded(
                  flex: (week.cooked * 100).round().clamp(1, 100000),
                  child: ColoredBox(color: cookedColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Four percent of the chart. Enough to see, small enough not to lie about it.
  static const double _minimum = 0.04;
}

/// A colour and what it means.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.borderXs,
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Text(label, style: context.text.metadata),
      ],
    );
  }

  static const double _dot = 10;
}

/// What has been eaten this month, by cuisine (Sprint 47b).
///
/// **The variety engine's premise, made visible.** The scorer spends ten points a
/// spin nudging away from the cuisine of the last few dinners, on the grounds that
/// sixty meals across twelve cuisines will happily serve Filipino food five nights
/// running. This is the only place a household can check whether that is working.
///
/// Top four and a remainder. Twelve rows of two-percent bars is a table, and a
/// table of small numbers is the "interesting dashboard nobody opens twice" that
/// docs/project_dev.md cut.
class CuisineMix extends StatelessWidget {
  const CuisineMix({required this.counts, super.key});

  final Map<Cuisine, int> counts;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    final int total = counts.values.fold<int>(0, (int sum, int n) => sum + n);
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final List<(Cuisine, int)> ranked =
        <(Cuisine, int)>[
          for (final MapEntry<Cuisine, int> entry in counts.entries)
            (entry.key, entry.value),
        ]..sort(((Cuisine, int) a, (Cuisine, int) b) {
          final int byCount = b.$2.compareTo(a.$2);
          // Ties broken by cuisine order rather than map order, so the rows do not
          // reshuffle between two refreshes that changed nothing.
          return byCount != 0 ? byCount : a.$1.index.compareTo(b.$1.index);
        });

    final List<(Cuisine, int)> top = ranked.take(_rows).toList();
    final int remainder =
        total - top.fold<int>(0, (int sum, (Cuisine, int) row) => sum + row.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('What we have been eating', style: context.text.overline),
        const SizedBox(height: AppSpacing.space3),
        for (final (int index, (Cuisine, int) row) in top.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.space2),
          _MixRow(
            label: row.$1.label,
            fraction: row.$2 / total,
            color: switch (index) {
              0 => colors.series1,
              1 => colors.series2,
              2 => colors.primary,
              _ => colors.outline,
            },
          ),
        ],
        if (remainder > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.space2),
          _MixRow(
            label: 'Everything else',
            fraction: remainder / total,
            color: colors.outline,
          ),
        ],
      ],
    );
  }

  /// Four. Past that the bars are shorter than their labels.
  static const int _rows = 4;
}

/// One cuisine's share.
class _MixRow extends StatelessWidget {
  const _MixRow({
    required this.label,
    required this.fraction,
    required this.color,
  });

  final String label;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, ${AppFormat.percent(fraction)}',
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: context.text.metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: MiniBarTrack(fraction: fraction, color: color),
          ),
          const SizedBox(width: AppSpacing.space3),
          SizedBox(
            width: _valueWidth,
            child: Text(
              AppFormat.percent(fraction),
              style: context.text.metadata,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Enough for "Mediterranean" to ellipsise gracefully rather than wrap.
  static const double _labelWidth = 86;
  static const double _valueWidth = 34;
}

/// A single horizontal bar on a track.
///
/// Thicker than the dashboard's `MiniBar`, which sits under a figure as a hint.
/// This one *is* the data, so it needs enough weight to be compared across rows.
class MiniBarTrack extends StatelessWidget {
  const MiniBarTrack({required this.fraction, required this.color, super.key});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderXs,
      child: SizedBox(
        height: _height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(color: context.colors.surfaceMuted),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }

  static const double _height = 8;
}
