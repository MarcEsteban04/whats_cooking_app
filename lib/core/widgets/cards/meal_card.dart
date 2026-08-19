import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/cards/app_card.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
import 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';

/// Everything a [MealCard] renders.
///
/// A presentation model rather than the domain `Meal` entity, because `core/`
/// cannot depend on a feature (docs/ARCHITECTURE.md §2.3) and the meals feature
/// does not exist until Sprint 21. When it does, a mapper in that feature turns
/// its entity into this — which also keeps the card renderable from a search
/// result, a planner row or an AI suggestion, none of which carry a full meal.
@immutable
class MealCardData {
  const MealCardData({
    required this.id,
    required this.name,
    this.cuisine,
    this.cookingTimeMinutes,
    this.estimatedCost,
    this.servings,
    this.imageUrl,
    this.emoji,
    this.isFavorite = false,
    this.contextLine,
  });

  /// Seeds the pastel fallback, so a photo-less meal keeps the same colour
  /// across launches (docs/DESIGN_SYSTEM.md §9).
  final String id;
  final String name;
  final String? cuisine;
  final int? cookingTimeMinutes;
  final num? estimatedCost;
  final int? servings;
  final String? imageUrl;

  /// Shown in the pastel fallback when [imageUrl] is missing or fails.
  final String? emoji;
  final bool isFavorite;

  /// The result form's optional line — "Loved by both of you".
  final String? contextLine;

  /// `Japanese · 30 min`, with missing parts dropped.
  String get metadataLine => AppFormat.metadata(<String?>[
    cuisine,
    cookingTimeMinutes == null
        ? null
        : AppFormat.cookingTime(cookingTimeMinutes!),
  ]);

  String? get formattedCost =>
      estimatedCost == null ? null : AppFormat.peso(estimatedCost!);
}

/// The three forms of the meal card (docs/COMPONENTS.md §4).
enum MealCardVariant {
  /// The Meals tab: full width, 4:3 image, heart floating top-right.
  feed,

  /// History, planner, search: a 64 px square image and a stacked title.
  compact,

  /// The roulette payoff: 1:1 image, the name in `displayMedium`, metadata
  /// pills. The most important surface in the app, and the only one with
  /// `shadowXl`.
  result,
}

/// A meal, in one of three forms.
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

    return Stack(
      children: <Widget>[
        AppCard(
          onTap: onTap,
          semanticLabel: _semanticLabel(meal),
          padding: EdgeInsets.zero,
          clipContent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: _feedAspectRatio,
                child: MealImage(meal: meal),
              ),
              Padding(
                padding: const EdgeInsets.all(AppLayout.cardPaddingCompact),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      meal.name,
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meal.metadataLine.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        meal.metadataLine,
                        style: context.text.metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (meal.formattedCost != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        meal.formattedCost!,
                        style: context.text.numeric.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onFavoriteToggled != null)
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

  static const double _feedAspectRatio = 4 / 3;
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
    return AppCard(
      variant: AppCardVariant.compact,
      onTap: onTap,
      semanticLabel: _semanticLabel(meal),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: SizedBox.square(
              dimension: _thumbnailSize,
              child: MealImage(meal: meal),
            ),
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
                if (meal.metadataLine.isNotEmpty ||
                    meal.formattedCost != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    AppFormat.metadata(<String?>[
                      meal.metadataLine.isEmpty ? null : meal.metadataLine,
                      meal.formattedCost,
                    ]),
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

  static const double _thumbnailSize = 64;
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
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: AppRadius.borderXxxl,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: MealImage(meal: meal),
                  ),
                ),
                if (onFavoriteToggled != null)
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
            ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              meal.name,
              style: context.text.displayMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meal.contextLine != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Text(
                meal.contextLine!,
                style: context.text.labelSmall.copyWith(color: colors.primary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            // Wraps rather than truncates, so nothing is lost at 1.3x scale.
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

/// A meal photo, its loading skeleton and its fallback.
///
/// docs/DESIGN_SYSTEM.md §9: every image fades in, shimmers while loading, and
/// "degrades to a deterministic pastel-plus-emoji block keyed off the meal ID —
/// so a missing photo still looks composed, and looks the *same* on every
/// launch."
class MealImage extends StatelessWidget {
  const MealImage({required this.meal, super.key});

  final MealCardData meal;

  @override
  Widget build(BuildContext context) {
    final String? url = meal.imageUrl;

    if (url == null || url.isEmpty) {
      return _MealImageFallback(meal: meal);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: AppMotion.resolve(context, AppMotion.normal),
      placeholder: (BuildContext context, String _) => const AppSkeleton(),
      errorWidget: (BuildContext context, String _, Object _) =>
          _MealImageFallback(meal: meal),
    );
  }
}

class _MealImageFallback extends StatelessWidget {
  const _MealImageFallback({required this.meal});

  final MealCardData meal;

  @override
  Widget build(BuildContext context) {
    final AppAccent accent = context.colors.accentFor(meal.id);

    return ColoredBox(
      color: accent.background,
      child: Center(
        child: Text(
          meal.emoji ?? _defaultEmoji,
          style: const TextStyle(fontSize: AppIconSize.lg),
        ),
      ),
    );
  }

  static const String _defaultEmoji = '🍽️';
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
    meal.metadataLine.isEmpty ? null : meal.metadataLine,
    meal.formattedCost,
  ]);
}
