// Derives the launcher-icon sources from the one brand asset.
//
// Run from the repository root, then regenerate the icons:
//   dart run tool/build_brand_assets.dart
//   dart run flutter_launcher_icons
//
// Three files come out of one. Two of them are launcher-icon sources, because a
// launcher icon is not one image:
//
// * `launcher_foreground.png` — the logo inset inside a transparent square, for
//   Android's adaptive icons. Android masks the outer third of a foreground
//   layer to whatever shape the launcher feels like (circle, squircle, teardrop),
//   so art that fills its canvas gets its edges eaten. The cloche lid and the
//   fork in this logo are exactly the sort of thing that disappears. Insetting
//   first is the only way to keep them.
//
// * `launcher_opaque.png` — the logo flattened onto white, for iOS and for
//   Android's legacy icon. iOS rejects alpha in an app icon outright, and a
//   legacy launcher icon with transparency shows the launcher's own background
//   through the gaps, which looks like a rendering fault rather than a design.
//
// The third is the one the app actually bundles:
//
// * `logo.png` — the mark at [_runtime] px. The master is 1240 px square and over
//   a megabyte, and the largest place it appears is 96 logical pixels; shipping
//   the original would put a megabyte in the APK to draw a thumbnail. Everything
//   under `source/` is a build input and is deliberately **not** declared in
//   pubspec, so none of it reaches the bundle.
//
// Committed outputs rather than a build step: they change when the logo changes,
// which is roughly never, and a generated file nobody can see is a file that
// silently rots.

import 'dart:io';

import 'package:image/image.dart';

/// Android's adaptive-icon safe zone: the middle 66% of the layer is guaranteed
/// visible, and everything outside it is at the launcher's mercy.
const double _safeZone = 0.66;

/// The square each output is written at. 1024 is what iOS wants for the App
/// Store, and it is comfortably above every Android density.
const int _canvas = 1024;

/// The square the bundled asset is written at.
///
/// 512 rather than the master's 1240. The largest use in the app is 96 logical
/// pixels, which is 288 physical on a 3× screen — so this is already more than
/// twice what any device asks for, at a fraction of the file size.
const int _runtime = 512;

/// What the logo sits on where transparency is not allowed.
///
/// White rather than the app background or the logo's own green. This mark was
/// drawn for a light ground — the cloche and the cutlery are white with grey
/// shading, so they read against white and vanish against anything paler than
/// they are; and on the logo's dark green the plate in the middle disappears
/// instead. White is the one choice where every element survives.
const int _opaqueBackground = 0xFFFFFFFF;

void main() {
  final File source = File('assets/brand/source/whats_cooking_logo.png');
  if (!source.existsSync()) {
    stderr.writeln('No logo at ${source.path}.');
    exitCode = 1;
    return;
  }

  final Image? decoded = decodePng(source.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode ${source.path} as a PNG.');
    exitCode = 1;
    return;
  }

  // Trimmed first. The logo arrives with transparent margins of its own, and
  // insetting an already-padded image twice leaves a small mark in a big square —
  // which on a home screen reads as a bug rather than as restraint.
  final Image logo = trim(decoded, mode: TrimMode.transparent);

  _write('assets/brand/source/launcher_foreground.png', _inset(logo, _safeZone));
  _write(
    'assets/brand/source/launcher_opaque.png',
    _flatten(_inset(logo, 0.86), _opaqueBackground),
  );

  // The bundled one. Transparent, because in the app it sits on whichever
  // surface the theme is painting — and cubic because this is the resize anybody
  // will actually look at.
  _write(
    'assets/brand/logo.png',
    copyResize(
      logo,
      width: logo.width >= logo.height ? _runtime : null,
      height: logo.width >= logo.height ? null : _runtime,
      interpolation: Interpolation.cubic,
    ),
  );
}

/// [logo] centred inside a transparent square, occupying [fraction] of it.
Image _inset(Image logo, double fraction) {
  final int target = (_canvas * fraction).round();

  // Scaled by the longer side, so a logo that is not quite square keeps its
  // proportions instead of being stretched into the box.
  final bool isWide = logo.width >= logo.height;
  final Image scaled = copyResize(
    logo,
    width: isWide ? target : null,
    height: isWide ? null : target,
    interpolation: Interpolation.cubic,
  );

  final Image canvas = Image(
    width: _canvas,
    height: _canvas,
    numChannels: 4,
  );

  return compositeImage(
    canvas,
    scaled,
    dstX: ((_canvas - scaled.width) / 2).round(),
    dstY: ((_canvas - scaled.height) / 2).round(),
  );
}

/// [image] over an opaque [colour], with no alpha left.
Image _flatten(Image image, int colour) {
  final Image ground = Image(width: image.width, height: image.height)
    ..clear(ColorUint8.rgba(
      (colour >> 16) & 0xFF,
      (colour >> 8) & 0xFF,
      colour & 0xFF,
      0xFF,
    ));

  return compositeImage(ground, image);
}

void _write(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}
