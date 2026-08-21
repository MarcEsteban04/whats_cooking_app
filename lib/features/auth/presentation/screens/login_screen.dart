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
import 'package:whats_cooking/core/widgets/inputs/app_toggle.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';
import 'package:whats_cooking/features/auth/presentation/widgets/auth_scaffold.dart';

/// "Welcome Back" — the left-hand screen of
/// `docs/reference_design/login_reference.webp`.
///
/// The reference's Google and Apple buttons and the "or" divider beneath them are
/// deliberately absent: social sign-in was removed from scope
/// (docs/MVP_SCOPE.md §7), so the email form is the only route and nothing
/// stands in for the buttons.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.prefilledEmail, super.key});

  /// An address carried over from a sign-up that hit an existing account
  /// (docs/USER_FLOWS.md §2).
  final String? prefilledEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.prefilledEmail ?? '');

    // **Arriving on this screen clears the last failure.**
    //
    // `AuthController` is shared by the sign-in and sign-up forms, and moving
    // between them never drops its listener count to zero — the new screen
    // subscribes in the same frame the old one unsubscribes — so an
    // `AuthFailed` set on one form was still there on the other. What that looked
    // like on a phone: "Those details did not match" sitting above an empty
    // password field that was *separately* complaining "Enter your password",
    // which is two errors describing nothing that just happened.
    //
    // Deferred to after the first frame, because a provider must not be written
    // to during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      Validators.email(_email.text) == null &&
      Validators.existingPassword(_password.text) == null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);

    // docs/USER_FLOWS.md §3: on a failed login the password is cleared. Retyping
    // it is a small cost; leaving a rejected secret on screen is not.
    if (mounted && ref.read(authControllerProvider) is AuthFailed) {
      _password.clear();
    }
    // Nothing navigates on success. The session changes, the router's redirect
    // notices, and the app moves (docs/NAVIGATION_MAP.md §4).
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState formState = ref.watch(authControllerProvider);
    final AppException? failure = formState.failure;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in with your email and password to pick up where you left off.',
      onBack: () => context.goNamed(AppRoute.welcome.routeName),
      footer: AuthFooterPrompt(
        question: "Don't have an account?",
        actionLabel: 'Sign Up',
        onAction: () => context.goNamed(AppRoute.register.routeName),
      ),
      children: <Widget>[
        if (failure != null) ...<Widget>[
          // A banner rather than a field error: a failed login is not attributed
          // to either field, which is the enumeration defence §3 asks for.
          InlineErrorBanner(
            message: failure.message,
            // The backend's own reason, development builds only. Without it a
            // sign-in that fails on a device is undiagnosable.
            detail: failure.detail,
          ),
          const SizedBox(height: AppSpacing.space4),
        ],
        AppTextField(
          controller: _email,
          label: 'Email Address',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: Validators.email,
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          controller: _password,
          label: 'Password',
          hint: '••••••••',
          isObscured: true,
          textInputAction: TextInputAction.done,
          validator: Validators.existingPassword,
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppToggleRow(
          value: _rememberMe,
          onChanged: formState.isSubmitting
              ? null
              : (bool value) => setState(() => _rememberMe = value),
          label: Text('Remember me', style: context.text.bodySmall),
          trailing: AppButton.tertiary(
            label: 'Forgot Password?',
            size: AppButtonSize.small,
            onPressed: formState.isSubmitting
                ? null
                : () => context.goNamed(AppRoute.forgotPassword.routeName),
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        AppButton.inverse(
          label: 'Sign In',
          isLoading: formState.isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
