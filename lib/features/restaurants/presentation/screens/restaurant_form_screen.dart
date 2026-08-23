import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/inputs/app_toggle.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/restaurants/domain/entities/restaurant.dart';
import 'package:whats_cooking/features/restaurants/presentation/providers/restaurants_controller.dart';

/// Writing down a place we go (Sprint 45).
///
/// **Two required fields, and the rest have defaults.** A name and roughly what a
/// meal costs is enough to save — everything else is an improvement on a record
/// that already works. A form that demands notes before it will accept "Ramen
/// Nagi, ₱450" is a form somebody abandons at the third field, and an abandoned
/// form is a place the roulette will never offer.
///
/// A full screen rather than a sheet, unlike the pantry and grocery add flows.
/// Those capture one line each; this captures seven fields including free text, and
/// a keyboard over a sheet leaves about two of them visible.
class RestaurantFormScreen extends ConsumerStatefulWidget {
  const RestaurantFormScreen({this.restaurantId, super.key});

  /// The place being rewritten, or null when adding.
  final String? restaurantId;

  @override
  ConsumerState<RestaurantFormScreen> createState() =>
      _RestaurantFormScreenState();
}

class _RestaurantFormScreenState extends ConsumerState<RestaurantFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _order = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  RestaurantDraft _draft = const RestaurantDraft();

  bool _isSaving = false;

  /// True once the existing place has been copied into the fields, so a rebuild
  /// cannot overwrite what somebody has typed.
  bool _isSeeded = false;

  AppException? _failure;

  bool get _isEditing => widget.restaurantId != null;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _order.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Restaurant? existing = widget.restaurantId == null
        ? null
        : ref.watch(restaurantByIdProvider(widget.restaurantId!));

    // Seeded once. `ref.watch` above means this build runs again whenever the list
    // changes — including on the save that follows — and re-seeding then would
    // stamp over the fields mid-edit.
    if (existing != null && !_isSeeded) {
      _isSeeded = true;
      _draft = RestaurantDraft.from(existing);
      _name.text = _draft.name;
      _cost.text = (_draft.costPerHead ?? 0).round().toString();
      _order.text = _draft.goToOrder;
      _notes.text = _draft.notes;
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.clear),
          onPressed: _isSaving ? null : () => context.pop(),
          tooltip: 'Cancel',
        ),
        title: Text(_isEditing ? 'Edit place' : 'Add a place'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenMargin,
                AppSpacing.space4,
                AppLayout.screenMargin,
                AppSpacing.space7,
              ),
              children: <Widget>[
                AppTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Ramen Nagi',
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (String value) =>
                      setState(() => _draft = _draft.copyWith(name: value)),
                ),
                const SizedBox(height: AppSpacing.space4),
                AppTextField(
                  controller: _cost,
                  label: 'About what a meal costs',
                  // A head, said plainly. "₱450" against a bill for two is the
                  // kind of ambiguity that makes a budget filter useless.
                  helperText: 'Per person, roughly.',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (String value) => setState(
                    () => _draft = _draft.copyWith(
                      costPerHead: double.tryParse(value),
                    ),
                  ),
                ),

                const SectionHeader(title: 'Cuisine'),
                _CuisineChips(
                  selected: _draft.cuisine,
                  onSelected: (Cuisine cuisine) => setState(
                    () => _draft = _draft.copyWith(cuisine: cuisine),
                  ),
                ),

                const SectionHeader(
                  title: 'How far',
                  subtitle: 'Not kilometres — just whether we can walk.',
                ),
                _ProximityChips(
                  selected: _draft.proximity,
                  onSelected: (Proximity proximity) => setState(
                    () => _draft = _draft.copyWith(proximity: proximity),
                  ),
                ),

                const SizedBox(height: AppSpacing.space4),
                _Delivers(
                  value: _draft.delivers,
                  onChanged: (bool value) =>
                      setState(() => _draft = _draft.copyWith(delivers: value)),
                ),

                const SectionHeader(
                  title: 'What we order',
                  // Says why the field is worth filling in, because it is the one
                  // no maps API could ever supply and the one that turns
                  // "somewhere Japanese" into a decision.
                  subtitle: 'The thing you would tell a friend to get.',
                ),
                AppTextField(
                  controller: _order,
                  hint: 'The Butao. Ask for extra chashu.',
                  maxLines: 2,
                  onChanged: (String value) => setState(
                    () => _draft = _draft.copyWith(goToOrder: value),
                  ),
                ),

                const SectionHeader(title: 'Anything else'),
                AppTextField(
                  controller: _notes,
                  hint: 'Queues after seven. Cash only.',
                  maxLines: 3,
                  onChanged: (String value) =>
                      setState(() => _draft = _draft.copyWith(notes: value)),
                ),

                if (_failure case final AppException problem) ...<Widget>[
                  const SizedBox(height: AppSpacing.space4),
                  InlineErrorBanner(
                    message: problem.displayMessage ?? problem.message,
                    onRetry: _save,
                  ),
                ],

                const SizedBox(height: AppSpacing.space6),
                AppButton.primary(
                  label: _isEditing ? 'Save' : 'Add it',
                  size: AppButtonSize.large,
                  isLoading: _isSaving,
                  // Disabled until it could actually be saved, so the button says
                  // whether there is anything to do rather than failing on a tap.
                  onPressed: _draft.isComplete && !_isSaving ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final RestaurantsController controller = ref.read(
      restaurantsControllerProvider.notifier,
    );

    final AppException? failure = switch (widget.restaurantId) {
      final String id => await controller.edit(id, _draft),
      null => await controller.create(_draft),
    };

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

    AppHaptics.reveal();
    context.pop();
  }
}

/// The twelve cuisines, as chips.
class _CuisineChips extends StatelessWidget {
  const _CuisineChips({required this.selected, required this.onSelected});

  final Cuisine selected;
  final ValueChanged<Cuisine> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final Cuisine cuisine in Cuisine.values)
          AppFilterChip(
            label: cuisine.label,
            isSelected: cuisine == selected,
            onSelected: (_) => onSelected(cuisine),
          ),
      ],
    );
  }
}

/// Walk, short ride, worth the trip.
class _ProximityChips extends StatelessWidget {
  const _ProximityChips({required this.selected, required this.onSelected});

  final Proximity selected;
  final ValueChanged<Proximity> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final Proximity option in Proximity.values)
          AppFilterChip(
            label: option.label,
            isSelected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// Whether they deliver.
///
/// **Hand-built, not `SwitchListTile.adaptive`** (Sprint 49b). The adaptive tile
/// drew a Cupertino switch on iOS and a Material one on Android — two controls,
/// neither of them this app's — and it laid them out on its own terms: the switch
/// pinned to the far edge with the caption running under it, which read as a
/// clipped control rather than a setting. `AppToggle` is the pill the reference
/// design uses and the same one the auth screens carry, so the app has one switch
/// rather than three.
///
/// The whole row is the target, which is the same reason the grocery list makes
/// its rows the checkbox: a 44-pixel pill is a small thing to hit while holding a
/// phone in one hand.
class _Delivers extends StatelessWidget {
  const _Delivers({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      onTap: () => onChanged(!value),
      isButton: false,
      semanticLabel: 'They deliver',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('They deliver', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'So a night nobody wants to go out still has an answer.',
                  style: context.text.metadata,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space4),
          // Excluded from semantics: the row above already announces itself as a
          // switch, and two toggles in the tree for one control is what makes a
          // screen reader read everything twice.
          ExcludeSemantics(
            child: AppToggle(
              value: value,
              onChanged: onChanged,
              semanticLabel: 'They deliver',
            ),
          ),
        ],
      ),
    );
  }
}
