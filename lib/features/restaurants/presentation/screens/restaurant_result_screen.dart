import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
import 'package:whats_cooking/core/widgets/feedback/app_toast.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurant_spin_controller.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';

/// Tonight we are going here (Sprint 46).
///
/// The meal result screen's twin, and the same three actions in the same
/// asymmetry: **This is it** loud, **Try again** quiet but one tap away, and a way
/// out that decides nothing.
///
/// **The one thing this screen has that the meal one does not** is the order. What
/// we get there is the field no API returns, and it is the difference between "we
/// are going to Ramen Nagi" and knowing what to say when you sit down.
class RestaurantResultScreen extends ConsumerWidget {
  const RestaurantResultScreen({
    required this.restaurantId,
    this.pick,
    super.key,
  });

  final String restaurantId;

  /// The place the spin landed on, handed over by the route so the payoff waits on
  /// nothing.
  final Restaurant? pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only consulted when the route arrived without one — a deep link, or a
    // restart on this screen. The list is already loaded, so this is a lookup
    // rather than a fetch.
    final Restaurant? place =
        pick ?? ref.watch(restaurantByIdProvider(restaurantId));

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.screenMargin),
              child: place == null
                  ? ErrorState(
                      kind: ErrorStateKind.notFound,
                      body: 'That place is no longer on your list.',
                      onRetry: () =>
                          context.goNamed(AppRoute.restaurants.routeName),
                    )
                  : _Result(place: place),
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends ConsumerStatefulWidget {
  const _Result({required this.place});

  final Restaurant place;

  @override
  ConsumerState<_Result> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_Result> {
  bool _isSaving = false;
  AppException? _failure;

  /// Why the engine chose this, matched on the id so a stale state from a previous
  /// spin cannot put last spin's reason under this spin's place.
  String? get _reason {
    if (ref.watch(restaurantSpinControllerProvider)
        case RestaurantSpinSettled(
          :final Restaurant place,
          :final String? reason,
        )
        when place.id == widget.place.id) {
      return reason;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Restaurant place = widget.place;
    final AppAccent accent = context.colors.accentFor(place.cuisine.label);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "TONIGHT WE'RE GOING OUT",
          style: context.text.overline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space4),

        DecoratedBox(
          decoration: BoxDecoration(
            color: accent.background,
            borderRadius: AppRadius.borderXxxl,
            boxShadow: context.shadows.xl,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  place.cuisine.label.toUpperCase(),
                  style: context.text.overline.copyWith(
                    color: accent.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  place.name,
                  style: context.text.displayMedium,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // The reason this list is kept by hand. Given real room rather than
                // a metadata line, because it is the most useful thing on the
                // screen once the decision is made.
                if (place.goToOrder case final String order) ...<Widget>[
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '"$order"',
                    style: context.text.bodyLarge.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ],

                const SizedBox(height: AppSpacing.space5),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space2,
                  children: <Widget>[
                    MetadataPill(
                      icon: AppIcons.budget,
                      label:
                          '${AppFormat.peso(place.costPerHead.round())} a head',
                    ),
                    MetadataPill(
                      icon: AppIcons.cuisine,
                      label: place.proximity.label,
                    ),
                    if (place.delivers)
                      const MetadataPill(
                        icon: AppIcons.grocery,
                        label: 'Delivers',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (_reason case final String reason) ...<Widget>[
          const SizedBox(height: AppSpacing.space3),
          Text(
            reason,
            style: context.text.metadata,
            textAlign: TextAlign.center,
          ),
        ],

        if (place.notes case final String notes) ...<Widget>[
          const SizedBox(height: AppSpacing.space2),
          Text(
            notes,
            style: context.text.metadata,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],

        if (_failure case final AppException problem) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          InlineErrorBanner(
            message: problem.displayMessage ?? problem.message,
            onRetry: _accept,
          ),
        ],

        const SizedBox(height: AppSpacing.space6),
        AppButton.primary(
          label: "That's where we're going",
          size: AppButtonSize.large,
          leadingIcon: AppIcons.favoriteActive,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _accept,
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton.secondary(
                label: 'Somewhere else',
                leadingIcon: AppIcons.spin,
                onPressed: _isSaving ? null : _rejectAndRespin,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: AppButton.tertiary(
                // The other answer, always one tap away. A night out that turns
                // out to be a night in is a normal outcome, not a failure.
                label: 'Cook instead',
                onPressed: _isSaving
                    ? null
                    : () => context.goNamed(AppRoute.roulette.routeName),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Align(
          child: AppButton.tertiary(
            label: 'Not now',
            size: AppButtonSize.small,
            onPressed: _isSaving
                ? null
                : () {
                    ref.read(restaurantSpinControllerProvider.notifier).reset();
                    context.goNamed(AppRoute.home.routeName);
                  },
          ),
        ),
      ],
    );
  }

  /// Records the night out, then goes home.
  ///
  /// No `decided` screen of its own. The meal flow earns one because a decision to
  /// cook has a next step — the recipe — and this does not: the next step is
  /// putting shoes on. A snackbar and a return to Home is the honest amount of
  /// ceremony.
  Future<void> _accept() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppException? failure = await ref
        .read(restaurantSpinControllerProvider.notifier)
        .accept(widget.place);

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

    AppHaptics.decided();
    AppToast.success('${widget.place.name} it is.');
    context.goNamed(AppRoute.home.routeName);
  }

  void _rejectAndRespin() {
    // Recorded here rather than on the next spin, because leaving by "Not now" or
    // the back gesture is not a rejection — and counting it as one would make the
    // ratio the engine is judged on quietly wrong.
    ref.read(restaurantSpinControllerProvider.notifier).reject(widget.place);
    context.goNamed(AppRoute.restaurantSpin.routeName);
  }
}
