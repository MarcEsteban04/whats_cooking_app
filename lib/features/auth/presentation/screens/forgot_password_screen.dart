import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/validators.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';
import 'package:whats_cooking/features/auth/presentation/widgets/auth_scaffold.dart';

/// Requests a password-reset email (docs/USER_FLOWS.md §4).
///
/// The confirmation deliberately says the same thing whether or not the address
/// has an account. §4: "again, enumeration defence." A screen that said "no such
/// account" would be a free tool for checking which addresses are registered
/// here.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _canSubmit => Validators.email(_email.text) == null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState formState = ref.watch(authControllerProvider);

    if (formState is AuthSucceeded) {
      return _ResetLinkSent(
        email: _email.text.trim(),
        onBackToLogin: () {
          ref.read(authControllerProvider.notifier).reset();
          context.goNamed(AppRoute.login.routeName);
        },
      );
    }

    final AppException? failure = formState.failure;

    return AuthScaffold(
      title: 'Reset your password',
      subtitle:
          'Enter the email you signed up with and we will send you a link to '
          'set a new password.',
      onBack: () => context.goNamed(AppRoute.login.routeName),
      children: <Widget>[
        if (failure != null) ...<Widget>[
          InlineErrorBanner(message: failure.message),
          const SizedBox(height: AppSpacing.space4),
        ],
        AppTextField(
          controller: _email,
          label: 'Email Address',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          validator: Validators.email,
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.space6),
        AppButton.inverse(
          label: 'Send reset link',
          isLoading: formState.isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

/// The confirmation, worded so it reveals nothing.
class _ResetLinkSent extends StatelessWidget {
  const _ResetLinkSent({required this.email, required this.onBackToLogin});

  final String email;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Check your email',
      // "If there is an account" — not "we sent it". True either way, and it
      // gives nothing away.
      subtitle:
          'If there is an account for $email, a reset link is on its way. The '
          'link works once and expires in an hour.',
      onBack: onBackToLogin,
      children: <Widget>[
        AppButton.inverse(label: 'Back to sign in', onPressed: onBackToLogin),
      ],
    );
  }
}
