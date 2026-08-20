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
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/auth/presentation/widgets/auth_scaffold.dart';

/// Sets a new password after following a reset link (docs/USER_FLOWS.md §4).
///
/// Reached by deep link with a `token` (docs/NAVIGATION_MAP.md §5), and the one
/// public route the guard lets an authenticated user reach — changing a password
/// while signed in is the normal case, not an anomaly.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.token, super.key});

  /// The recovery token from the link, when the link carries one.
  ///
  /// Often it does not. Under PKCE the SDK consumes the code itself and hands
  /// the app a recovery *session* instead, so a token only appears on the older
  /// link format. Either authorises the change; neither being present is a real
  /// state, and the screen says so rather than presenting a form that cannot
  /// work.
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      Validators.newPassword(_password.text) == null &&
      Validators.passwordConfirmation(_password.text)(_confirmation.text) ==
          null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .updatePassword(newPassword: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppSession session = ref.watch(sessionProvider);

    // Authorised by a token in the link, or by the recovery session the SDK
    // established from it. Requiring the token alone would show "link expired"
    // to everyone arriving through the PKCE flow — which is the flow this app
    // actually uses, so that would be everyone.
    final bool isAuthorised =
        (widget.token != null && widget.token!.isNotEmpty) ||
        session.isRecoveringPassword;

    if (!isAuthorised) {
      return _InvalidLink(
        onRequestAnother: () =>
            context.goNamed(AppRoute.forgotPassword.routeName),
      );
    }

    final AuthFormState formState = ref.watch(authControllerProvider);
    final AppException? failure = formState.failure;

    return AuthScaffold(
      title: 'Choose a new password',
      subtitle:
          'Pick something you will remember. We will sign you in straight '
          'afterwards.',
      onBack: () => context.goNamed(AppRoute.login.routeName),
      children: <Widget>[
        if (failure != null) ...<Widget>[
          InlineErrorBanner(message: failure.message),
          const SizedBox(height: AppSpacing.space4),
        ],
        AppTextField(
          controller: _password,
          label: 'New Password',
          hint: '••••••••',
          isObscured: true,
          textInputAction: TextInputAction.next,
          validator: Validators.newPassword,
          helperText: 'At least ${Validators.minPasswordLength} characters',
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          controller: _confirmation,
          label: 'Repeat Password',
          hint: '••••••••',
          isObscured: true,
          textInputAction: TextInputAction.done,
          validator: Validators.passwordConfirmation(_password.text),
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.space6),
        AppButton.inverse(
          label: 'Save and sign in',
          isLoading: formState.isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

/// Shown for a link with no token, or an expired one.
///
/// §4 draws this path explicitly: "Expired or used → Explain and offer resend".
class _InvalidLink extends StatelessWidget {
  const _InvalidLink({required this.onRequestAnother});

  final VoidCallback onRequestAnother;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'That link has expired',
      subtitle:
          'Reset links work once and expire after an hour. Ask for a fresh one '
          'and we will send it straight over.',
      onBack: onRequestAnother,
      children: <Widget>[
        AppButton.inverse(
          label: 'Send a new link',
          onPressed: onRequestAnother,
        ),
      ],
    );
  }
}
