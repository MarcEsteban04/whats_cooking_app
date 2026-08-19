#!/usr/bin/env bash
#
# Re-verifies every contrast ratio quoted in docs/DESIGN_SYSTEM.md §2 against the
# palette as it actually stands. §11 requires this after any palette change.
#
# The ratios are computed in Dart from the real token values rather than in shell,
# so this is a thin wrapper around the test that owns them.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Verifying WCAG contrast ratios against docs/DESIGN_SYSTEM.md §2..."
flutter test test/core/theme/contrast_test.dart
