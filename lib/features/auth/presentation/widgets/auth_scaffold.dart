import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/buttons/app_icon_button.dart';
import 'package:whats_cooking/core/widgets/feedback/backend_banner.dart';

/// The layout every auth screen shares, from
/// `docs/reference_design/login_reference.webp`.
///
/// The reference's auth screens are one composition repeated: a circular back
/// button in the top-left, a large **centred** headline, a centred muted
/// subtitle of about two lines, the form, and a centred footer prompt pinned
/// below it. Building that once means the three screens cannot drift apart on
/// spacing or alignment — which is exactly what "make it look the same" fails on
/// first.
///
/// Centred is worth noting: the rest of the app is left-aligned
/// (docs/design_ui.md §8's greeting, §17's section headers). Auth is the
/// exception the reference draws, and it reads as a threshold rather than as a
/// screen inside the app.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.footer,
    this.leading,
    super.key,
  });

  /// The centred headline.
  final String title;

  /// The centred supporting line beneath it.
  final String subtitle;

  /// The form.
  final List<Widget> children;

  /// Null hides the back button — correct for the first screen in the flow.
  final VoidCallback? onBack;

  /// The centred prompt at the foot of the screen.
  final Widget? footer;

  /// Content above the title, for a screen that leads with an illustration.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          // Caps and centres the content on a tablet (docs/DESIGN_SYSTEM.md
          // §10), and leaves a phone unchanged.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  // Scrollable rather than fixed: the keyboard takes roughly
                  // half a small phone's height, and a form that cannot scroll
                  // puts its own submit button behind it.
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.screenMargin,
                    vertical: AppSpacing.space4,
                  ),
                  child: ConstrainedBox(
                    // Fills the viewport, so the footer sits at the bottom of a
                    // tall screen rather than floating under the form.
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0,
                        constraints.maxHeight - (AppSpacing.space4 * 2),
                      ),
                    ),
                    // IntrinsicHeight is what makes the [Spacer] below legal. A
                    // scroll view hands its child an unbounded height, and a
                    // flex child inside an unbounded column is an assertion
                    // failure — so the column is given a definite height first.
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _BackRow(onBack: onBack),
                          // Above the headline, on every auth screen. This is
                          // the one place where "the app has no backend" costs
                          // the user something they cannot get back: an account
                          // they will lose on the next launch.
                          const BackendBanner(),
                          if (leading != null) ...<Widget>[
                            leading!,
                            const SizedBox(height: AppSpacing.space5),
                          ],
                          Text(
                            title,
                            style: context.text.headlineLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            subtitle,
                            style: context.text.bodySmall.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.space7),
                          ...children,
                          if (footer != null) ...<Widget>[
                            // Pushes the footer down when there is room, and
                            // collapses to nothing when there is not.
                            const SizedBox(height: AppSpacing.space7),
                            const Spacer(),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular back button, and the space it occupies when absent.
class _BackRow extends StatelessWidget {
  const _BackRow({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: onBack == null
            // Holds its height either way, so the headline sits at the same
            // point on a screen with a back button and one without.
            ? const SizedBox.shrink()
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: context.shadows.xs,
                ),
                child: AppIconButton(
                  icon: AppIcons.back,
                  semanticLabel: 'Go back',
                  iconSize: AppIconSize.sm,
                  onPressed: onBack,
                ),
              ),
      ),
    );
  }

  static const double _height = AppLayout.minTouchTarget;
}

/// The centred prompt at the foot of an auth screen.
///
/// "Don't have an account? **Sign Up**" — the question muted, the action bold and
/// tappable, on one line.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    required this.question,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String question;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Semantics(
      button: true,
      label: '$question $actionLabel',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onAction,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Padding rather than a fixed height, so the tap target clears 48 px
          // around a single line of text.
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$question ',
                  style: context.text.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: actionLabel,
                  style: context.text.labelSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
