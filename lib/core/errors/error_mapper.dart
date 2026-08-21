import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/utils/logger.dart';

/// Turns backend and platform failures into [AppException]s.
///
/// docs/ARCHITECTURE.md §9: "Mapping happens exactly once, in the data layer."
/// This is that one place. §4 is blunt about why it matters: "**No Supabase type
/// crosses the data boundary.** A `PostgrestException` reaching a widget is a
/// review failure."
///
/// Every mapping keeps the original as [AppException.cause] and puts the
/// technical text in [AppException.detail], so nothing is lost for logging while
/// nothing technical is available to display.
abstract final class ErrorMapper {
  /// Maps [error] to the closest [AppException].
  ///
  /// An [AppException] passes through unchanged — mapping twice would replace a
  /// specific message written at a throw site with a generic one.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    return switch (error) {
      supabase.PostgrestException() => _fromPostgrest(error, stackTrace),
      supabase.AuthException() => _fromAuth(error, stackTrace),
      supabase.StorageException() => _fromStorage(error, stackTrace),
      SocketException() => NetworkException(
        detail: error.message,
        cause: error,
        stackTrace: stackTrace,
      ),
      HttpException() => NetworkException(
        detail: error.message,
        cause: error,
        stackTrace: stackTrace,
      ),
      TimeoutException() => NetworkException(
        message: 'That took too long',
        detail: 'request timed out after ${error.duration}',
        cause: error,
        stackTrace: stackTrace,
      ),
      FormatException() => ServerException(
        detail: 'malformed response: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      ),
      _ => _unknown(error, stackTrace),
    };
  }

  /// Postgres and RLS failures.
  ///
  /// The important case is `42501` — an RLS denial. It must become a
  /// [PermissionException] and not a [ServerException], because the two get
  /// different words and only one of them is worth retrying.
  static AppException _fromPostgrest(
    supabase.PostgrestException error,
    StackTrace? stackTrace,
  ) {
    final String? code = error.code;

    return switch (code) {
      // insufficient_privilege — the RLS policy said no.
      '42501' => PermissionException(
        detail: error.message,
        code: code,
        cause: error,
        stackTrace: stackTrace,
      ),
      // PGRST116 — `.single()` matched no rows.
      'PGRST116' => NotFoundException(
        detail: error.message,
        code: code,
        cause: error,
        stackTrace: stackTrace,
      ),
      // 23505 unique_violation, 23514 check_violation, 23503 foreign key.
      // These are the client asking for something the schema forbids, so they
      // are the client's fault rather than the server's.
      '23505' => ValidationException(
        message: 'That already exists',
        detail: error.message,
        code: code,
        cause: error,
        stackTrace: stackTrace,
      ),
      '23514' || '23503' => ValidationException(
        message: "That isn't allowed",
        detail: error.message,
        code: code,
        cause: error,
        stackTrace: stackTrace,
      ),
      _ => ServerException(
        detail: error.message,
        code: code,
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }

  static AppException _fromAuth(
    supabase.AuthException error,
    StackTrace? stackTrace,
  ) {
    final String message = error.message.toLowerCase();

    // Checked before anything else. A 429 arrives as an AuthException like any
    // other, and treating it as a credential failure would tell someone their
    // password was wrong when it was simply too soon to ask again
    // (docs/USER_FLOWS.md §3).
    if (error.statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      final Duration? wait = _retryAfterFrom(error.message);

      return RateLimitException(
        message: wait == null
            ? 'Too many attempts. Give it a moment and try again.'
            : 'Too many attempts. Try again in ${wait.inSeconds} seconds.',
        detail: error.message,
        code: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
        retryAfter: wait,
      );
    }

    // Signing in to an account whose address was never confirmed. Supabase
    // returns its own distinct error for this, and folding it into "those
    // details did not match" tells someone their password is wrong when it is
    // not — they then change a password that was already correct.
    //
    // This does not weaken the enumeration defence in docs/USER_FLOWS.md §3.
    // That defence is about not revealing *which field* was wrong, and it still
    // holds: a wrong password and an unknown address are still one message.
    // Whether an address is registered-but-unconfirmed is already plain in the
    // API response the client receives, so saying it in the UI reveals nothing
    // the caller could not already read.
    if (message.contains('not confirmed') ||
        message.contains('email_not_confirmed')) {
      return AuthFailureException(
        message: 'Confirm your email first — check your inbox for the link',
        detail: error.message,
        code: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final bool isExpired =
        message.contains('expired') ||
        message.contains('jwt') ||
        error.statusCode == '401';

    return AuthFailureException(
      message: isExpired ? 'Please sign in again' : genericAuthFailure,
      detail: error.message,
      code: error.statusCode,
      cause: error,
      stackTrace: stackTrace,
      isSessionExpired: isExpired,
    );
  }

  /// What an auth failure says when nothing more specific is known.
  ///
  /// Public so a caller can tell "we do not know why" apart from a message this
  /// mapper chose deliberately — a rate limit and an unconfirmed address both
  /// get their own wording, and those must survive being handled elsewhere.
  ///
  /// **It is only true on a sign-in.** Sign-up has no details to match, and
  /// showing this there is a sentence that cannot be acted on — see
  /// `AuthController.signUp`, which substitutes its own.
  static const String genericAuthFailure = 'Those details did not match';

  /// The wait from a rate-limit message, when it states one.
  ///
  /// Supabase phrases it as "you can only request this after 21 seconds". The
  /// *number* is worth surfacing — it turns "try later" into something the user
  /// can actually wait out — but the sentence is backend text and never shown,
  /// so only the duration is lifted out of it.
  static Duration? _retryAfterFrom(String message) {
    final RegExpMatch? match = RegExp(
      r'(\d+)\s*second',
      caseSensitive: false,
    ).firstMatch(message);

    final int? seconds = int.tryParse(match?.group(1) ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static AppException _fromStorage(
    supabase.StorageException error,
    StackTrace? stackTrace,
  ) {
    if (error.statusCode == '404') {
      return NotFoundException(
        detail: error.message,
        code: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error.statusCode == '403') {
      return PermissionException(
        detail: error.message,
        code: error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return ServerException(
      message: "We couldn't load that image",
      detail: error.message,
      code: error.statusCode,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// The escape hatch, which is always logged (docs/ARCHITECTURE.md §9).
  ///
  /// An unmapped failure means something is happening that this app has not been
  /// taught to recognise, so the log line is the only chance to learn about it.
  static AppException _unknown(Object error, StackTrace? stackTrace) {
    AppLog.error(
      'Unmapped error reached ErrorMapper',
      error: error,
      stackTrace: stackTrace,
      name: 'ErrorMapper',
    );

    return UnknownException(
      detail: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
