import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/preferences/preference_editors.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/profile/domain/entities/user_profile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/profile/presentation/widgets/settings_scaffold.dart';

/// Budget, cooking time and party size (docs/USER_FLOWS.md §17: "Budget →
/// Default budget and party size").
///
/// The three constraints that decide what the roulette can offer, on one screen
/// because they are answered together: "₱300, half an hour, two of us" is one
/// thought.
class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() =>
      _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  FoodPreferences? _edited;
  AppException? _failure;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return profile.when(
      loading: () => const SettingsScaffold(
        title: 'Budget and time',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => SettingsScaffold(
        title: 'Budget and time',
        child: ErrorState(
          onRetry: () => ref.read(profileControllerProvider.notifier).refresh(),
        ),
      ),
      data: _buildForm,
    );
  }

  Widget _buildForm(UserProfile profile) {
    final FoodPreferences preferences = _edited ?? profile.preferences;
    final bool hasChanges = preferences != profile.preferences;

    return SettingsScaffold(
      title: 'Budget and time',
      subtitle: 'What the roulette should assume when it picks.',
      action: AppButton.inverse(
        label: 'Save',
        isLoading: _isSaving,
        onPressed: hasChanges ? () => _save(preferences) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null) ...<Widget>[
            InlineErrorBanner(message: _failure!.message),
            const SizedBox(height: AppSpacing.space4),
          ],
          const SectionHeader(
            title: 'A normal spend',
            subtitle: 'Per meal.',
            hasTopSpacing: false,
          ),
          BudgetPicker(
            budget: preferences.budget,
            onChanged: (int? budget) => setState(
              () => _edited = budget == null
                  ? preferences.copyWith(clearBudget: true)
                  : preferences.copyWith(budget: budget),
            ),
          ),
          const SectionHeader(title: 'How long you have'),
          CookingTimePicker(
            minutes: preferences.maxCookingTimeMinutes,
            onChanged: (int? minutes) => setState(
              () => _edited = minutes == null
                  ? preferences.copyWith(clearMaxCookingTime: true)
                  : preferences.copyWith(maxCookingTimeMinutes: minutes),
            ),
          ),
          const SectionHeader(title: 'Who you cook for'),
          CookingForPicker(
            selected: preferences.cookingFor,
            onChanged: (CookingFor choice) => setState(
              () => _edited = preferences.copyWith(cookingFor: choice),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(FoodPreferences preferences) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppException? failure = await ref
        .read(profileControllerProvider.notifier)
        .updatePreferences(preferences);

    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
      if (failure == null) {
        _edited = null;
      }
    });
  }
}
