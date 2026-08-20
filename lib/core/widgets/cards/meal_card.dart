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
  /// The card carries no imagery, so this is what fills the space a photograph
  /// used to — and it is better at the job, because it says something about the
  /// food rather than merely decorating it.
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

  /// What one plate costs, which is what every budget question in the app means.
  num? get costPerServing => estimatedCost == null || servings == null
      ? estimatedCost
      : estimatedCost! / servings!;

  String? get formattedCost =>
      estimatedCost == null ? null : AppFormat.peso(estimatedCost!);

  /// `₱65 a head`, the figure a reader can actually compare between meals.
  String? get formattedCostPerServing {
    final num? each = costPerServing;
    return each == null ? null : '${AppFormat.peso(each)} a head';
  }
}

/// The three forms of the meal card (docs/COMPONENTS.md §4).
enum MealCardVariant {
  /// The Meals tab: full width, name-led, a row of metadata.
  feed,

  /// History, planner, search: a single line with its metadata beneath.
  compact,

  /// The roulette payoff: the name in `displayMedium` and metadata pills.
  result,
}

/// A meal, in one of three forms.
///
/// **No imagery, deliberately.** docs/COMPONENTS.md §4 and docs/design_ui.md §15
/// both describe a 4:3 photograph as the card's leading element, and this card
/// used to draw one — falling back, per docs/DESIGN_SYSTEM.md §9, to a pastel
/// block keyed off the meal id when no photo existed.
///
/// No photo ever existed. The catalogue ships sixty meals with no
/// rights-cleared photography behind them, so every card in the app was that
/// fallback: a 4:3 area of flat colour taking up two-thirds of the card and
/// saying nothing. Three attempts at making it say something — a bigger glyph, a
/// gradient, a glyph on a legible disc — each looked better than the last and
/// none of them looked like food.
///
/// So the imagery is gone rather than faked. What replaces it is the thing a
/// reader actually wants: the name, a line of the meal's own description, and
/// the four numbers that decide dinner — cost a head, time, difficulty, and who
/// it feeds. A card that is honest about being text is worth more than one
/// pretending to be a photograph, and five of them fit where one and a half used
/// to.
///
/// If photography arrives, it comes back as a deliberate change, with the
/// licensing and hosting decided first.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                // Reserves the corner the heart floats over, so a long name
                // wraps before it reaches it rather than running underneath.
                padding: EdgeInsets.only(right: hasHeart ? _heartGutter : 0),
                child: Text(
                  meal.name,
                  style: context.text.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (meal.description case final String description) ...<Widget>[
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
              // Wraps rather than truncates, so nothing is lost at 1.3x scale.
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: <Widget>[
                  // The cuisine carries the colour. It is the one piece of metadata
                  // that groups meals rather than measuring them, so it is also the
                  // one worth tinting — and a tinted word is colour with a meaning,
                  // where a coloured block was colour standing in for a photograph.
                  if (meal.cuisine case final String cuisine)
                    _AccentPill(label: cuisine, accent: accent),
                  if (meal.isMine)
                    _AccentPill(
                      label: 'Yours',
                      accent: AppAccent(
                        background: colors.primaryContainer,
                        foreground: colors.onPrimaryContainer,
                      ),
                    ),
                  if (meal.formattedCostPerServing case final String cost)
                    MetadataPill(label: cost, isNumeric: true),
                  if (meal.cookingTimeMinutes case final int minutes)
                    MetadataPill(
                      label: AppFormat.cookingTime(minutes),
                      icon: AppIcons.cookingTime,
                    ),
                  if (meal.difficulty case final String difficulty)
                    MetadataPill(label: difficulty, icon: AppIcons.difficulty),
                  if (meal.servings case final int servings)
                    MetadataPill(
                      label: AppFormat.servings(servings),
                      icon: AppIcons.servings,
                    ),
                ],
              ),
            ],
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

  /// The width the floating heart needs, plus the gap beside it.
  static const double _heartGutter = 44;
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
