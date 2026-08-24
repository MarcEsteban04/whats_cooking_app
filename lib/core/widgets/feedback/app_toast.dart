import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/app_colors.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// What kind of thing happened (Sprint 57).
enum ToastTone {
  /// It worked. A tick, and the palette's success green.
  success,

  /// It did not. A warning glyph, and the palette's error tone.
  failure,

  /// Neither — a statement of fact. Ink, like everything else in the app.
  neutral,
}

/// One thing to tell somebody.
@immutable
class ToastMessage {
  const ToastMessage({
    required this.text,
    required this.tone,
    required this.serial,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final ToastTone tone;

  /// Distinguishes two identical messages.
  ///
  /// Without it, ticking two items off a list in a row would show one pill and
  /// then nothing — the notifier would see an equal value and not rebuild, so the
  /// second confirmation would silently be the first one still on screen.
  final int serial;

  /// An offer, not a requirement. Null for the great majority.
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction => actionLabel != null && onAction != null;
}

/// The app's confirmations, at the top of the screen (Sprint 57).
///
/// **It replaces `ScaffoldMessenger`, and the reason is a collision rather than a
/// preference.** The theme sets `SnackBarBehavior.floating` and the shell runs
/// `extendBody` under a floating navigation capsule — so every confirmation in
/// this app was surfacing in the same eighty pixels as the primary navigation,
/// either sitting on the capsule or shouldering it aside. Two things were
/// competing for one place, and one of them is how you move around the app.
///
/// **Success and failure no longer look identical.** They did: "6 things came out
/// of the kitchen" and "That could not be saved" were the same grey rectangle,
/// which made the palette's success and error tones the two colours nothing used.
/// A glyph carries the difference as well as the colour, because
/// docs/DESIGN_SYSTEM.md §11 forbids colour meaning something on its own.
///
/// **No `BuildContext`.** Deliberately, and it fixes a real class of bug: several
/// callers pop a sheet and *then* confirm, so the context they were holding is on
/// its way out of the tree. The pill is owned by [ToastHost], installed once
/// inside `MaterialApp.builder`, so a caller only has to have something to say.
///
/// One at a time. A queue would mean somebody who ticks six things off a list
/// waits eighteen seconds to be told about the sixth — the last thing you did is
/// the only one worth reading, so a new message replaces the one on screen.
class AppToast {
  AppToast._();

  /// What [ToastHost] is watching. Null means nothing on screen.
  static final ValueNotifier<ToastMessage?> current =
      ValueNotifier<ToastMessage?>(null);

  static int _serial = 0;

  /// It worked.
  static void success(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    text,
    tone: ToastTone.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// It did not.
  static void failure(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    text,
    tone: ToastTone.failure,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// A statement of fact, neither good nor bad.
  static void say(String text, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        text,
        tone: ToastTone.neutral,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void show(
    String text, {
    ToastTone tone = ToastTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    current.value = ToastMessage(
      text: trimmed,
      tone: tone,
      serial: ++_serial,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Takes it off screen early.
  static void dismiss() => current.value = null;

  /// How long a message stays.
  ///
  /// Long enough to read two lines, and a little longer when there is something
  /// to tap: an offer nobody had time to accept is worse than no offer.
  static Duration lifetimeOf(ToastMessage message) => message.hasAction
      ? const Duration(seconds: 5)
      : const Duration(seconds: 3);
}

/// Holds the pill above every route.
///
/// Installed once, in `MaterialApp.builder`, which puts it below the theme and
/// the media query and *above* the router's navigator — so it sits over full
/// screen routes, sheets and dialogs alike, and no screen has to know it exists.
class ToastHost extends StatelessWidget {
  const ToastHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // `Positioned.fill` rather than a bare child. A non-positioned child in a
        // `Stack` is laid out with *loosened* constraints, so the whole app would
        // be sized by what it happens to want rather than by the window — which
        // is the sort of thing that looks fine until one screen has an unbounded
        // scroll view in it.
        Positioned.fill(child: child),

        // Not wrapped in `IgnorePointer` as a whole: the pill has a dismiss
        // gesture and sometimes an action. When there is nothing to show the
        // layer is a `SizedBox.shrink`, so it takes no hits either way.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            // Bottom excluded: this is a top layer, and letting it reserve the
            // bottom inset would push the pill down by the height of the home
            // indicator for no reason.
            bottom: false,
            child: _ToastLayer(),
          ),
        ),
      ],
    );
  }
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer();

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: AppMotion.normal,
    reverseDuration: AppMotion.fast,
    vsync: this,
  );

  /// What is on screen, which lags [AppToast.current] on the way out: the pill
  /// has to stay built while it animates away.
  ToastMessage? _showing;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AppToast.current.addListener(_onChanged);

    // Not `_onChanged()`, which calls `setState` — an assertion failure during
    // `initState`. In practice the notifier is empty when the app mounts, since
    // nothing has had a chance to say anything; a hot reload can rebuild this
    // layer while a pill is up, and that must not throw either.
    if (AppToast.current.value case final ToastMessage waiting) {
      _showing = waiting;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    AppToast.current.removeListener(_onChanged);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _timer?.cancel();
    final ToastMessage? next = AppToast.current.value;

    if (next == null) {
      // **Cleared once it is actually gone, not when it is asked to go.** An
      // `Opacity` of zero still hit-tests, so a pill left in the tree after
      // fading out would go on swallowing every tap across the top of the screen
      // — invisibly, and for the rest of the session.
      unawaited(
        _controller.reverse().then((_) {
          // Only if nothing new arrived while it was leaving.
          if (mounted && AppToast.current.value == null) {
            setState(() => _showing = null);
          }
        }),
      );
      return;
    }

    setState(() => _showing = next);

    // Restarted from zero rather than continued, so a replacement reads as a new
    // message instead of the old one silently changing its words.
    _controller
      ..value = 0
      ..forward();

    _timer = Timer(AppToast.lifetimeOf(next), () {
      // Only if it is still this one. A message replaced before its timer fired
      // must not take its successor down with it.
      if (AppToast.current.value?.serial == next.serial) {
        AppToast.dismiss();
      }
    });

    // No haptic here, deliberately. Every caller that wants one already fires it
    // at the moment of the action — ticking an item off a list buzzes before the
    // request goes out — and a second buzz when the confirmation lands would make
    // one tap feel like two.
  }

  @override
  Widget build(BuildContext context) {
    if (_showing case final ToastMessage message) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeOutCubic.transform(_controller.value);

          return IgnorePointer(
            // Deaf while it is leaving. The clear-on-complete above stops it
            // eating taps *afterwards*; this stops it eating one during the
            // hundred and fifty milliseconds it spends on the way out, which is
            // long enough for a thumb already moving to land on nothing.
            ignoring: _controller.status == AnimationStatus.reverse,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                // Slides down from just above its resting place. A short travel:
                // the pill appears near the top of the screen either way, and a
                // long slide turns a confirmation into an animation.
                offset: Offset(0, (t - 1) * _slide),
                // And grows the last few per cent into place. This is the whole
                // difference between a rectangle appearing and an object
                // arriving — and it is deliberately small, because a pill that
                // bounces is a pill somebody watches instead of reads.
                child: Transform.scale(
                  scale: _minScale + ((1 - _minScale) * t),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: _Pill(message: message),
      );
    }

    return const SizedBox.shrink();
  }

  static const double _slide = 24;

  /// Where the grow starts. Small on purpose — see the builder.
  static const double _minScale = 0.94;
}

/// The island itself.
///
/// **Dark in both themes, and that is the correction.** The first version used
/// `surfaceInverse`, which is the right token for "the opposite of the page" and
/// the wrong one for this: in the dark theme it resolves to near-white, so the
/// pill landed as a glaring white slab over a black screen. A notification is not
/// an inversion of the page, it is an object *above* it — and the thing this was
/// modelled on is darker than what it floats over, in every wallpaper.
///
/// So the ground is ink at both ends, with a hairline in the dark theme to lift
/// it off a background of nearly the same value, and a real shadow rather than a
/// polite one. That reads as a layer instead of a rectangle.
///
/// **The tone lives in a filled disc with the glyph knocked out of it**, which is
/// the app's own vocabulary — `ConfirmationDialog`'s tinted circle,
/// `DashboardActionRow`'s filled square. A bare coloured glyph on ink was the
/// weakest possible version: at 16 px, a mid-green tick and an amber warning read
/// as the same grey mark, so the one thing the pill exists to distinguish was the
/// thing you could not see.
class _Pill extends StatelessWidget {
  const _Pill({required this.message});

  final ToastMessage message;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final (IconData icon, Color disc, Color onDisc) = switch (message.tone) {
      ToastTone.success => (
        AppIcons.check,
        colors.success.color,
        colors.success.onColor,
      ),
      ToastTone.failure => (
        AppIcons.warning,
        colors.error.color,
        colors.error.onColor,
      ),
      // No disc for a plain statement — see `_Disc`. The colours are still
      // passed so the switch stays exhaustive over one shape.
      ToastTone.neutral => (
        AppIcons.info,
        colors.outlineStrong,
        _onInk(isDark),
      ),
    };

    return Padding
    // Clear of the status bar, and inset from the edges rather than flush: an
    // object that touches both sides of the screen is a banner, and a banner is
    // part of the page.
    (
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: Semantics(
            liveRegion: true,
            container: true,
            // **A real `Material`, and it fixes two things that looked like
            // design problems.**
            //
            // This layer hangs off `MaterialApp.builder`, so it is under the
            // theme but under no `Material` — and a `Text` there merges its
            // style with `WidgetsApp`'s fallback `DefaultTextStyle`, which
            // carries a **double yellow underline**. Every message in the app was
            // being drawn with it, because none of the typography sets
            // `decoration` and a null field is what `merge` fills in.
            //
            // The action's `InkWell` had the same root cause from the other end:
            // no `Material` ancestor means no ink, so the one tappable thing in
            // here gave no feedback at all.
            child: Material(
              color: _ink(isDark),
              elevation: 0,
              borderRadius: AppRadius.borderFull,
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.borderFull,
                  border: isDark
                      // Only in the dark theme. On a pale page the shadow does
                      // the separating; on a dark one there is barely a value
                      // difference to shadow *against*, and the hairline is what
                      // stops the pill dissolving into the background.
                      ? Border.all(color: colors.outlineStrong)
                      : null,
                ),
                child: GestureDetector(
                  // Tap anywhere that is not the action to send it away. Swipe up
                  // too, because that is the direction it came from and the
                  // gesture people try on anything at the top of a screen.
                  onTap: AppToast.dismiss,
                  onVerticalDragEnd: (DragEndDetails details) {
                    if ((details.primaryVelocity ?? 0) < 0) {
                      AppToast.dismiss();
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.space2,
                      AppSpacing.space2,
                      // Tighter on the right when an action is carried: the
                      // label has padding of its own, and both would put an
                      // unbalanced gap after the last word.
                      message.hasAction ? AppSpacing.space1 : AppSpacing.space4,
                      AppSpacing.space2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _Disc(
                          icon: icon,
                          background: disc,
                          foreground: onDisc,
                          isOutlineOnly: message.tone == ToastTone.neutral,
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Flexible(
                          child: Text(
                            message.text,
                            style: context.text.titleSmall.copyWith(
                              color: _onInk(isDark),
                              // Belt and braces on top of the `Material` above.
                              // The one thing this widget must never do is
                              // decorate its own text.
                              decoration: TextDecoration.none,
                            ),
                            // Two lines. Every message in this app fits inside
                            // that, and a third would make the pill a panel.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (message.hasAction) ...<Widget>[
                          const SizedBox(width: AppSpacing.space2),
                          _Action(message: message, isDark: isDark),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The ground. Ink at both ends of the theme — see the class doc.
  static Color _ink(bool isDark) =>
      isDark ? AppColors.darkSurfaceHigh : AppColors.neutral900;

  /// What reads on [_ink].
  static Color _onInk(bool isDark) =>
      isDark ? AppColors.darkTextPrimary : AppColors.neutral50;
}

/// The tone, as a filled circle with the glyph knocked out.
///
/// Filled for success and failure, because those are the two the reader has to
/// tell apart at a glance and a solid disc of colour does it before the glyph is
/// even resolved. Outlined for a plain statement, which is not news and should not
/// arrive wearing a colour.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.isOutlineOnly,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final bool isOutlineOnly;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOutlineOnly ? Colors.transparent : background,
        shape: BoxShape.circle,
        border: isOutlineOnly ? Border.all(color: background) : null,
      ),
      child: SizedBox.square(
        dimension: _size,
        child: Center(
          child: Icon(
            icon,
            size: _glyph,
            color: isOutlineOnly ? background : foreground,
          ),
        ),
      ),
    );
  }

  static const double _size = 26;
  static const double _glyph = 16;
}

/// The offer on the right, when there is one.
class _Action extends StatelessWidget {
  const _Action({required this.message, required this.isDark});

  final ToastMessage message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return InkWell(
      onTap: () {
        // Taken down first, so the screen underneath is not changing behind a
        // pill still offering to change it.
        AppToast.dismiss();
        message.onAction?.call();
      },
      borderRadius: AppRadius.borderFull,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        child: Text(
          message.actionLabel!.toUpperCase(),
          style: context.text.overline.copyWith(
            // The one place the accent is allowed in here: it is a button inside
            // a notification and has to look like one at a glance. Read on ink at
            // both ends of the theme, which the terracotta does — it is the same
            // relationship SPIN has with the pale page.
            color: colors.primaryBrand,
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}
