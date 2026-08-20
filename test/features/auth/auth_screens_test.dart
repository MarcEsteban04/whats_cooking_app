import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/inputs/app_toggle.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';
import 'package:whats_cooking/features/auth/domain/repositories/auth_repository.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_controller.dart';
import 'package:whats_cooking/features/auth/presentation/providers/auth_repository_provider.dart';
import 'package:whats_cooking/features/auth/presentation/providers/session_provider.dart';
import 'package:whats_cooking/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/login_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/register_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:whats_cooking/features/auth/presentation/screens/welcome_screen.dart';
import 'package:whats_cooking/features/auth/presentation/widgets/auth_success_sheet.dart';

import '../../support/component_harness.dart';

/// The auth screens from `docs/reference_design/login_reference.webp`, and the
/// security rules docs/USER_FLOWS.md §2–§4 attach to them.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              size: surfaceSize ?? const Size(400, 800),
            ),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Taps a button after scrolling it into view.
  ///
  /// The auth forms are taller than a test viewport once the footer is pinned,
  /// so a bare tap on the CTA silently misses and the test fails much later with
  /// a confusing message.
  Future<void> tapButton(WidgetTester tester, String label) async {
    final Finder button = find.widgetWithText(AppButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapToggle(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(AppToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
  }

  group('the reference has no social sign-in', () {
    // docs/MVP_SCOPE.md §7 removed it, so the reference's Google and Apple
    // buttons and the "or" divider beneath them are absent — and must stay
    // absent rather than creeping back in as disabled placeholders.
    testWidgets('login offers neither Google nor Apple', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const LoginScreen());

      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Apple'), findsNothing);
      expect(find.text('or'), findsNothing);
    });

    testWidgets('register offers neither Google nor Apple', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const RegisterScreen());

      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Apple'), findsNothing);
      expect(find.text('or'), findsNothing);
    });
  });

  group('LoginScreen', () {
    testInBothThemes('renders the reference layout', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, const LoginScreen(), brightness: brightness);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign In'), findsOneWidget);
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
    });

    testWidgets('the primary CTA is the near-black pill, not green', (
      WidgetTester tester,
    ) async {
      // The reference's CTA colour, which differs from
      // docs/DESIGN_SYSTEM.md §2.5's green primary.
      await pumpScreen(tester, const LoginScreen());

      final AppButton signIn = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Sign In'),
      );

      expect(signIn.variant, AppButtonVariant.inverse);
      expect(signIn.isFullWidth, isTrue);
    });

    testWidgets('Sign In is disabled until both fields are valid', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const LoginScreen());

      AppButton button() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Sign In'));

      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'marc@example.com');
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'no password yet');

      await tester.enterText(find.byType(TextField).last, 'a-password');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('a rejected login does not say which field was wrong', (
      WidgetTester tester,
    ) async {
      // docs/USER_FLOWS.md §3: "A failed login never states which field was
      // wrong — standard credential-enumeration defence."
      await pumpScreen(tester, const LoginScreen());

      await tester.enterText(
        find.byType(TextField).first,
        'nobody@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'wrong-password');
      await tester.pump();

      await tapButton(tester, 'Sign In');

      expect(find.text('Those details did not match'), findsOneWidget);
      // Nothing attributes the failure to a field. Checked as specific phrasings
      // rather than the word "email", which the field's own label contains.
      for (final String leak in <String>[
        'No account',
        'not registered',
        'Incorrect password',
        'Wrong password',
        'That password',
      ]) {
        expect(find.textContaining(leak), findsNothing, reason: leak);
      }
    });

    testWidgets('a rejected login clears the password', (
      WidgetTester tester,
    ) async {
      // §3 again. Leaving a rejected secret on screen is a needless exposure.
      await pumpScreen(tester, const LoginScreen());

      await tester.enterText(
        find.byType(TextField).first,
        'nobody@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'wrong-password');
      await tester.pump();
      await tapButton(tester, 'Sign In');

      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        isEmpty,
      );
    });

    testWidgets('an address carried from sign-up is pre-filled', (
      WidgetTester tester,
    ) async {
      // §2: an already-registered address "offers a one-tap route to login with
      // the address pre-filled — never a dead-end error".
      await pumpScreen(
        tester,
        const LoginScreen(prefilledEmail: 'marc@example.com'),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'marc@example.com',
      );
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const LoginScreen(),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('RegisterScreen', () {
    testInBothThemes('renders the reference layout', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, const RegisterScreen(), brightness: brightness);

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(AppToggle), findsOneWidget);
      expect(find.textContaining('I agree to the'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign Up'), findsOneWidget);
      expect(find.textContaining('Already have an account?'), findsOneWidget);
    });

    testWidgets('Sign Up needs the terms accepted', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const RegisterScreen());

      AppButton button() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Sign Up'));

      await tester.enterText(find.byType(TextField).at(0), 'Marc');
      await tester.enterText(find.byType(TextField).at(1), 'marc@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'a-long-password');
      await tester.pump();

      expect(
        button().onPressed,
        isNull,
        reason: 'the terms toggle is still off',
      );

      await tapToggle(tester);

      expect(button().onPressed, isNotNull);
    });

    testWidgets('a successful sign-up shows the celebration sheet', (
      WidgetTester tester,
    ) async {
      // The reference's middle panel.
      await pumpScreen(tester, const RegisterScreen());

      await tester.enterText(find.byType(TextField).at(0), 'Marc');
      await tester.enterText(find.byType(TextField).at(1), 'marc@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'a-long-password');
      await tapToggle(tester);

      await tapButton(tester, 'Sign Up');

      expect(find.byType(AuthSuccessSheet), findsOneWidget);
      expect(find.text('Welcome aboard!'), findsOneWidget);
    });

    testWidgets('a duplicate address offers sign-in instead of a dead end', (
      WidgetTester tester,
    ) async {
      // §2's rule, and the reason EmailAlreadyRegistered is its own type rather
      // than a message to match on.
      Future<void> submit() async {
        await tester.enterText(find.byType(TextField).at(0), 'Marc');
        await tester.enterText(find.byType(TextField).at(1), 'dup@example.com');
        await tester.enterText(find.byType(TextField).at(2), 'a-long-password');
        if (!tester.widget<AppToggle>(find.byType(AppToggle)).value) {
          await tapToggle(tester);
        }
        await tapButton(tester, 'Sign Up');
      }

      await pumpScreen(tester, const RegisterScreen());
      await submit();

      // Second attempt with the same address.
      container.read(authControllerProvider.notifier).reset();
      await pumpScreen(tester, const RegisterScreen());
      await submit();

      expect(find.textContaining('already has an account'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign in instead'), findsOneWidget);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const RegisterScreen(),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('confirms without revealing whether the account exists', (
      WidgetTester tester,
    ) async {
      // docs/USER_FLOWS.md §4: "The confirmation screen says the same thing
      // whether or not the address exists — again, enumeration defence."
      await pumpScreen(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), 'nobody@example.com');
      await tester.pump();
      await tapButton(tester, 'Send reset link');

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('If there is an account'), findsOneWidget);
      expect(find.textContaining('No account'), findsNothing);
      expect(find.textContaining("doesn't exist"), findsNothing);
    });

    testWidgets('the send button waits for a valid address', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ForgotPasswordScreen());

      AppButton button() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Send reset link'),
      );

      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pump();
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'marc@example.com');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('a link with no token explains and offers a resend', (
      WidgetTester tester,
    ) async {
      // §4 draws this path: "Expired or used → Explain and offer resend".
      await pumpScreen(tester, const ResetPasswordScreen());

      expect(find.text('That link has expired'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Send a new link'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'a form that cannot work should not be offered',
      );
    });

    testWidgets('a valid token shows the form', (WidgetTester tester) async {
      await pumpScreen(tester, const ResetPasswordScreen(token: 'abc123'));

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('the passwords have to match', (WidgetTester tester) async {
      await pumpScreen(tester, const ResetPasswordScreen(token: 'abc123'));

      AppButton button() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Save and sign in'),
      );

      await tester.enterText(find.byType(TextField).first, 'a-long-password');
      await tester.enterText(find.byType(TextField).last, 'a-different-one');
      await tester.pump();
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'a-long-password');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });
  });

  group('WelcomeScreen', () {
    testInBothThemes('leads with the product and two ways in', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, const WelcomeScreen(), brightness: brightness);

      expect(find.text("What's Cooking?"), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Get started'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'I already have an account'),
        findsOneWidget,
      );
    });

    testWidgets('shows the product rather than describing it', (
      WidgetTester tester,
    ) async {
      // Built to the home-screen reference, not the auth one: the first screen
      // should already look like the app it opens. Three floating cards say what
      // the roulette does, in the reference's own card language.
      await pumpScreen(tester, const WelcomeScreen());

      expect(find.text('What are we\neating tonight?'), findsOneWidget);
      for (final String promise in <String>['Spin', 'Agree', 'Eat']) {
        expect(find.text(promise), findsOneWidget, reason: promise);
      }
    });

    testWidgets('guest mode is offered but disabled until Sprint 29', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const WelcomeScreen());

      final AppButton guest = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Try it first'),
      );

      expect(guest.onPressed, isNull);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      // The staggered cluster indents each card further than the last, which is
      // exactly the kind of layout that clips on the narrowest device.
      await pumpScreen(
        tester,
        const WelcomeScreen(),
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });

  group('sign-up when the address needs confirming', () {
    // The Supabase default. `signUp` returns a user and **no session**, and the
    // account is unusable until the link is followed.
    //
    // This is the bug that made an account look broken: treated as a success,
    // the app sent the user into onboarding holding no access token, every write
    // was refused by Row Level Security, and the next launch showed a signed-out
    // app with an account they could not sign in to.
    setUp(() {
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _ConfirmationRequiredRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<void> submitSignUp(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Marc');
      await tester.enterText(find.byType(TextField).at(1), 'marc@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'a-long-password');
      await tapToggle(tester);
      await tapButton(tester, 'Sign Up');
    }

    testWidgets('sends the user to their inbox, not into onboarding', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const RegisterScreen());
      await submitSignUp(tester);

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('marc@example.com'), findsOneWidget);
      expect(
        find.text("Let's get cooking"),
        findsNothing,
        reason: 'onboarding must not be offered without a session',
      );
    });

    testWidgets('publishes no session', (WidgetTester tester) async {
      // The whole point. A session here would move the router into the app on an
      // account that cannot read or write a single row.
      await pumpScreen(tester, const RegisterScreen());
      await submitSignUp(tester);

      expect(container.read(sessionProvider).isAuthenticated, isFalse);
    });

    testWidgets('does not celebrate', (WidgetTester tester) async {
      // Nothing has succeeded yet. Confetti and a green check would tell the
      // user they were finished when they have one step left.
      await pumpScreen(tester, const RegisterScreen());
      await submitSignUp(tester);

      final AuthSuccessSheet sheet = tester.widget<AuthSuccessSheet>(
        find.byType(AuthSuccessSheet),
      );

      expect(sheet.tone, AuthSheetTone.awaiting);
      expect(find.bySemanticsLabel('Success'), findsNothing);
    });
  });

  group('the session is the only route out', () {
    testWidgets('signing in publishes a session rather than pushing a route', (
      WidgetTester tester,
    ) async {
      // docs/NAVIGATION_MAP.md §4: no screen performs its own auth check or its
      // own post-login navigation. The session changes and the router reacts.
      await pumpScreen(tester, const RegisterScreen());

      expect(container.read(sessionProvider).isAuthenticated, isFalse);

      await tester.enterText(find.byType(TextField).at(0), 'Marc');
      await tester.enterText(find.byType(TextField).at(1), 'marc@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'a-long-password');
      await tapToggle(tester);
      await tapButton(tester, 'Sign Up');

      final AppSession session = container.read(sessionProvider);
      expect(session.isAuthenticated, isTrue);
      expect(
        session.isOnboarded,
        isFalse,
        reason: 'a new account goes to onboarding (docs/USER_FLOWS.md §2)',
      );
    });
  });
}

/// An auth backend that answers sign-up the way Supabase does when the project
/// has **Confirm email** switched on: the account is created, and no session
/// comes back with it.
///
/// Only [signUp] is reachable from the screen under test. The rest throw rather
/// than returning something plausible, so a test that starts depending on them
/// says so instead of quietly passing against a stub.
class _ConfirmationRequiredRepository implements AuthRepository {
  @override
  Future<AppSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    throw EmailConfirmationRequired(email.trim());
  }

  @override
  Future<AppSession> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<AppSession> updatePassword({required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AppSession?> restoreSession() => throw UnimplementedError();
}
