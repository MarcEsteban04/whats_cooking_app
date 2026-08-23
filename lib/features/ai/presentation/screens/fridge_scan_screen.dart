import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/app_toast.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/ai/presentation/providers/fridge_scan_controller.dart';

/// Point the camera at the fridge (Sprint 49).
///
/// **The confirmation list is the feature, not the recognition.** A vision model
/// reading a shelf gets most of it and invents some of it, and inventing is the
/// case that matters: a wrong ingredient in the pantry changes what the roulette
/// leans toward and what the grocery list stops asking for. So nothing is written
/// until somebody has read the list, and every line can be corrected or dropped
/// before it is.
///
/// **The photo is never stored.** Not by this app and not by us — it is downscaled
/// on the device, sent, read once, and gone. There is no bucket, no row and no log
/// line, which is also why there is no "recent scans" here to look back at.
class FridgeScanScreen extends ConsumerStatefulWidget {
  const FridgeScanScreen({super.key});

  @override
  ConsumerState<FridgeScanScreen> createState() => _FridgeScanScreenState();
}

class _FridgeScanScreenState extends ConsumerState<FridgeScanScreen> {
  final ImagePicker _picker = ImagePicker();

  /// Set while the system camera or gallery is open.
  ///
  /// Its own flag rather than the controller's: nothing has been sent yet, and a
  /// controller that showed "reading" while somebody was still framing the shot
  /// would be lying about where the time went.
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final FridgeScan scan = ref.watch(fridgeScanControllerProvider);
    final bool isBusy = scan.isBusy || _isPicking;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Read the fridge'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenMargin,
                AppSpacing.space4,
                AppLayout.screenMargin,
                AppSpacing.space8,
              ),
              children: <Widget>[
                if (scan.failure case final AppException failure) ...<Widget>[
                  InlineErrorBanner(
                    message: failure.displayMessage ?? failure.message,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],

                if (scan.isReading)
                  const _Reading()
                else if (scan.candidates.isNotEmpty)
                  _Found(
                    scan: scan,
                    onToggle: ref
                        .read(fridgeScanControllerProvider.notifier)
                        .toggle,
                    onRename: ref
                        .read(fridgeScanControllerProvider.notifier)
                        .rename,
                  )
                else
                  _Prompt(hasRead: scan.hasRead && scan.failure == null),

                const SizedBox(height: AppSpacing.space5),

                if (scan.candidates.isEmpty)
                  ..._pickButtons(isBusy: isBusy, hasRead: scan.hasRead)
                else ...<Widget>[
                  AppButton.inverse(
                    label: switch (scan.kept.length) {
                      0 => 'Nothing ticked',
                      1 => 'Add 1 to the kitchen',
                      final int count => 'Add $count to the kitchen',
                    },
                    isLoading: scan.isAdding,
                    onPressed: isBusy || scan.kept.isEmpty ? null : _add,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  AppButton.secondary(
                    label: 'Take another',
                    isFullWidth: true,
                    onPressed: isBusy ? null : () => _pick(ImageSource.camera),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _pickButtons({required bool isBusy, required bool hasRead}) {
    return <Widget>[
      AppButton.inverse(
        label: hasRead ? 'Try another photo' : 'Take a photo',
        leadingIcon: AppIcons.camera,
        isLoading: _isPicking,
        onPressed: isBusy ? null : () => _pick(ImageSource.camera),
      ),
      const SizedBox(height: AppSpacing.space2),
      AppButton.secondary(
        label: 'Choose one instead',
        isFullWidth: true,
        onPressed: isBusy ? null : () => _pick(ImageSource.gallery),
      ),
    ];
  }

  /// Opens the camera or the gallery, then sends what comes back.
  ///
  /// **Downscaled by the platform, not by us.** `maxWidth`/`maxHeight` and
  /// `imageQuality` are applied before the bytes cross into Dart, so a
  /// twelve-megapixel photo never becomes a twelve-megapixel list of bytes in this
  /// process. It also keeps the upload honest: 1280 px is more than enough for a
  /// model to read a shelf, and the full-resolution version would be a slow send
  /// and a bigger bill for the same answer.
  Future<void> _pick(ImageSource source) async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
      );

      if (file == null) {
        // Cancelled. Not a failure, and not worth a message — whatever was on
        // screen before is still the right thing to be looking at.
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }

      AppHaptics.spinBegun();
      await ref
          .read(fridgeScanControllerProvider.notifier)
          .read(bytes, mimeType: _mimeType(file));
    } on Object catch (error) {
      // A picker failure is a platform refusal — permission denied, no camera —
      // and it is the one error here that never reaches the controller. Logged
      // without the path, which on some platforms names the user's directory.
      AppLog.warning(
        'Could not take a photo.',
        name: 'fridge-scan',
        data: <String, Object?>{'reason': error.runtimeType.toString()},
      );
      if (mounted) {
        AppToast.failure('Could not open the camera. Check its permission.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _add() async {
    final ({int added, AppException? failure}) result = await ref
        .read(fridgeScanControllerProvider.notifier)
        .addKept();

    if (!mounted) {
      return;
    }

    AppHaptics.decided();
    // The count, and the shortfall when there was one. "Six of eight" is the
    // honest sentence, and it is better than a success message that quietly
    // dropped two — and the tone follows the count rather than the failure, so a
    // partial still reads as things having arrived.
    AppToast.show(switch (result) {
      (added: 0, failure: _) => 'Nothing was added.',
      (added: final int n, failure: null) =>
        n == 1
            ? '1 thing is in your kitchen'
            : '$n things are in your '
                  'kitchen',
      (added: final int n, failure: _) => '$n added — the rest could not be',
    }, tone: result.added == 0 ? ToastTone.failure : ToastTone.success);

    // Back to the pantry, which is where the result is. Staying on an empty scan
    // screen after adding eight things hides the thing that just happened.
    if (result.added > 0) {
      context.pop();
    }
  }

  /// What the picker handed back, as far as the function will accept.
  ///
  /// The platform's own answer when it gives one; otherwise inferred from the
  /// extension, and JPEG when even that is unclear — which is what
  /// `imageQuality` produces anyway.
  static String _mimeType(XFile file) {
    if (file.mimeType case final String declared
        when declared.startsWith('image/')) {
      return declared;
    }
    final String path = file.path.toLowerCase();
    if (path.endsWith('.png')) {
      return 'image/png';
    }
    if (path.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Plenty for reading a shelf, and about a tenth of the bytes.
  static const double _maxEdge = 1280;
  static const int _quality = 80;
}

/// Before the first photo, and after one that found nothing.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.hasRead});

  /// True once a photo has come back empty.
  final bool hasRead;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: hasRead ? 'No food in that one' : 'How this works',
      icon: AppIcons.camera,
      child: Text(
        hasRead
            // Says what to do differently rather than blaming the photo. Nearly
            // always it is the shot: a closed door, a dark shelf, or everything
            // behind a drawer front.
            ? 'Try again with the door open and the light on. Close enough that '
                  'the labels are readable helps most.'
            : 'Take a photo of an open fridge or a shelf. You will get a list to '
                  'check before anything is added — nothing goes into your '
                  'kitchen until you say so.\n\n'
                  'The photo is not saved anywhere.',
        style: context.text.bodyMedium,
      ),
    );
  }
}

/// While the model is looking.
class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Looking at it',
      icon: AppIcons.camera,
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: AppIconSize.sm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              // Says what is happening and what comes next. Three providers may be
              // tried in turn, so this can genuinely take a few seconds.
              'Working out what is in the picture. You will get a list to check.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The list, before anything is written.
class _Found extends StatelessWidget {
  const _Found({
    required this.scan,
    required this.onToggle,
    required this.onRename,
  });

  final FridgeScan scan;
  final ValueChanged<int> onToggle;
  final void Function(int index, String name) onRename;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Is this right?',
      icon: AppIcons.camera,
      trailing: Text(
        '${scan.kept.length} of ${scan.candidates.length}',
        style: context.text.metadata,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            // The instruction, once, above the list. Recognition being wrong is
            // the expected case rather than the exception, and saying so is what
            // makes somebody actually read the names instead of pressing add.
            'Untick anything that is not there, and fix any name that is close '
            'but wrong.',
            style: context.text.metadata,
          ),
          const SizedBox(height: AppSpacing.space3),

          for (final (int index, ScanCandidate candidate)
              in scan.candidates.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            _CandidateRow(
              // Keyed by name so a rename does not rebuild the field it is being
              // typed into, and a reordering could not carry text between rows.
              key: ValueKey<String>('$index-${candidate.name}'),
              candidate: candidate,
              isEnabled: !scan.isBusy,
              onToggle: () => onToggle(index),
              onRename: (String name) => onRename(index, name),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line: keep it or not, and what it is called.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.isEnabled,
    required this.onToggle,
    required this.onRename,
    super.key,
  });

  final ScanCandidate candidate;
  final bool isEnabled;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isKept = candidate.isKept;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: <Widget>[
          // A square rather than a Material checkbox. Everything else in this app
          // is drawn from the same few shapes, and a stock checkbox is the one
          // control that would announce itself as coming from somewhere else.
          Semantics(
            checked: isKept,
            label: candidate.name,
            child: InkWell(
              onTap: isEnabled ? onToggle : null,
              borderRadius: AppRadius.borderSm,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isKept ? colors.surfaceInverse : Colors.transparent,
                    border: Border.all(
                      color: isKept
                          ? colors.surfaceInverse
                          : colors.outlineStrong,
                      width: _boxBorder,
                    ),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: SizedBox.square(
                    dimension: _boxSize,
                    child: isKept
                        ? Icon(
                            AppIcons.check,
                            size: _tickSize,
                            color: colors.textOnInverse,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),

          // Borderless on purpose. Twelve boxed fields reads as a form to fill in;
          // this has to read as a list to check, which somebody can still tap and
          // correct.
          Expanded(
            child: TextFormField(
              initialValue: candidate.name,
              enabled: isEnabled,
              textCapitalization: TextCapitalization.none,
              style: context.text.titleSmall.copyWith(
                color: isKept ? colors.textPrimary : colors.textTertiary,
                decoration: isKept ? null : TextDecoration.lineThrough,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: AppSpacing.space2,
                ),
              ),
              onChanged: onRename,
            ),
          ),
        ],
      ),
    );
  }

  static const double _boxSize = 18;
  static const double _boxBorder = 1.5;
  static const double _tickSize = 16;
}
