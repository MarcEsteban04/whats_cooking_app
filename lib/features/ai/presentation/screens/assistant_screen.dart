import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/config/app_env.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/core/widgets/inputs/app_text_field.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';

/// Asking the app in words (Sprint 47).
///
/// **Not streaming, and that is a decision rather than a shortcut.** The roadmap
/// asked for "streaming where the provider supports it", and building it would
/// break the thing that makes the AI work at all: `ai-assistant` tries three
/// providers in turn, and once the first has sent tokens to this screen, failing
/// over means either abandoning a half-written answer in front of the reader or
/// splicing two models' prose together. A four-second wait for a whole answer beats
/// a fast answer that sometimes falls apart mid-sentence.
///
/// So the waiting state has to be good instead. It says what is happening, keeps
/// the question on screen, and leaves the conversation readable.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantConversation conversation = ref.watch(
      assistantControllerProvider,
    );

    // Scrolled after the frame that added the message, because the extent it needs
    // does not exist until the new bubble has been laid out.
    ref.listen(assistantControllerProvider, (
      AssistantConversation? _,
      AssistantConversation next,
    ) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Ask'),
        actions: <Widget>[
          if (!conversation.isEmpty)
            IconButton(
              icon: const Icon(AppIcons.refresh),
              tooltip: 'Start again',
              onPressed: () {
                ref.read(assistantControllerProvider.notifier).clear();
                _input.clear();
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: conversation.isEmpty
                      ? _Opening(onPick: _send)
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            AppLayout.screenMargin,
                            AppSpacing.space4,
                            AppLayout.screenMargin,
                            AppSpacing.space4,
                          ),
                          children: <Widget>[
                            for (final AssistantMessage message
                                in conversation.messages)
                              _Bubble(message: message),

                            if (conversation.isThinking) const _Thinking(),

                            if (conversation.failure case final AppException e)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.space3,
                                ),
                                child: InlineErrorBanner(
                                  // The Edge Function writes these sentences —
                                  // "you have asked a lot in the last hour, try
                                  // again in about 40 minutes" — so this shows
                                  // theirs rather than inventing a second wording.
                                  message: e.displayMessage ?? e.message,
                                  onRetry: ref
                                      .read(assistantControllerProvider.notifier)
                                      .retry,
                                ),
                              ),
                          ],
                        ),
                ),
                _Composer(
                  controller: _input,
                  isBusy: conversation.isThinking,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _send(String question) {
    if (question.trim().isEmpty) {
      return;
    }
    _input.clear();
    AppHaptics.reelTick();
    ref.read(assistantControllerProvider.notifier).ask(question);
  }

  void _toBottom() {
    if (!_scroll.hasClients) {
      return;
    }
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: AppMotion.resolve(context, AppMotion.normal),
      curve: AppMotion.curveNormal,
    );
  }
}

/// The empty state, and it is doing real work.
///
/// **Suggestions rather than a blank box.** Nobody knows what to type into an
/// assistant they have not used, and "how can I help?" over an empty screen is a
/// question that gets closed rather than answered. These four are the things the
/// app can genuinely answer well, because they are the four it has context for —
/// the pantry, the budget, what was eaten lately, and the library.
class _Opening extends StatelessWidget {
  const _Opening({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppLayout.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            AppIcons.assistant,
            size: AppIconSize.xl,
            color: context.colors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'Ask about dinner',
            style: context.text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            // Says what it already knows, because an assistant that has to be told
            // the budget every time is a slower way of using the filter sheet.
            'It already knows what is in your kitchen, what you avoid, and what '
            'you have eaten lately.',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              for (final String prompt in _prompts)
                AppFilterChip(
                  label: prompt,
                  isSelected: false,
                  onSelected: (_) => onPick(prompt),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<String> _prompts = <String>[
    'What can we cook tonight?',
    'Something quick and cheap',
    'What should I use up first?',
    'Something different from this week',
  ];
}

/// One turn.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFraction,
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  // The question inverts to ink and the answer stays on a card.
                  // The palette has one accent and it belongs to SPIN, so the
                  // loudest thing available for "this is you talking" is black
                  // (docs/DESIGN_SYSTEM.md §2.2).
                  color: isUser ? colors.surfaceInverse : colors.surface,
                  borderRadius: AppRadius.borderXl,
                  boxShadow: isUser ? null : context.shadows.sm,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  child: Text(
                    message.content,
                    style: context.text.bodyMedium.copyWith(
                      color: isUser ? colors.textOnInverse : null,
                    ),
                  ),
                ),
              ),
              // Which provider answered, in development only. Not a secret —
              // `ai-assistant` returns it deliberately — but it is a developer's
              // fact, and a release build should not put "groq" under a recipe.
              if (!isUser && AppEnv.isVerboseLogging)
                if (message.provider case final String provider)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.space1,
                      left: AppSpacing.space2,
                    ),
                    child: Text(provider, style: context.text.metadata),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// Not the full width. A bubble that reaches both edges stops reading as one
  /// side of a conversation.
  static const double _maxWidthFraction = 0.82;
}

/// Waiting for an answer.
///
/// Says what is happening rather than spinning. Three providers may be tried in
/// turn, so this can genuinely take a few seconds — and a bare spinner for four
/// seconds reads as broken where a sentence reads as thinking.
class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: AppRadius.borderXl,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox.square(
                  dimension: AppIconSize.xs,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.space3),
                Text('Thinking about it', style: context.text.metadata),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The input row.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isBusy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isBusy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    // **No keyboard inset here.** It used to add `viewInsets.bottom`, and the
    // `Scaffold` above already resizes its body for the keyboard — so the inset
    // was counted twice and the composer floated a whole keyboard-height up the
    // screen, sitting on top of the conversation with empty space beneath it.
    //
    // The Scaffold's `resizeToAvoidBottomInset` is left on, which is the one that
    // should own this: it moves the whole column, so the last message stays
    // visible above the field instead of being covered by it.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppLayout.screenMargin,
        right: AppLayout.screenMargin,
        top: AppSpacing.space2,
        bottom: AppSpacing.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: AppTextField(
              controller: controller,
              hint: 'Ask about dinner',
              // Grows to three lines and stops. Past that the send button starts
              // walking off a short screen.
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: isBusy ? null : onSend,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton.primary(
            label: 'Ask',
            // Disabled while an answer is in flight rather than queuing a second
            // question. Two in flight is two bills and an hour's rate limit spent
            // on a conversation nobody can follow.
            onPressed: isBusy ? null : () => onSend(controller.text),
          ),
        ],
      ),
    );
  }
}
