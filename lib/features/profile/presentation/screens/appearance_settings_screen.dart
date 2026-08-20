import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/preferences/selectable_tile.dart';
import 'package:whats_cooking/features/profile/presentation/providers/theme_mode_controller.dart';
import 'package:whats_cooking/features/profile/presentation/widgets/settings_scaffold.dart';

/// Light, dark or system (docs/USER_FLOWS.md §17).
///
/// Tiles rather than chips: three options, each worth reading, which is exactly
/// the case docs/COMPONENTS.md §18b names for tiles — and §18b lists "which theme
/// to use" among them explicitly.
///
/// No save button. Appearance is the one setting whose effect *is* the feedback:
/// the screen changes colour under your thumb, so asking someone to confirm what
/// they can already see would be strange.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode current = ref.watch(themeModeControllerProvider);

    return SettingsScaffold(
      title: 'Appearance',
      subtitle: 'Applies straight away.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ThemeMode mode in ThemeMode.values) ...<Widget>[
            SelectableTile(
              title: mode.label,
              caption: mode.caption,
              icon: mode.icon,
              isSelected: current == mode,
              onSelected: () =>
                  ref.read(themeModeControllerProvider.notifier).set(mode),
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
        ],
      ),
    );
  }
}
