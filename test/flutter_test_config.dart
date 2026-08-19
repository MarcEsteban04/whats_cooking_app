import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Applies to every test under `test/` (Flutter picks this file up by name).
///
/// Inter is loaded by `google_fonts`, which fetches it over HTTP on first use.
/// A test suite must not depend on the network, and the metrics under test are
/// ours rather than the font's, so runtime fetching is switched off once here
/// instead of in a `setUpAll` in every file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
