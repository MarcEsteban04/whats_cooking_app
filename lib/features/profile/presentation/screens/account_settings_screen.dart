import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/validators.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/cards/icon_list_row.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/core/widgets/section_header.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';
import 'package:whats_cooking/features/profile/presentation/widgets/settings_scaffold.dart';

/// Name, password, sign out and deletion (docs/USER_FLOWS.md §17).
///
/// The screen where the two irreversible actions live, and both are gated:
/// signing out confirms once, deleting confirms **twice** and states plainly what
/// goes and what the household keeps — §17's exact requirement.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final TextEditingController _name = TextEditingController();
  bool _hasSeededName = false;
  bool _isSavingName = false;
  AppException? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? currentName = ref
        .watch(profileControllerProvider)
        .value
        ?.displayName;

    if (currentName != null && !_hasSeededName) {
      _hasSeededName = true;
      _name.text = currentName;
    }

    final bool canSaveName =
        Validators.displayName(_name.text) == null &&
        _name.text.trim() != currentName;

    return SettingsScaffold(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null) ...<Widget>[
            InlineErrorBanner(message: _failure!.message),
            const SizedBox(height: AppSpacing.space4),
          ],
          AppTextField(
            controller: _name,
            label: 'Your name',
            validator: Validators.displayName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: 'Save name',
              size: AppButtonSize.medium,
              isLoading: _isSavingName,
              onPressed: canSaveName ? _saveName : null,
            ),
          ),

          const SectionHeader(title: 'Security'),
          IconListCard(
            rows: <Widget>[
              IconListRow(
                title: 'Change password',
                icon: Icons.lock_outline_rounded,
                value: 'We will email you a link',
                onTap: () => context.goNamed(AppRoute.forgotPassword.routeName),
              ),
            ],
          ),

          const SectionHeader(title: 'Leaving'),
          IconListCard(
            rows: <Widget>[
              IconListRow(
                title: 'Sign out',
                icon: Icons.logout_rounded,
                onTap: _signOut,
              ),
              IconListRow(
                title: 'Delete my account',
                icon: AppIcons.delete,
                value: 'This cannot be undone',
                tone: IconListRowTone.destructive,
                onTap: _deleteAccount,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space7),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    setState(() {
      _isSavingName = true;
      _failure = null;
    });

    final AppException? failure = await ref
        .read(profileControllerProvider.notifier)
        .updateDisplayName(_name.text);

    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingName = false;
      _failure = failure;
    });
  }

  Future<void> _signOut() async {
    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign out?',
      body: 'You will need your email and password to get back in.',
      confirmLabel: 'Sign out',
    );

    if (!confirmed || !mounted) {
      return;
    }
    // Nothing navigates. The session changes and the router's redirect returns
    // the app to the public zone (docs/NAVIGATION_MAP.md §4).
    await ref.read(authControllerProvider.notifier).signOut();
  }

  /// Deletion, confirmed twice.
  ///
  /// docs/USER_FLOWS.md §17: "Account deletion requires double confirmation and
  /// states plainly what is destroyed and what the household retains."
  ///
  /// The two dialogs are not the same question asked twice. The first explains
  /// the consequence; the second is the point of no return. Someone who taps
  /// through the first out of habit still has to read the second.
  Future<void> _deleteAccount() async {
    final bool understood = await ConfirmationDialog.show(
      context,
      title: 'Delete your account?',
      body:
          'Your profile, preferences, favourites and meal history are deleted '
          'permanently. Meals you added to a shared kitchen stay with the '
          'household, and your partner keeps their own.',
      confirmLabel: 'Continue',
      isDestructive: true,
      icon: AppIcons.delete,
    );

    if (!understood || !mounted) {
      return;
    }

    final bool confirmed = await ConfirmationDialog.show(
      context,
      title: 'Last chance',
      body: 'This cannot be undone. Delete everything?',
      confirmLabel: 'Delete permanently',
      cancelLabel: 'Keep my account',
      isDestructive: true,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final AppException? failure = await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount();

    if (!mounted) {
      return;
    }
    // Surfaced rather than swallowed: this is the one action where a silent
    // failure leaves someone believing their data is gone when it is not.
    setState(() => _failure = failure);
  }
}
