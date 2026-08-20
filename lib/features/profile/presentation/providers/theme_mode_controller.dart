import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_cooking/core/utils/logger.dart';

part 'theme_mode_controller.g.dart';

/// The appearance setting (docs/USER_FLOWS.md §17: "Appearance → Light, dark,
/// system").
///
/// Stored in `SharedPreferences` rather than in the database, deliberately.
/// Appearance is a property of *this device*: someone with a phone in dark mode
/// and a tablet in light mode wants both, and syncing it would fight them. It is
/// also read before any session exists, so it cannot depend on one.
///
/// Plain preferences are the right store here for the same reason they were the
/// wrong one for session tokens — there is nothing to protect.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    unawaited(_restore());

    // System until the stored value arrives. docs/design_ui.md §1 rules out a
    // dark interface *by default*, not dark mode itself, and following the OS is
    // what a premium app does before it has been told otherwise.
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? stored = preferences.getString(_key);

      if (stored != null) {
        state = _parse(stored);
      }
    } on Object catch (error) {
      // A failed read means the system default, which is a perfectly good
      // outcome. Nothing about appearance is worth surfacing as an error.
      AppLog.debug(
        'Could not read the stored theme mode',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  /// Sets the appearance and remembers it.
  ///
  /// Applied immediately and persisted afterwards, so the tap feels instant even
  /// on a slow write — and a failed write costs the setting next launch rather
  /// than the tap.
  Future<void> set(ThemeMode mode) async {
    state = mode;

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(_key, mode.name);
    } on Object catch (error) {
      AppLog.warning(
        'Could not save the theme mode',
        name: _name,
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  static ThemeMode _parse(String value) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ThemeMode.system;
  }

  static const String _key = 'whats_cooking.appearance';
  static const String _name = 'ThemeModeController';
}

/// The label and description for each appearance option.
extension ThemeModeCopy on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'Match my phone',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String get caption => switch (this) {
    ThemeMode.system => 'Follows your device setting',
    ThemeMode.light => 'Always the warm, light look',
    ThemeMode.dark => 'Always dark',
  };

  /// The glyph beside the option.
  ///
  /// An icon rather than an emoji: the palette is monochrome, and a full-colour
  /// sun sitting in a list of ink-on-white rows is the one thing on the screen
  /// that did not come from the design system.
  IconData get icon => switch (this) {
    ThemeMode.system => Icons.phone_android_rounded,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };
}
