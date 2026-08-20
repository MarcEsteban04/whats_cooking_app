import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/avatar.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/press_feedback.dart';

/// The screen header from the reference's home screen.
///
/// A greeting on the left with a tappable context line beneath it, and circular
/// actions on the right. The reference puts the *place* on that second line;
/// docs/design_ui.md §8 puts the *household* there — "❤️ Cooking with Princess"
/// or "👤 Just cooking for yourself" — which is the same idea translated: the one
/// piece of context that changes what the app will suggest.
///
/// The context line is tappable, and that matters. It is the entry point to
/// couple mode, which docs/NAVIGATION_MAP.md §3 deliberately keeps off the tab
/// bar: "it is a *context* the whole app operates in, not a destination".
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.greeting,
    required this.context_,
    required this.contextEmoji,
    required this.userName,
    this.avatarUrl,
    this.onContextTap,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.hasUnreadNotifications = false,
    super.key,
  });

  /// "Good evening, Marc" — the line docs/design_ui.md §8 leads with.
  final String greeting;

  /// The context beneath it: who is being cooked for.
  ///
  /// Named with a trailing underscore because `context` is taken by `build`.
  final String context_;

  /// The glyph before the context line.
  final String contextEmoji;

  /// For the avatar's initials fallback.
  final String userName;
  final String? avatarUrl;

  final VoidCallback? onContextTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;

  /// Shows the dot on the bell.
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                greeting,
                style: context.text.headlineLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space1),
              PressFeedback(
                onTap: onContextTap,
                semanticLabel: onContextTap == null
                    ? null
                    : '$context_. Open your kitchen',
                expandTouchTarget: false,
                child: Padding(
                  // Vertical padding rather than a fixed height, so the row keeps
                  // a comfortable target around one line of small text.
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Text(
                          contextEmoji,
                          style: const TextStyle(fontSize: _contextGlyph),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space1),
                      Flexible(
                        child: Text(
                          context_,
                          style: context.text.metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onContextTap != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.space1),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: AppIconSize.xs,
                          color: colors.textTertiary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        if (onNotificationsTap != null)
          _NotificationButton(
            hasUnread: hasUnreadNotifications,
            onTap: onNotificationsTap!,
          ),
        if (onNotificationsTap != null && onAvatarTap != null)
          const SizedBox(width: AppSpacing.space2),
        if (onAvatarTap != null)
          PressFeedback(
            onTap: onAvatarTap,
            semanticLabel: 'Your profile',
            expandTouchTarget: false,
            child: Avatar(
              name: userName,
              imageUrl: avatarUrl,
              size: AvatarSize.small,
            ),
          ),
      ],
    );
  }

  static const double _contextGlyph = 13;
}

/// The bell, with the unread dot the reference draws on it.
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.hasUnread, required this.onTap});

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        AppIconButton(
          icon: AppIcons.notifications,
          semanticLabel: hasUnread
              ? 'Notifications, you have unread'
              : 'Notifications',
          style: AppIconButtonStyle.floating,
          iconSize: AppIconSize.sm,
          visualSize: AvatarSize.small.diameter,
          onPressed: onTap,
        ),
        if (hasUnread)
          Positioned(
            top: _dotInset,
            right: _dotInset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.error.color,
                  shape: BoxShape.circle,
                  // A ring in the surface colour, so the dot reads as sitting on
                  // the button rather than merging with the glyph behind it.
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: const SizedBox.square(dimension: _dotSize),
              ),
            ),
          ),
      ],
    );
  }

  static const double _dotSize = 8;
  static const double _dotInset = 6;
}
