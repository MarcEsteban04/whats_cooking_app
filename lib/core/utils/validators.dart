/// Form validation, shared across auth, onboarding and profile.
///
/// Every validator returns null when the value is acceptable and a message
/// written for a person otherwise — the shape `AppTextField.validator` takes.
///
/// docs/USER_FLOWS.md §2: "Validation is inline and immediate. No error is
/// deferred to submit time when it could have been shown on blur." So these run
/// on blur, and the messages are written to be read mid-form rather than as a
/// list of complaints after submitting.
abstract final class Validators {
  /// Minimum password length.
  ///
  /// Eight, matching Supabase Auth's own default. A client rule stricter than
  /// the server's is a rule the server will not enforce on a password set any
  /// other way; a looser one produces a server rejection the user could have
  /// been warned about.
  static const int minPasswordLength = 8;

  /// Maximum display-name length, matching `profiles.display_name`.
  static const int maxNameLength = 60;

  /// A deliberately permissive email shape.
  ///
  /// Something, an `@`, something with a dot in it. Not RFC 5322: a stricter
  /// pattern rejects valid addresses — plus-addressing, new TLDs, unicode
  /// domains — and the only authority on whether an address exists is whether
  /// the mail arrives. This catches the typo, and the confirmation email does
  /// the rest.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Validates an email address.
  static String? email(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Enter your email';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return "That doesn't look like an email address";
    }
    return null;
  }

  /// Validates a password being *set*.
  ///
  /// Length only. Composition rules — a digit, a symbol, mixed case — push people
  /// toward `Password1!` and away from a long passphrase, so they cost real
  /// security to buy the appearance of it.
  static String? newPassword(String value) {
    if (value.isEmpty) {
      return 'Choose a password';
    }
    if (value.length < minPasswordLength) {
      return 'At least $minPasswordLength characters';
    }
    return null;
  }

  /// Validates a password being *entered* to sign in.
  ///
  /// Presence only. Applying the length rule here would tell someone their
  /// existing password is invalid, and would leak that this app's minimum is
  /// eight to anyone probing the form.
  static String? existingPassword(String value) {
    return value.isEmpty ? 'Enter your password' : null;
  }

  /// Validates a password confirmation against [original].
  static String? Function(String) passwordConfirmation(String original) {
    return (String value) {
      if (value.isEmpty) {
        return 'Repeat your password';
      }
      if (value != original) {
        return "Those don't match";
      }
      return null;
    };
  }

  /// Validates a display name.
  static String? displayName(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Enter your name';
    }
    if (trimmed.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
    return null;
  }

  /// Validates a budget in whole pesos, within [min] and [max].
  static String? Function(String) budget({required int min, required int max}) {
    return (String value) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return 'Enter a budget';
      }

      final int? amount = int.tryParse(trimmed);
      if (amount == null) {
        return 'Numbers only';
      }
      if (amount < min) {
        return 'At least $min';
      }
      if (amount > max) {
        return 'At most $max';
      }
      return null;
    };
  }
}
