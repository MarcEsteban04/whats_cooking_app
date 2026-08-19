/// The design system's public surface (docs/DESIGN_SYSTEM.md).
///
/// Feature code imports this barrel. It deliberately does **not** export
/// `app_colors.dart`: the raw palette is private to the theme layer, and colours
/// reach a screen only as semantic roles through `context.colors` (§12).
library;

export 'package:whats_cooking/core/theme/app_breakpoints.dart';
export 'package:whats_cooking/core/theme/app_icons.dart';
export 'package:whats_cooking/core/theme/app_motion.dart';
export 'package:whats_cooking/core/theme/app_radius.dart';
export 'package:whats_cooking/core/theme/app_shadows.dart' show AppShadows;
export 'package:whats_cooking/core/theme/app_spacing.dart';
export 'package:whats_cooking/core/theme/app_theme.dart';
export 'package:whats_cooking/core/theme/app_typography.dart'
    show AppTextStyles, AppTypography;
