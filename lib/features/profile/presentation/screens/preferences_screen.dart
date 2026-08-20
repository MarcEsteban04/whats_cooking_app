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

/// Editing cuisines, dislikes and dietary needs (docs/USER_FLOWS.md §17).
///
/// The same three editors onboarding used, from
/// `core/widgets/preferences/` — docs/COMPONENTS.md §18b: "a user must meet the
/// same cuisine grid on day one and on day thirty".
///
/// Saved explicitly rather than on every toggle. Toggling six cuisines would be
/// six writes, and a screen that saves as you go gives you no way to change your
/// mind before committing.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
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
        title: 'Food preferences',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => SettingsScaffold(
        title: 'Food preferences',
        child: ErrorState(
          onRetry: () => ref.read(profileControllerProvider.notifier).refresh(),
        ),
      ),
      data: (UserProfile data) => _buildForm(context, data),
    );
  }

  Widget _buildForm(BuildContext context, UserProfile profile) {
    final FoodPreferences preferences = _edited ?? profile.preferences;
    final bool hasChanges = preferences != profile.preferences;

    return SettingsScaffold(
      title: 'Food preferences',
      subtitle: 'Changes apply to your next spin.',
      action: AppButton.inverse(
        label: 'Save',
        isLoading: _isSaving,
        // Disabled with nothing to save, so the button says whether there is
        // anything to do rather than always looking available.
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
            title: 'What you love',
            subtitle: 'We will lean towards these.',
            hasTopSpacing: false,
          ),
          CuisinePicker(
            selected: preferences.favouriteCuisines,
            onChanged: (Set<Cuisine> selected) => setState(
              () => _edited = preferences.copyWith(favouriteCuisines: selected),
            ),
          ),
          const SectionHeader(
            title: 'What you avoid',
            subtitle: 'We will never suggest these.',
          ),
          DislikesEditor(
            foods: preferences.dislikedFoods,
            onChanged: (List<String> foods) => setState(
              () => _edited = preferences.copyWith(dislikedFoods: foods),
            ),
          ),
          const SectionHeader(
            title: 'Dietary needs',
            subtitle: 'These are hard rules, not suggestions.',
          ),
          DietaryPicker(
            selected: preferences.dietaryTags,
            onChanged: (Set<DietaryTag> tags) => setState(
              () => _edited = preferences.copyWith(dietaryTags: tags),
            ),
          ),
          const SectionHeader(
            title: 'Repeating a meal',
            subtitle: 'How long before we can offer it again.',
          ),
          RepetitionWindowPicker(
            days: preferences.repetitionWindowDays,
            onChanged: (int? days) => setState(
              () => _edited = days == null
                  // Back to the default, which is not the same as zero — so it
                  // has to clear rather than assign.
                  ? preferences.copyWith(clearRepetitionWindow: true)
                  : preferences.copyWith(repetitionWindowDays: days),
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
      // The local copy is dropped on success so the screen goes back to
      // reflecting the saved profile — and kept on failure so the edits are not
      // lost along with the write.
      if (failure == null) {
        _edited = null;
      }
    });
  }
}
