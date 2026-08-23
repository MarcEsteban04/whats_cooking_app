import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/domain/meal_moment.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_toggle.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';
import 'package:whats_cooking/features/profile/presentation/providers/reminder_controller.dart';
import 'package:whats_cooking/features/profile/presentation/widgets/settings_scaffold.dart';

/// The evening reminder (Sprint 56).
///
/// **This route existed for two sprints and led to a placeholder.** It was
/// reachable by deep link, deliberately left off the settings list, and the
/// comment on `SettingsScreen` said why: nothing in this app sent a notification,
/// so a tile here would teach somebody that tiles do not work. Now something
/// does, and this is that screen.
///
/// One switch and one time, and no more. Every other notification an app like
/// this could send — a partner accepted a meal, something expires tomorrow, your
/// week is over budget — is a reason for somebody to turn *all* of them off at the
/// operating system, which cannot be undone from in here. One notification that
/// earns its place is worth more than five that get muted together.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  /// Set when the operating system refused. Not an `AppException`: nothing failed
  /// and nothing is broken — somebody's phone said no, and the only useful
  /// response is a sentence about where to change that.
  String? _refusal;

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final ReminderSetting setting = ref.watch(reminderControllerProvider);

    return SettingsScaffold(
      title: 'Reminders',
      subtitle: 'One notification, at a time you pick.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_refusal case final String message) ...<Widget>[
            InlineErrorBanner(message: message),
            const SizedBox(height: AppSpacing.space4),
          ],

          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Ask(
                  isOn: setting.isOn,
                  isEnabled: !_isBusy,
                  onChanged: _setOn,
                ),
                const SizedBox(height: AppSpacing.space4),
                const DashboardRule(),
                DashboardRow(
                  title: 'Time',
                  subtitle: 'When to ask',
                  value: setting.label,
                  onTap: _isBusy ? null : () => _pickTime(setting),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.space4),

          // What it will actually say, in the words it will say them.
          //
          // Shown rather than described, because a notification is the one thing
          // in this app somebody cannot preview by tapping around — and a setting
          // whose effect is invisible until it happens is a setting people leave
          // alone.
          DashboardPanel(
            title: 'What it says',
            icon: AppIcons.notifications,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What’s for ${MealMoment.at(_at(setting)).mealName}?',
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'Let us decide for you.',
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  // The three things that are true and would otherwise be
                  // surprises. Every one of them is somebody's bug report.
                  'It follows the clock, so a morning time asks about '
                  'breakfast.\n'
                  'It skips an evening that is already decided.\n'
                  'It says what needs using up when something does.',
                  style: context.text.metadata,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.space4),
          Text(
            // Said plainly, because it is a real limit rather than a detail.
            // ${MealReminder.horizon} reminders are laid down at a time and the
            // queue is refilled whenever the app opens — so a fortnight of never
            // opening it does run out, and somebody should hear that from the app
            // rather than notice it.
            'A week of reminders is set at a time, topped up whenever you open '
            'the app.',
            style: context.text.metadata.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// The next time a reminder would land, for the preview above.
  DateTime _at(ReminderSetting setting) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, setting.hour, setting.minute);
  }

  Future<void> _setOn(bool isOn) async {
    setState(() {
      _isBusy = true;
      _refusal = null;
    });

    final String? refusal = await ref
        .read(reminderControllerProvider.notifier)
        .setOn(isOn);

    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = false;
      _refusal = refusal;
    });
  }

  /// The platform time picker.
  ///
  /// Material's own, not a hand-built control, and the one place in this app that
  /// is the right call: choosing a time of day is a solved problem with a
  /// muscle-memory answer on both platforms, and a bespoke clock face would be
  /// unfamiliar in exchange for matching a palette. It inherits the app's theme,
  /// so it is not a foreign object either.
  Future<void> _pickTime(ReminderSetting setting) async {
    final TimeOfDay? chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: setting.hour, minute: setting.minute),
      helpText: 'ASK ME AT',
    );

    if (chosen == null || !mounted) {
      return;
    }

    await ref
        .read(reminderControllerProvider.notifier)
        .setTime(hour: chosen.hour, minute: chosen.minute);
  }
}

/// The one switch.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.isOn,
    required this.isEnabled,
    required this.onChanged,
  });

  final bool isOn;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      onTap: isEnabled ? () => onChanged(!isOn) : null,
      isButton: false,
      semanticLabel: 'Ask me what to eat',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Ask me what to eat', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'So deciding does not have to start with remembering this '
                  'app exists.',
                  style: context.text.metadata,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space4),
          // Excluded from semantics: the row already announces itself, and two
          // toggles in the tree for one control is what makes a screen reader
          // read everything twice.
          ExcludeSemantics(
            child: AppToggle(
              value: isOn,
              onChanged: isEnabled ? onChanged : null,
              semanticLabel: 'Ask me what to eat',
            ),
          ),
        ],
      ),
    );
  }
}
