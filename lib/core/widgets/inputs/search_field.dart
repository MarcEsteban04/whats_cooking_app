import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';

/// The search input (docs/COMPONENTS.md §2, docs/design_ui.md §9).
///
/// A variant of the text field rather than a separate concept, but different
/// enough in shape to be its own widget: fully rounded, `surfaceMuted`, no
/// border, and a leading search glyph.
///
/// Input is debounced at [debounce] so typing "adobo" issues one query rather
/// than five. [onChanged] fires immediately for local state; [onSearch] fires
/// after the pause and is what should reach a repository.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.onSearch,
    this.controller,
    this.hint = 'Search meals, ingredients, or cuisines',
    this.onChanged,
    this.autofocus = false,
    this.debounce = _defaultDebounce,
    this.focusNode,
    super.key,
  });

  /// Called after the user stops typing for [debounce].
  final ValueChanged<String> onSearch;

  final TextEditingController? controller;
  final String hint;

  /// Called on every keystroke, undebounced.
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Duration debounce;
  final FocusNode? focusNode;

  static const Duration _defaultDebounce = Duration(milliseconds: 300);

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  bool _ownsController = false;
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    // Cancelled explicitly: a timer that fires after dispose calls setState on
    // a dead State, which is the classic debounce leak.
    _debounceTimer?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);

    final bool hasText = value.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onSearch(value));
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() => _hasText = false);
    // Clearing is an explicit action, so it searches at once rather than after
    // the debounce: the user is waiting for the unfiltered list to come back.
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.borderFull,
        boxShadow: context.shadows.xs,
      ),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        style: context.text.bodyMedium,
        cursorColor: colors.primary,
        onChanged: _onChanged,
        onSubmitted: (String value) {
          _debounceTimer?.cancel();
          widget.onSearch(value);
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: false,
          // The rounded container above draws the surface; Material's own
          // borders would show as a second, squarer outline inside it.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          prefixIcon: Icon(
            AppIcons.search,
            size: AppIconSize.sm,
            color: colors.textTertiary,
          ),
          suffixIcon: _hasText
              ? AppIconButton(
                  icon: AppIcons.clear,
                  semanticLabel: 'Clear search',
                  iconSize: AppIconSize.sm,
                  onPressed: _clear,
                )
              : null,
        ),
      ),
    );
  }
}
