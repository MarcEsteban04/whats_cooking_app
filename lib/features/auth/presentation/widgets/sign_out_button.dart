import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';

/// Signs the user out, after confirming.
///
/// Confirmed rather than immediate: signing out is cheap to undo on a phone with
/// a saved password and expensive on one without, and the dialog names what
/// happens (docs/COMPONENTS.md §10).
///
/// Nothing navigates afterwards. The session changes, the router's redirect
/// notices, and the app returns to the public zone
/// (docs/NAVIGATION_MAP.md §4).
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthFormState formState = ref.watch(authControllerProvider);

    return AppButton.secondary(
      label: 'Sign out',
      isFullWidth: false,
      isLoading: formState.isSubmitting,
      onPressed: () async {
        final bool confirmed = await ConfirmationDialog.show(
          context,
          title: 'Sign out?',
          body: 'You will need your email and password to get back in.',
          confirmLabel: 'Sign out',
        );

        if (!confirmed) {
          return;
        }
        await ref.read(authControllerProvider.notifier).signOut();
      },
    );
  }
}
