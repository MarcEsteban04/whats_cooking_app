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
import 'package:whats_cooking/features/auth/presentation/widgets/auth_success_sheet.dart';

/// "Create your account" — the right-hand screen of
/// `docs/reference_design/login_reference.webp`.
///
/// Full name, email, password, then the terms toggle and a near-black pill CTA.
/// The reference's social buttons are absent (docs/MVP_SCOPE.md §7).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _acceptedTerms &&
      Validators.displayName(_name.text) == null &&
      Validators.email(_email.text) == null &&
      Validators.newPassword(_password.text) == null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState formState = ref.watch(authControllerProvider);

    // The reference's middle screen: a white sheet over the dimmed form, with a
    // green check and a pinned action. Shown in place of navigating away, so the
    // moment reads as a confirmation of *this* screen's work.
    if (formState is AuthSucceeded) {
      return AuthSuccessSheet(
        title: 'Welcome aboard!',
        message:
            'Your account is ready. Tell us what you like to eat and we '
            'will start picking.',
        actionLabel: "Let's get cooking",
        onAction: () => context.goNamed(AppRoute.onboarding.routeName),
      );
    }

    // The account exists but has no session yet, because the project requires
    // the address to be confirmed. Sending them to onboarding here is what makes
    // an account look broken on the next launch: they would answer seven
    // questions that no policy lets them save.
    if (formState is AuthAwaitingEmailConfirmation) {
      return AuthSuccessSheet(
        tone: AuthSheetTone.awaiting,
        title: 'Check your email',
        message:
            'We sent a confirmation link to ${formState.email}. Open it, '
            'then sign in and we will start picking.',
        actionLabel: 'Back to sign in',
        onAction: () => context.goNamed(
          AppRoute.login.routeName,
          queryParameters: <String, String>{'email': formState.email},
        ),
      );
    }

    final AppException? failure = formState.failure;
    final String? suggestLoginFor = formState is AuthFailed
        ? formState.suggestLoginFor
        : null;

    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'Your name, your email, a password — then we can start deciding '
          'dinner for you.',
      onBack: () => context.goNamed(AppRoute.welcome.routeName),
      footer: AuthFooterPrompt(
        question: 'Already have an account?',
        actionLabel: 'Sign In',
        onAction: () => context.goNamed(AppRoute.login.routeName),
      ),
      children: <Widget>[
        if (failure != null && suggestLoginFor == null) ...<Widget>[
          InlineErrorBanner(message: failure.message),
          const SizedBox(height: AppSpacing.space4),
        ],
        if (suggestLoginFor != null) ...<Widget>[
          // §2: an already-registered address "offers a one-tap route to login
          // with the address pre-filled — never a dead-end error".
          _AlreadyRegisteredBanner(
            email: suggestLoginFor,
            onSignIn: () => context.goNamed(
              AppRoute.login.routeName,
              queryParameters: <String, String>{'email': suggestLoginFor},
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
        ],
        AppTextField(
          controller: _name,
          label: 'Full Name',
          hint: 'Marc Esteban',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: Validators.displayName,
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space4),
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
          validator: Validators.newPassword,
          helperText: 'At least ${Validators.minPasswordLength} characters',
          isEnabled: !formState.isSubmitting,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppToggleRow(
          value: _acceptedTerms,
          onChanged: formState.isSubmitting
              ? null
              : (bool value) => setState(() => _acceptedTerms = value),
          label: const _TermsLabel(),
        ),
        const SizedBox(height: AppSpacing.space6),
        AppButton.inverse(
          label: 'Sign Up',
          isLoading: formState.isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

/// "I agree to the **Terms** & **Privacy Policy**", with the documents emphasised
/// as the reference shows them.
class _TermsLabel extends StatelessWidget {
  const _TermsLabel();

  @override
  Widget build(BuildContext context) {
    final TextStyle base = context.text.bodySmall.copyWith(
      color: context.colors.textSecondary,
    );
    final TextStyle emphasis = context.text.labelSmall.copyWith(
      color: context.colors.textPrimary,
    );

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: 'I agree to the ', style: base),
          TextSpan(text: 'Terms', style: emphasis),
          TextSpan(text: ' & ', style: base),
          TextSpan(text: 'Privacy Policy', style: emphasis),
        ],
      ),
    );
  }
}

/// The recovery path for an address that already has an account.
class _AlreadyRegisteredBanner extends StatelessWidget {
  const _AlreadyRegisteredBanner({required this.email, required this.onSignIn});

  final String email;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: AppRadius.borderMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$email already has an account.',
              style: context.text.bodySmall.copyWith(
                color: colors.info.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            AppButton.secondary(
              label: 'Sign in instead',
              size: AppButtonSize.small,
              onPressed: onSignIn,
            ),
          ],
        ),
      ),
    );
  }
}
