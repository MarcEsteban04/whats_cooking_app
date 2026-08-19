import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';

/// The kinds of failure a screen can show (docs/COMPONENTS.md §13).
///
/// Each carries its own copy, so a screen chooses a *cause* and gets wording
/// written for a person. The alternative — passing a message in at every call
/// site — is how `PostgrestException` ends up on screen.
enum ErrorStateKind {
  network(title: 'No connection', body: 'Check your internet and try again.'),
  server(
    title: 'Something went wrong',
    body: "We couldn't load your meals right now.",
  ),
  notFound(title: "We couldn't find that", body: 'It may have been removed.'),
  permission(
    title: "You don't have access",
    body: 'This belongs to another household.',
  ),
  unknown(title: 'Something went wrong', body: 'Try again in a moment.');

  const ErrorStateKind({required this.title, required this.body});

  final String title;
  final String body;

  IconData get icon => switch (this) {
    ErrorStateKind.network => Icons.wifi_off_rounded,
    ErrorStateKind.notFound => Icons.search_off_rounded,
    ErrorStateKind.permission => Icons.lock_outline_rounded,
    _ => AppIcons.error,
  };
}

/// The "something failed" surface (docs/COMPONENTS.md §13).
///
/// docs/design_ui.md §31 is the governing rule: **never expose technical
/// errors.** The user sees a cause in plain words and a way forward. An
/// [errorCode] may be shown beneath the action for support, deliberately below
/// the fold of attention and never in the primary message.
class ErrorState extends StatelessWidget {
  const ErrorState({
    this.kind = ErrorStateKind.unknown,
    this.title,
    this.body,
    this.onRetry,
    this.onGoBack,
    this.retryLabel = 'Try Again',
    this.errorCode,
    super.key,
  });

  final ErrorStateKind kind;

  /// Overrides [ErrorStateKind.title] where a screen can say something more
  /// specific. Still plain words, never an exception message.
  final String? title;

  /// Overrides [ErrorStateKind.body].
  final String? body;

  final VoidCallback? onRetry;

  /// Shown only where a back path exists.
  final VoidCallback? onGoBack;
  final String retryLabel;

  /// For support, not for the user. Rendered in `bodySmall` on `textDisabled`
  /// beneath the action.
  final String? errorCode;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.screenMargin,
          vertical: AppSpacing.space9,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              kind.icon,
              size: AppIconSize.xl,
              // 60% opacity: present, but not alarming. An error state is
              // already the whole screen; a full-strength red icon on top of
              // that reads as a crash.
              color: colors.error.color.withValues(alpha: _iconOpacity),
            ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              title ?? kind.title,
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
              child: Text(
                body ?? kind.body,
                style: context.text.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space6),
              AppButton.primary(
                label: retryLabel,
                size: AppButtonSize.medium,
                onPressed: onRetry,
              ),
            ],
            if (onGoBack != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              AppButton.tertiary(label: 'Go back', onPressed: onGoBack),
            ],
            if (errorCode != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space4),
              Text(
                errorCode!,
                style: context.text.bodySmall.copyWith(
                  color: colors.textDisabled,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const double _iconOpacity = 0.6;
  static const double _bodyMaxWidth = 280;
}

/// A non-blocking failure (docs/COMPONENTS.md §13).
///
/// For the failures that should not take over the screen — a favourite that did
/// not save, a background refresh that failed. Slides in over `durationNormal`.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.error.surface,
          borderRadius: AppRadius.borderMd,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  AppIcons.error,
                  size: AppIconSize.sm,
                  color: colors.error.onSurface,
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text(
                    message,
                    style: context.text.bodySmall.copyWith(
                      color: colors.error.onSurface,
                    ),
                    maxLines: 2,
                  ),
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.space2),
                  AppButton.tertiary(
                    label: 'Retry',
                    size: AppButtonSize.small,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _height = 48;
}
