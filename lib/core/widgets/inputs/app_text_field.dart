import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';

/// The application's text input (docs/COMPONENTS.md §2).
///
/// Two rules from the spec shape the whole widget:
///
/// **Validation fires on blur, not on every keystroke.** Errors while typing are
/// hostile — a required-field message appearing after the first character tells
/// the user they are wrong before they have finished being right.
///
/// **The error replaces the helper text in place.** Both are rendered into a
/// reserved line, so a field that gains an error does not push the rest of the
/// form down. Wrapping the input in a `Column` with the label above and the
/// helper below is why this does not use Material's floating label.
class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.isObscured = false,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    super.key,
  });

  final TextEditingController? controller;

  /// Rendered above the field in `labelSmall`, per §2 — not as a floating label.
  final String? label;
  final String? hint;

  /// Guidance shown beneath the field until an error replaces it.
  final String? helperText;

  /// An externally supplied error, from form-level or server-side validation.
  final String? errorText;

  /// Run on blur and on submit. Returns null when valid.
  final String? Function(String value)? validator;

  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  /// Whether this is a password field. Adds the visibility toggle from §2.
  final bool isObscured;
  final bool isEnabled;
  final bool isReadOnly;
  final bool autofocus;

  /// Multi-line grows from one line up to this many, then scrolls internally.
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;

  /// A trailing widget. Ignored when [isObscured], which supplies its own.
  final Widget? suffix;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _isObscured = true;
  String? _validationError;

  /// An external error wins over a local one: it usually came from the server
  /// and is the more specific of the two.
  String? get _effectiveError => widget.errorText ?? _validationError;

  bool get _hasError => _effectiveError != null;

  @override
  void initState() {
    super.initState();

    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _ownsController = widget.controller == null;

    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Clear on focus so a corrected field stops shouting while it is being
      // corrected. It will be re-validated on the way out.
      if (_validationError != null) {
        setState(() => _validationError = null);
      }
      return;
    }
    _validate();
  }

  void _validate() {
    final String? Function(String value)? validator = widget.validator;
    if (validator == null) {
      return;
    }

    final String? error = validator(_controller.text);
    if (error != _validationError) {
      setState(() => _validationError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final AppTextStyles text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: text.labelSmall.copyWith(
              color: widget.isEnabled
                  ? colors.textSecondary
                  : colors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.isEnabled,
          readOnly: widget.isReadOnly,
          autofocus: widget.autofocus,
          obscureText: widget.isObscured && _isObscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.isObscured ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          style: text.bodyMedium,
          cursorColor: colors.primary,
          onChanged: widget.onChanged,
          onSubmitted: (String value) {
            _validate();
            widget.onSubmitted?.call(value);
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            // The reserved line below carries helper and error text, so
            // Material's own must be suppressed or the field grows twice.
            helperText: null,
            errorText: null,
            counterText: '',
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: AppIconSize.sm,
                    color: colors.textTertiary,
                  ),
            suffixIcon: _buildSuffix(),
            // The theme supplies every border; only the error state has to be
            // selected here, because the widget owns the validation timing.
            border: _hasError ? _errorBorder(colors) : null,
            enabledBorder: _hasError ? _errorBorder(colors) : null,
            focusedBorder: _hasError ? _errorBorder(colors) : null,
          ),
        ),
        _HelperLine(
          helperText: widget.helperText,
          errorText: _effectiveError,
          // Reserve the line for any field that could ever show a message.
          // Reserving only once a helper exists would still let a validated
          // field without helper text shove the form down on first error.
          isReserved:
              widget.helperText != null ||
              widget.errorText != null ||
              widget.validator != null,
        ),
      ],
    );
  }

  Widget? _buildSuffix() {
    if (widget.isObscured) {
      return AppIconButton(
        icon: _isObscured
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        semanticLabel: _isObscured ? 'Show password' : 'Hide password',
        iconSize: AppIconSize.sm,
        onPressed: () => setState(() => _isObscured = !_isObscured),
      );
    }
    return widget.suffix;
  }

  OutlineInputBorder _errorBorder(AppColorScheme colors) {
    return OutlineInputBorder(
      borderRadius: AppRadius.borderMd,
      borderSide: BorderSide(color: colors.error.color, width: 2),
    );
  }
}

/// The line beneath a field, carrying helper text or an error in its place.
///
/// When [isReserved] it holds its height even while empty, so a field that gains
/// an error does not push the rest of the form down — the whole point of §2's
/// rule. The height scales with the text scale rather than being hard-coded, or
/// the reservation would be wrong at 1.3x, which is exactly when a two-line
/// error is most likely.
class _HelperLine extends StatelessWidget {
  const _HelperLine({
    required this.helperText,
    required this.errorText,
    required this.isReserved,
  });

  final String? helperText;
  final String? errorText;
  final bool isReserved;

  @override
  Widget build(BuildContext context) {
    final String? message = errorText ?? helperText;
    final AppColorScheme colors = context.colors;
    final TextStyle style = context.text.bodySmall;

    if (message == null) {
      if (!isReserved) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        height:
            _gap +
            MediaQuery.textScalerOf(context)
                .scale(style.fontSize! * style.height!),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: _gap, left: AppSpacing.space1),
      child: Text(
        message,
        style: style.copyWith(
          color: errorText != null ? colors.error.color : colors.textTertiary,
        ),
        maxLines: 2,
      ),
    );
  }

  static const double _gap = 6;
}
