/// The shared component library (docs/COMPONENTS.md).
///
/// Feature code imports this barrel. docs/design_ui.md §40 requires reusable
/// widgets rather than UI written inline in screens, and a single import is what
/// makes reaching for the shared component easier than writing a local one.
library;

export 'package:whats_cooking/core/widgets/app_badge.dart';
export 'package:whats_cooking/core/widgets/avatar.dart';
export 'package:whats_cooking/core/widgets/buttons/app_button.dart';
export 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
export 'package:whats_cooking/core/widgets/cards/app_card.dart';
export 'package:whats_cooking/core/widgets/cards/category_card.dart';
export 'package:whats_cooking/core/widgets/cards/icon_list_row.dart';
export 'package:whats_cooking/core/widgets/cards/meal_card.dart';
export 'package:whats_cooking/core/widgets/cards/stat_card.dart';
export 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
export 'package:whats_cooking/core/widgets/chips/cuisine_chip.dart';
export 'package:whats_cooking/core/widgets/chips/metadata_pill.dart';
export 'package:whats_cooking/core/widgets/feedback/app_skeleton.dart';
export 'package:whats_cooking/core/widgets/feedback/empty_state.dart';
export 'package:whats_cooking/core/widgets/feedback/error_state.dart';
export 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
export 'package:whats_cooking/core/widgets/inputs/app_toggle.dart';
export 'package:whats_cooking/core/widgets/inputs/search_field.dart';
export 'package:whats_cooking/core/widgets/navigation/app_bottom_nav.dart';
export 'package:whats_cooking/core/widgets/navigation/app_header.dart';
export 'package:whats_cooking/core/widgets/overlays/app_bottom_sheet.dart';
export 'package:whats_cooking/core/widgets/overlays/confirmation_dialog.dart';
export 'package:whats_cooking/core/widgets/placeholder_screen.dart';
export 'package:whats_cooking/core/widgets/preferences/selectable_tile.dart';
export 'package:whats_cooking/core/widgets/press_feedback.dart';
export 'package:whats_cooking/core/widgets/section_header.dart';
