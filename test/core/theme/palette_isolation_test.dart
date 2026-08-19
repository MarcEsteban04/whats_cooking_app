import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the design system's one structural rule.
///
/// docs/DESIGN_SYSTEM.md §12: "Raw palette constants are private to the theme
/// layer. A feature file that imports `app_colors.dart` directly is a review
/// failure." Dart has no package-private visibility, so the rule cannot be
/// expressed in the type system — but it can be tested, which means it holds
/// whether or not a reviewer is paying attention on the day.
void main() {
  /// The one directory allowed to name raw colours.
  const String themeLayer = 'lib/core/theme';

  List<File> dartFilesUnder(String path) {
    final Directory directory = Directory(path);
    if (!directory.existsSync()) {
      return <File>[];
    }
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where(
          (File file) =>
              !file.path.endsWith('.g.dart') &&
              !file.path.endsWith('.freezed.dart'),
        )
        .toList();
  }

  /// Every Dart file in `lib/` that is not part of the theme layer.
  List<File> filesOutsideThemeLayer() {
    final String normalisedThemeLayer = themeLayer.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    return dartFilesUnder('lib')
        .where((File file) => !file.path.contains(normalisedThemeLayer))
        .toList();
  }

  test('nothing outside the theme layer imports the raw palette', () {
    final List<String> offenders = <String>[];

    for (final File file in filesOutsideThemeLayer()) {
      if (file.readAsStringSync().contains('theme/app_colors.dart')) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files import the raw palette. Read the semantic role through '
          'context.colors instead (docs/DESIGN_SYSTEM.md §12): $offenders',
    );
  });

  test('no Material colour constants are used outside the theme layer', () {
    // The Sprint 07 checklist: "no Colors.* outside the theme layer". Material's
    // greys have no warmth and would show as a cold patch in a warm palette.
    final List<String> offenders = <String>[];
    final RegExp materialColors = RegExp(r'\bColors\.\w+');

    for (final File file in filesOutsideThemeLayer()) {
      if (materialColors.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files reference Material colour constants directly: $offenders',
    );
  });

  test('no colour literals are declared outside the theme layer', () {
    final List<String> offenders = <String>[];
    final RegExp colorLiteral = RegExp(r'Color\(0x');

    for (final File file in filesOutsideThemeLayer()) {
      if (colorLiteral.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These files declare a colour literal: $offenders',
    );
  });
}
