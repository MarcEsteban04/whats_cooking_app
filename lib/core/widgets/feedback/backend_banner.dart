import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/theme/theme.dart';

/// Says out loud when the app is not talking to a real backend.
///
/// This exists because of a bug that was not a crash. Run without
/// `--dart-define-from-file=config/development.json` and
/// `authRepositoryProvider` quietly falls back to the in-memory stand-in: you
/// can create an account, get all the way into onboarding, and lose the whole
/// thing on the next launch — with nothing on screen ever having said so. The
/// only warning was a line in the debug console.
///
/// Keeping the app runnable without credentials is right, and
/// `supabase/README.md` promises it. Letting someone *invest* in an account that
/// cannot survive a restart is not. So the fallback stays and stops being
/// silent.
///
/// Shown only in debug builds. A release build that reached this state would be
/// a build-configuration failure, which is not something a user could act on.
class BackendBanner extends ConsumerWidget {
  const BackendBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    // `.value` rather than `when`: the probe is a network round trip, and a
    // spinner or an error state here would be louder than the thing it reports.
    // Until it answers there is nothing to say.
    final BackendStatus? status = ref.watch(backendStatusProvider).value;

    if (status == null || status.isUsable) {
      return const SizedBox.shrink();
    }

    // Carries its own bottom margin, so a call site can drop it into a column
    // unconditionally and get no gap at all on the healthy path.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: _Banner(status: status),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.status});

  final BackendStatus status;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.butter.background,
          borderRadius: AppRadius.borderMd,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                AppIcons.warning,
                size: AppIconSize.sm,
                color: colors.butter.foreground,
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _headline,
                      style: context.text.titleSmall.copyWith(
                        color: colors.butter.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      // The developer-facing diagnosis, which already names the
                      // fix for each of the three unusable states.
                      status.description,
                      style: context.text.bodySmall.copyWith(
                        color: colors.butter.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What it means for the person looking at the screen, before the diagnosis
  /// of why.
  String get _headline => switch (status) {
    BackendStatus.notConfigured =>
      'No backend — accounts will not survive a restart',
    BackendStatus.unreachable => 'Cannot reach the backend',
    BackendStatus.schemaUnavailable => 'Backend reached, schema missing',
    BackendStatus.healthy => '',
  };
}
