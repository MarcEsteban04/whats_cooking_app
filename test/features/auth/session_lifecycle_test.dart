import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/router/app_routes.dart';
import 'package:whats_cooking/core/router/router_guards.dart';
import 'package:whats_cooking/features/auth/domain/entities/app_session.dart';

/// Sprint 17's rules: what a session means, and where the router sends it.
///
/// The Supabase repository itself is not unit-tested here — it needs a live
/// project, which belongs in Sprint 65's integration pass. What *is* tested is
/// everything that decides behaviour from a session: the guard, the recovery
/// trap, and the error mapping the screens depend on.
void main() {
  group('the password-recovery session', () {
    const AppSession recovering = AppSession.recoveringPassword();

    test('is authenticated, because Supabase really does sign the user in', () {
      expect(recovering.isAuthenticated, isTrue);
      expect(recovering.isRecoveringPassword, isTrue);
    });

    test('is not confused with an ordinary sign-in', () {
      const AppSession normal = AppSession.signedIn(
        isOnboarded: true,
        hasHousehold: true,
      );

      expect(normal.isRecoveringPassword, isFalse);
      expect(recovering, isNot(normal));
    });

    test('can only reach the reset screen', () {
      // The trap this closes: a recovery link signs the user in, so without the
      // flag every rule below sends them to Home — live session, half-finished
      // reset, no way back to the form.
      for (final AppRoute route in <AppRoute>[
        AppRoute.home,
        AppRoute.meals,
        AppRoute.profile,
        AppRoute.welcome,
        AppRoute.login,
        AppRoute.onboarding,
      ]) {
        expect(
          RouterGuard.redirect(location: route.path, session: recovering),
          AppRoute.resetPassword.path,
          reason: '${route.name} should be held for the reset',
        );
      }
    });

    test('is allowed to stay on the reset screen', () {
      expect(
        RouterGuard.redirect(
          location: AppRoute.resetPassword.path,
          session: recovering,
        ),
        isNull,
      );
    });

    test('does not loop', () {
      // The redirect target must itself be allowed, or the router bounces
      // forever on a white screen.
      final String? first = RouterGuard.redirect(
        location: AppRoute.home.path,
        session: recovering,
      );
      expect(
        RouterGuard.redirect(location: first!, session: recovering),
        isNull,
      );
    });
  });

  group('the preserved destination is actually spent', () {
    // docs/USER_FLOWS.md §18: "The user is returned to where they were after
    // re-authenticating. Never dump them on Home." The guard wrote the parameter
    // on the way in from the start; until Sprint 17 nothing read it back.
    const AppSession onboarded = AppSession.signedIn(
      isOnboarded: true,
      hasHousehold: true,
    );

    test('a signed-in user lands on the interrupted route', () {
      final String? redirect = RouterGuard.redirect(
        location: '/welcome?redirect=/meals/abc-123',
        session: onboarded,
      );

      expect(redirect, '/meals/abc-123');
    });

    test('an invite code survives the detour', () {
      // The growth path (docs/NAVIGATION_MAP.md §5): a partner who taps an
      // invite must land in the household, not on Home having lost the code.
      final String? redirect = RouterGuard.redirect(
        location: '/login?redirect=/couple/join%3Fcode%3DABC123',
        session: onboarded,
      );

      expect(redirect, contains('/couple/join'));
      expect(redirect, contains('ABC123'));
    });

    test('without one, Home is still the destination', () {
      expect(
        RouterGuard.redirect(location: AppRoute.login.path, session: onboarded),
        AppRoute.home.path,
      );
    });

    test('an off-site destination is refused', () {
      // A crafted link must not be able to use the app to bounce someone
      // elsewhere immediately after they sign in.
      expect(
        RouterGuard.redirect(
          location: '/login?redirect=https://evil.example.com',
          session: onboarded,
        ),
        AppRoute.home.path,
      );
    });

    test('the round trip is symmetrical', () {
      // Signed out, the guard writes the parameter; signed in, it spends it. The
      // two halves have to agree on the encoding or the destination is lost.
      const AppSession signedOut = AppSession.signedOut();

      final String? outbound = RouterGuard.redirect(
        location: '/meals/abc-123',
        session: signedOut,
      );
      final String? inbound = RouterGuard.redirect(
        location: outbound!,
        session: onboarded,
      );

      expect(inbound, '/meals/abc-123');
    });
  });

  group('rate limiting is its own failure', () {
    // docs/USER_FLOWS.md §3 gives it its own path and copy: "Too many attempts |
    // Rate-limit message with wait time".
    test('a 429 does not read as a rejected credential', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException('Too many requests', statusCode: '429'),
      );

      expect(mapped, isA<RateLimitException>());
      expect(
        mapped,
        isNot(isA<AuthFailureException>()),
        reason:
            'telling someone their password is wrong when it is not sends '
            'them to change a perfectly good password',
      );
    });

    test('it is never retried automatically', () {
      // The one failure where a retry is precisely wrong: it extends the
      // lockout.
      expect(const RateLimitException().isRetryable, isFalse);
    });

    test('the wait is lifted out of the message', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException(
          'For security purposes, you can only request this after 21 seconds.',
          statusCode: '429',
        ),
      );

      expect(
        (mapped as RateLimitException).retryAfter,
        const Duration(seconds: 21),
      );
      expect(mapped.message, contains('21 seconds'));
    });

    test('the backend sentence itself is never displayed', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException(
          'For security purposes, you can only request this after 21 seconds.',
          statusCode: '429',
        ),
      );

      expect(mapped.message, isNot(contains('For security purposes')));
      expect(mapped.detail, contains('For security purposes'));
    });

    test('a rate limit with no stated wait still reads sensibly', () {
      final AppException mapped = ErrorMapper.map(
        const supabase.AuthException('Email rate limit exceeded'),
      );

      expect(mapped, isA<RateLimitException>());
      expect((mapped as RateLimitException).retryAfter, isNull);
      expect(mapped.message, isNot(contains('null')));
    });
  });

  group('session states', () {
    test('restoring is distinct from signed out', () {
      // Collapsing the two flashes the welcome screen on every cold start.
      const AppSession restoring = AppSession.restoring();

      expect(restoring.isRestoring, isTrue);
      expect(restoring.isUnauthenticated, isFalse);
      expect(restoring, isNot(const AppSession.signedOut()));
    });

    test('equality covers every field', () {
      // The router rebuilds on a session change, so a field left out of equality
      // is a change the router never hears about.
      const AppSession base = AppSession.signedIn(
        isOnboarded: true,
        hasHousehold: true,
      );

      expect(base.copyWith(isOnboarded: false), isNot(base));
      expect(base.copyWith(hasHousehold: false), isNot(base));
      expect(base.copyWith(isRecoveringPassword: true), isNot(base));
      expect(base.copyWith(), base);
    });

    test('a recovering session reports onboarding satisfied', () {
      // Not cosmetic: claiming otherwise would bounce the recovery session
      // through the onboarding guard on its way to the reset form.
      const AppSession recovering = AppSession.recoveringPassword();

      expect(recovering.isOnboarded, isTrue);
      expect(recovering.hasHousehold, isTrue);
    });
  });
}
