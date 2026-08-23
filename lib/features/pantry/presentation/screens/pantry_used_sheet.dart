import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/formatters.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_toast.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_use.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

/// What the meal you just cooked took out of the kitchen (Sprint 54).
///
/// **The pantry only ever grew before this.** Accepting a meal filled in the
/// shopping list and never touched the shelf, so a household added chicken, cooked
/// it, and the app went on believing the chicken was there. Survivable while the
/// pantry was a twenty-point *nudge* in the scorer; not survivable now it is a
/// **filter** — "All in" fills with meals that cannot be cooked, and every fridge
/// scan is undone by the next dinner.
///
/// **It asks, and that is the whole design.** The recipe wanting 500 g of chicken
/// says nothing about whether that was the last of it, and only the person who
/// cooked knows. An app that silently rewrites the kitchen after every meal is an
/// app whose kitchen nobody trusts — which is exactly the thing being filtered on.
///
/// Opt-out rather than opt-in: everything starts ticked, because the common case
/// is that the recipe's amounts were the amounts used, and eight unticked boxes is
/// eight taps to do the ordinary thing.
class PantryUsedSheet extends ConsumerStatefulWidget {
  const PantryUsedSheet({required this.mealId, this.mealName, super.key});

  final String mealId;

  /// Shown in the heading when the caller has it, which the decided screen does.
  final String? mealName;

  @override
  ConsumerState<PantryUsedSheet> createState() => _PantryUsedSheetState();
}

class _PantryUsedSheetState extends ConsumerState<PantryUsedSheet> {
  /// Null until the read comes back.
  List<PantryUse>? _uses;

  final Set<String> _dropped = <String>{};

  bool _isLoading = true;
  bool _isApplying = false;
  AppException? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<PantryUse> uses = await ref
          .read(pantryRepositoryProvider)
          .usedByMeal(widget.mealId);

      if (!mounted) {
        return;
      }
      setState(() {
        _uses = uses;
        _isLoading = false;
      });
    } on Object catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _failure = ErrorMapper.map(error, stackTrace);
      });
    }
  }

  List<PantryUse> get _kept => <PantryUse>[
    for (final PantryUse use in _uses ?? const <PantryUse>[])
      if (!_dropped.contains(use.itemId)) use,
  ];

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final List<PantryUse> uses = _uses ?? const <PantryUse>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenMargin,
        AppSpacing.space5,
        AppLayout.screenMargin,
        AppSpacing.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Take it out of the kitchen?',
                      style: context.text.titleLarge,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      widget.mealName == null
                          ? 'What the recipe used, so the kitchen stays right.'
                          : '${AppFormat.sentenceCase(widget.mealName!)} used '
                                'these. Untick anything you still have.',
                      style: context.text.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              AppButton.tertiary(
                label: 'Not now',
                size: AppButtonSize.small,
                onPressed: _isApplying ? null : () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),

          if (_failure case final AppException problem) ...<Widget>[
            InlineErrorBanner(
              message: problem.displayMessage ?? problem.message,
              detail: problem.detail,
            ),
            const SizedBox(height: AppSpacing.space4),
          ],

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.space6),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (uses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space4),
              child: Text(
                // Not a failure. A catalogue meal with no ingredient rows, or a
                // recipe made entirely of staples, genuinely takes nothing off the
                // shelf — and saying so is better than an empty box.
                'Nothing on the shelf matched this recipe, so the kitchen is '
                'already right.',
                style: context.text.bodyMedium,
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final (int index, PantryUse use)
                        in uses.indexed) ...<Widget>[
                      if (index > 0) const DashboardRule(),
                      _UseRow(
                        use: use,
                        isKept: !_dropped.contains(use.itemId),
                        isEnabled: !_isApplying,
                        onToggle: () => setState(() {
                          if (!_dropped.remove(use.itemId)) {
                            _dropped.add(use.itemId);
                          }
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.space5),
          AppButton.inverse(
            label: switch (_kept.length) {
              0 => 'Leave the kitchen as it is',
              1 => 'Take 1 out',
              final int count => 'Take $count out',
            },
            isLoading: _isApplying,
            onPressed: _isLoading || _isApplying
                ? null
                : _kept.isEmpty
                ? () => context.pop()
                : _apply,
          ),
          if (uses.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              // The consequence, stated. Somebody who has just cooked is not
              // thinking about the roulette, and this is the reason the sheet
              // exists at all.
              'A right kitchen is what "cook what we have" spins from.',
              style: context.text.metadata.copyWith(color: colors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _apply() async {
    setState(() {
      _isApplying = true;
      _failure = null;
    });

    final ({int changed, AppException? failure}) result = await ref
        .read(pantryControllerProvider.notifier)
        .applyUse(_kept);

    if (!mounted) {
      return;
    }

    // The match map is now wrong, and it is what the roulette's kitchen filter
    // reads. Invalidated rather than patched: the amounts changed, so which meals
    // are complete changed with them, and only the server knows the new answer.
    ref.invalidate(pantryMatchesProvider);

    AppHaptics.decided();
    context.pop();

    AppToast.show(switch (result) {
      (changed: 0, failure: final AppException e) =>
        e.displayMessage ?? e.message,
      (changed: 0, failure: _) => 'The kitchen is unchanged.',
      (changed: final int n, failure: null) =>
        n == 1
            ? '1 thing came out of the kitchen'
            : '$n things came out '
                  'of the kitchen',
      (changed: final int n, failure: _) => '$n came out — the rest could not',
    }, tone: result.changed > 0 ? ToastTone.success : ToastTone.failure);
  }
}

/// One ingredient, and what taking it out would do.
class _UseRow extends StatelessWidget {
  const _UseRow({
    required this.use,
    required this.isKept,
    required this.isEnabled,
    required this.onToggle,
  });

  final PantryUse use;
  final bool isKept;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: <Widget>[
          // The same square the fridge scan, the list import and the meal
          // selection use. Four confirmation lists, one shape.
          Semantics(
            checked: isKept,
            label: use.name,
            child: InkWell(
              onTap: isEnabled ? onToggle : null,
              borderRadius: AppRadius.borderSm,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isKept ? colors.surfaceInverse : Colors.transparent,
                    border: Border.all(
                      color: isKept
                          ? colors.surfaceInverse
                          : colors.outlineStrong,
                      width: _boxBorder,
                    ),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: SizedBox.square(
                    dimension: _boxSize,
                    child: isKept
                        ? Icon(
                            AppIcons.check,
                            size: _tickSize,
                            color: colors.textOnInverse,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Text(
              AppFormat.sentenceCase(use.name),
              style: context.text.titleSmall.copyWith(
                color: isKept ? colors.textPrimary : colors.textTertiary,
                decoration: isKept ? null : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Text(
            // What will happen, not what it holds — "200 g left" or "all of it".
            // The reader is deciding whether that is true, and the outcome is the
            // thing to check.
            use.outcome,
            style: context.text.metadata.copyWith(
              color: isKept
                  ? (use.isUsedUp ? colors.warning.color : colors.textSecondary)
                  : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static const double _boxSize = 18;
  static const double _boxBorder = 1.5;
  static const double _tickSize = 16;
}
