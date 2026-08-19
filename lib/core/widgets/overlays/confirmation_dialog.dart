import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// A confirmation (docs/COMPONENTS.md §10).
///
/// The rule worth reading twice: destructive confirmations **name the
/// consequence** — *"Delete this meal? It will be removed from your history."* —
/// and never ask a bare "Are you sure?". A dialog that does not say what will
/// happen is a dialog people learn to dismiss without reading.
///
/// Actions are stacked full width with the confirm on top, because a row of two
/// equal buttons makes the destructive one as easy to hit as the safe one.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    required this.title,
    required this.confirmLabel,
    this.body,
    this.cancelLabel = 'Cancel',
    this.icon,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String confirmLabel;

  /// What will happen. Required in practice for anything destructive.
  final String? body;
  final String cancelLabel;

  /// An optional glyph in a tinted circle.
  final IconData? icon;

  /// Renders the confirm action as [AppButton.destructive].
  final bool isDestructive;

  /// Shows the dialog and completes true when confirmed.
  ///
  /// Completes false on cancel *and* on barrier dismissal, so a caller never
  /// has to treat null as a third outcome.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? body,
    String cancelLabel = 'Cancel',
    IconData? icon,
    bool isDestructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmationDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final Color tint = isDestructive
        ? colors.error.surface
        : colors.primaryContainer;
    final Color onTint = isDestructive
        ? colors.error.onSurface
        : colors.onPrimaryContainer;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: _iconCircle,
                      child: Center(
                        child: Icon(icon, size: AppIconSize.md, color: onTint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
              ],
              Text(
                title,
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space2),
                Text(
                  body!,
                  style: context.text.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                label: confirmLabel,
                variant: isDestructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                isFullWidth: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpacing.space3),
              AppButton.secondary(
                label: cancelLabel,
                isFullWidth: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _maxWidth = 340;
  static const double _iconCircle = 48;
}
