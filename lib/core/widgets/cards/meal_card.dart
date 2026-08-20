import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';

/// Everything a [MealCard] renders.
///
/// A presentation model rather than the domain `Meal` entity, because `core/`
/// cannot depend on a feature (docs/ARCHITECTURE.md §2.3). It also keeps the
/// card renderable from a search result, a planner row or an AI suggestion,
/// none of which carry a full meal.
@immutable
class MealCardData {
  const MealCardData({
    required this.id,
    required this.name,
    this.description,
    this.cuisine,
    this.category,
    this.difficulty,
    this.cookingTimeMinutes,
    this.estimatedCost,
    this.servings,
    this.isFavorite = false,
    this.isMine = false,
    this.contextLine,
  });

  /// Seeds the card's accent, so a meal keeps the same colour across launches
  /// (docs/DESIGN_SYSTEM.md §9).
  final String id;
  final String name;

  /// The first line or two of the meal's own description.
  ///
  /// The card carries no imagery, so this fills the space a photograph used to —
  /// and it does the job better, because it says something about the food rather
  /// than merely decorating it.
  final String? description;

  final String? cuisine;
  final String? category;
  final String? difficulty;
  final int? cookingTimeMinutes;

  /// Pesos, for [servings] people.
  final num? estimatedCost;
  final int? servings;

  final bool isFavorite;

  /// Marks a meal this household wrote itself, so it is distinguishable from the
  /// catalogue in a feed that mixes both.
  final bool isMine;

  /// The result form's optional line — "Loved by both of you".
  final String? contextLine;

  /// `Filipino · Dinner`, with missing parts dropped.
  String get contextLabel => AppFormat.metadata(<String?>[cuisine, category]);

  /// `Dinner · 45 min · Easy` — everything except the cuisine, which the rail
  /// and the pill already carry.
  ///
  /// One line rather than a pill each. docs/design_ui.md §15 asks for "minimal
  /// metadata", and six pills per card across twenty cards is a screen of grey
  /// lozenges — the opposite of minimal.
  String get detailLine => AppFormat.metadata(<String?>[
    category,
    cookingTimeMinutes == null
        ? null
        : AppFormat.cookingTime(cookingTimeMinutes!),
    difficulty,
  ]);

  /// What one plate costs, which is what every budget question in the app means.
  num? get costPerServing => estimatedCost == null || servings == null
      ? estimatedCost
      : estimatedCost! / servings!;

  String? get formattedCost =>
      estimatedCost == null ? null : AppFormat.peso(estimatedCost!);

  /// `₱65`, the figure a reader can compare between meals.
  String? get formattedCostPerServing {
    final num? each = costPerServing;
    return each == null ? null : AppFormat.peso(each);
  }
}

/// The three forms of the meal card (docs/COMPONENTS.md §4).
enum MealCardVariant {
  /// The Meals tab: full width, name-led, a coloured cuisine rail.
  feed,

  /// History, planner, search: a single line with its metadata beneath.
  compact,

  /// The roulette payoff: the name in `displayMedium` and metadata pills.
  result,
}

/// A meal, in one of three forms.
///
/// **No imagery, deliberately.** docs/COMPONENTS.md §4 and docs/design_ui.md §15
/// both lead the card with a 4:3 photograph, and this card used to draw one,
/// falling back per docs/DESIGN_SYSTEM.md §9 to a pastel block keyed off the
/// meal id. No photo ever existed — the catalogue ships sixty meals with no
/// rights-cleared photography — so every card in the app was that fallback: a
/// 4:3 area of flat colour taking two-thirds of the height and saying nothing.
///
/// The imagery is gone rather than faked, and the card is built round what a
/// reader actually wants:
///
/// * the **name**, which is the thing being chosen;
/// * a line of the meal's **own description**, in the space the photo had;
/// * the **cost a head**, set large — §15 gives the price its own line, and it is
///   the number that settles most arguments about dinner;
/// * everything else on **one metadata line**, not a pill each.
///
/// Colour comes from a **cuisine rail** down the left edge. Twenty cards each
/// carrying a different coloured edge gives the feed rhythm at a glance, where
/// twenty identical white rectangles gave it none — and unlike the pastel block
/// it replaced, the colour means something: same cuisine, same colour, every
/// time (§9).
///
/// In every form the whole card navigates to detail and the heart is an
/// independent target that must not trigger navigation (§4) — which is why the
/// heart sits outside the card's tap region in the tree rather than merely
/// calling `onFavoriteToggled`.
class MealCard extends StatelessWidget {
  const MealCard({
    required this.meal,
    this.variant = MealCardVariant.feed,
    this.onTap,
    this.onFavoriteToggled,
    this.trailing,
    super.key,
  });

  final MealCardData meal;
  final MealCardVariant variant;
  final VoidCallback? onTap;

  /// Null hides the heart entirely — correct for the planner and for search
  /// results, where favouriting is not the action on offer.
  final ValueChanged<bool>? onFavoriteToggled;

  /// A trailing action, `compact` form only.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      MealCardVariant.feed => _FeedForm(
        meal: meal,
        onTap: onTap,
        onFavoriteToggled: onFavoriteToggled,
      ),
      MealCardVariant.compact => _CompactForm(
        meal: meal,
        onTap: onTap,
        trailing: trailing,
      ),
      MealCardVariant.result => _ResultForm(
        meal: meal,
        onTap: onTap,
        onFavoriteToggled: onFavoriteToggled,
      ),
    };
  }
}

class _FeedForm extends StatelessWidget {
  const _FeedForm({
    required this.meal,
    required this.onTap,
    required this.onFavoriteToggled,
  });

  final MealCardData meal;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavoriteToggled;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(meal.cuisine ?? meal.id);
    final bool hasHeart = onFavoriteToggled != null;

    // The heart is a sibling of the card, not a child of it. docs/COMPONENTS.md
    // §4: "The heart is an independent target and must not trigger navigation" —
    // and inside the card it would be both, because `AppCard` owns the tap
    // region and its semantic label would swallow the heart's own.
    return Stack(
      children: <Widget>[
        AppCard(
          onTap: onTap,
          semanticLabel: _semanticLabel(meal),
          padding: EdgeInsets.zero,
          clipContent: true,
          // The cuisine rail, as a left border rather than a stretched child.
          //
          // A `Row` with `CrossAxisAlignment.stretch` was the obvious way to make
          // a full-height rail and it is wrong here: stretch needs a bounded
          // height, and a card inside a scrolling list is given an unbounded one.
          // It threw "BoxConstraints forces an infinite height" on every card, so
          // the feed rendered nothing at all.
          //
          // A border needs no height to paint. It also costs nothing, where the
          // usual fix — wrapping in `IntrinsicHeight` — adds a second layout pass
          // to every card in the list.
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accent.foreground, width: _railWidth),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          // Reserves the corner the heart floats over, so a long
                          // name wraps before reaching it rather than running
                          // underneath.
                          padding: EdgeInsets.only(
                            right: hasHeart ? _heartGutter : 0,
                          ),
                          child: Text(
                            meal.name,
                            style: context.text.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (meal.description
                            case final String description) ...<Widget>[
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            description,
                            style: context.text.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.space4),
                        _CostRow(meal: meal, accent: accent),
                        if (meal.detailLine.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            meal.detailLine,
                            style: context.text.metadata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasHeart)
          Positioned(
            top: AppSpacing.space2,
            right: AppSpacing.space2,
            child: FavoriteButton(
              isFavorite: meal.isFavorite,
              onToggled: onFavoriteToggled!,
              mealName: meal.name,
            ),
          ),
      ],
    );
  }

  /// Thin enough to read as an edge rather than a block.
  static const double _railWidth = 5;

  /// The width the floating heart needs, plus the gap beside it.
  static const double _heartGutter = 44;
}

/// The price, the cuisine, and whose meal it is — the card's bottom line.
///
/// The cost is set in `titleMedium` rather than tucked into a pill, because it is
/// the number people are comparing and §15 gives it its own line in the
/// reference card.
class _CostRow extends StatelessWidget {
  const _CostRow({required this.meal, required this.accent});

  final MealCardData meal;
  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        if (meal.formattedCostPerServing case final String each)
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: each, style: context.text.titleMedium),
                TextSpan(text: ' a head', style: context.text.metadata),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (meal.cuisine case final String cuisine)
          // The one tinted pill left on the card. The cuisine is the only piece
          // of metadata that *groups* meals rather than measuring them, which is
          // what makes it worth a colour.
          _AccentPill(label: cuisine, accent: accent),
        if (meal.isMine)
          _AccentPill(
            label: 'Yours',
            accent: AppAccent(
              background: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
            ),
          ),
      ],
    );
  }
}

/// A pill whose fill carries a meaning rather than a decoration.
class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label, required this.accent});

  final String label;
  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.background,
        borderRadius: AppRadius.borderFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        child: Text(
          label,
          style: context.text.labelSmall.copyWith(color: accent.foreground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CompactForm extends StatelessWidget {
  const _CompactForm({
    required this.meal,
    required this.onTap,
    required this.trailing,
  });

  final MealCardData meal;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(meal.cuisine ?? meal.id);

    return AppCard(
      variant: AppCardVariant.compact,
      onTap: onTap,
      semanticLabel: _semanticLabel(meal),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Row(
        children: <Widget>[
          // A slim rail where the thumbnail used to be. It holds the meal's
          // colour without pretending to hold its photograph, and it keeps the
          // row's left edge aligned with the feed card above it.
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.foreground,
              borderRadius: AppRadius.borderFull,
            ),
            child: const SizedBox(width: _railWidth, height: _railHeight),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  meal.name,
                  style: context.text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_metadata.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    _metadata,
                    style: context.text.metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.space2),
            trailing!,
          ],
        ],
      ),
    );
  }

  String get _metadata => AppFormat.metadata(<String?>[
    meal.cuisine,
    meal.cookingTimeMinutes == null
        ? null
        : AppFormat.cookingTime(meal.cookingTimeMinutes!),
    meal.formattedCost,
  ]);

  static const double _railWidth = 4;
  static const double _railHeight = 40;
}

class _ResultForm extends StatelessWidget {
  const _ResultForm({
    required this.meal,
    required this.onTap,
    required this.onFavoriteToggled,
  });

  final MealCardData meal;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavoriteToggled;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppAccent accent = colors.accentFor(meal.cuisine ?? meal.id);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.borderXxxl,
        boxShadow: context.shadows.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppLayout.cardPadding),
        child: Column(
          children: <Widget>[
            if (onFavoriteToggled != null)
              Align(
                alignment: Alignment.centerRight,
                child: FavoriteButton(
                  isFavorite: meal.isFavorite,
                  onToggled: onFavoriteToggled!,
                  mealName: meal.name,
                ),
              ),
            if (meal.cuisine case final String cuisine) ...<Widget>[
              _AccentPill(label: cuisine, accent: accent),
              const SizedBox(height: AppSpacing.space4),
            ],
            Text(
              meal.name,
              style: context.text.displayMedium,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (meal.contextLine case final String context_) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Text(
                context_,
                style: context.text.labelSmall.copyWith(color: colors.primary),
                textAlign: TextAlign.center,
              ),
            ],
            if (meal.description case final String description) ...<Widget>[
              const SizedBox(height: AppSpacing.space3),
              Text(
                description,
                style: context.text.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.space5),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                if (meal.formattedCost != null)
                  MetadataPill(label: meal.formattedCost!, isNumeric: true),
                if (meal.cookingTimeMinutes != null)
                  MetadataPill(
                    label: AppFormat.cookingTime(meal.cookingTimeMinutes!),
                    icon: AppIcons.cookingTime,
                  ),
                if (meal.servings != null)
                  MetadataPill(
                    label: AppFormat.servings(meal.servings!),
                    icon: AppIcons.servings,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The heart on a meal card (docs/COMPONENTS.md §4).
///
/// Optimistic: the state flips on tap with no loading indicator, because a
/// favourite that waits for the network feels broken (§11). The write happening
/// afterwards is the caller's problem, and a failure reverts with a snackbar.
///
/// The scale-1.3-then-settle is what makes the tap feel like it landed.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    required this.isFavorite,
    required this.onToggled,
    this.mealName,
    super.key,
  });

  final bool isFavorite;
  final ValueChanged<bool> onToggled;

  /// Named in the semantic label so a screen reader on a list of hearts can
  /// tell which meal each one belongs to.
  final String? mealName;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.pressIn,
      reverseDuration: AppMotion.pressOut,
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1,
      end: _popScale,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.curveFast));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    widget.onToggled(!widget.isFavorite);

    if (AppMotion.prefersReducedMotion(context)) {
      return;
    }
    await _controller.forward();
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final String label = widget.isFavorite
        ? 'Remove ${widget.mealName ?? 'meal'} from favourites'
        : 'Save ${widget.mealName ?? 'meal'} to favourites';

    return ScaleTransition(
      scale: _scale,
      child: AppIconButton(
        icon: widget.isFavorite ? AppIcons.favoriteActive : AppIcons.favorite,
        semanticLabel: label,
        style: AppIconButtonStyle.floating,
        iconSize: AppIconSize.sm,
        visualSize: _diameter,
        color: widget.isFavorite ? colors.error.color : colors.textSecondary,
        onPressed: () => unawaited(_onTap()),
      ),
    );
  }

  static const double _diameter = 36;
  static const double _popScale = 1.3;
}

String _semanticLabel(MealCardData meal) {
  return AppFormat.metadata(<String?>[
    meal.name,
    meal.contextLabel.isEmpty ? null : meal.contextLabel,
    meal.formattedCostPerServing,
  ]);
}
