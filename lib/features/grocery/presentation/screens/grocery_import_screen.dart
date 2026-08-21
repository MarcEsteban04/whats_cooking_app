import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_presenter.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/utils/app_haptics.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/core/widgets/buttons/app_button.dart';
import 'package:whats_cooking/core/widgets/dashboard/dashboard.dart';
import 'package:whats_cooking/core/widgets/feedback/error_state.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_import_controller.dart';

/// Import a shopping list from a file (Sprint 53).
///
/// A photo of a list on paper, a `.txt`, or a PDF from a delivery app. The
/// assistant copies out what is on it, and **nothing reaches the list until
/// somebody has read it back** — a misread line here is not a wrong row in a
/// database, it is something bought.
///
/// **The file is not stored.** One request, on to whichever provider answers, then
/// nowhere. There is no bucket and no history, which is also why there is no list
/// of past imports here.
class GroceryImportScreen extends ConsumerStatefulWidget {
  const GroceryImportScreen({super.key});

  @override
  ConsumerState<GroceryImportScreen> createState() =>
      _GroceryImportScreenState();
}

class _GroceryImportScreenState extends ConsumerState<GroceryImportScreen> {
  /// Set while the system file picker is open.
  ///
  /// Its own flag rather than the controller's: nothing has been sent yet, and
  /// showing "reading" while somebody is still browsing would misattribute where
  /// the time went.
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final GroceryImport import = ref.watch(groceryImportControllerProvider);
    final bool isBusy = import.isBusy || _isPicking;

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
        title: const Text('Import a list'),
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
                if (import.failure case final AppException failure) ...<Widget>[
                  InlineErrorBanner(
                    message: failure.displayMessage ?? failure.message,
                    detail: failure.detail,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],

                if (import.isReading)
                  _Reading(sourceName: import.sourceName)
                else if (import.candidates.isNotEmpty)
                  _Found(
                    import: import,
                    onToggle: ref
                        .read(groceryImportControllerProvider.notifier)
                        .toggle,
                    onRename: ref
                        .read(groceryImportControllerProvider.notifier)
                        .rename,
                  )
                else
                  _Prompt(
                    hasRead: import.hasRead && import.failure == null,
                    sourceName: import.sourceName,
                  ),

                const SizedBox(height: AppSpacing.space5),

                if (import.candidates.isEmpty)
                  AppButton.inverse(
                    label: import.hasRead ? 'Try another file' : 'Choose a file',
                    leadingIcon: AppIcons.add,
                    isLoading: _isPicking,
                    onPressed: isBusy ? null : _pick,
                  )
                else ...<Widget>[
                  AppButton.inverse(
                    label: switch (import.kept.length) {
                      0 => 'Nothing ticked',
                      1 => 'Add 1 to the list',
                      final int count => 'Add $count to the list',
                    },
                    isLoading: import.isAdding,
                    onPressed: isBusy || import.kept.isEmpty ? null : _add,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  AppButton.secondary(
                    label: 'Choose a different file',
                    isFullWidth: true,
                    onPressed: isBusy ? null : _pick,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the picker and sends what comes back.
  ///
  /// One file, not many. An import is one list; letting somebody pick four and
  /// then merging them is a feature nobody asked for and four times the tokens.
  Future<void> _pick() async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _extensions,
        dialogTitle: 'Pick a shopping list',
      );

      if (file == null) {
        // Cancelled. Not a failure, and whatever was on screen is still the right
        // thing to be looking at.
        return;
      }

      // Read here rather than relying on a `bytes` field: `PlatformFile` hands
      // back a URI, and on Android that can be a content:// URI with no readable
      // path at all.
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _say('That file came back empty.');
        return;
      }

      if (!mounted) {
        return;
      }

      AppHaptics.spinBegun();
      final String extension = _extensionOf(file.name);

      if (extension == 'txt') {
        // **Decoded here rather than sent as an attachment.** Text does not need
        // to be a file, and sending it as one would narrow the provider chain to
        // the ones that read documents for no benefit. `allowMalformed`, because a
        // stray byte in a list somebody exported should cost that byte rather than
        // the import.
        await ref
            .read(groceryImportControllerProvider.notifier)
            .read(
              sourceName: file.name,
              text: utf8.decode(bytes, allowMalformed: true),
            );
        return;
      }

      await ref
          .read(groceryImportControllerProvider.notifier)
          .read(
            sourceName: file.name,
            bytes: bytes,
            mimeType: _mimeFor(extension),
          );
    } on Object catch (error) {
      // A picker failure is a platform refusal — a permission, a provider that
      // returned nothing. Logged without the path, which names the user's
      // directories on some platforms.
      AppLog.warning(
        'Could not open a file.',
        name: 'grocery-import',
        data: <String, Object?>{'reason': error.runtimeType.toString()},
      );
      _say('Could not open that file.');
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _add() async {
    final ({int added, AppException? failure}) result = await ref
        .read(groceryImportControllerProvider.notifier)
        .addKept();

    if (!mounted) {
      return;
    }

    AppHaptics.decided();
    _say(switch (result) {
      (added: 0, failure: _) => 'Nothing was added.',
      (added: final int n, failure: null) =>
        n == 1 ? '1 thing is on your list' : '$n things are on your list',
      (added: final int n, failure: _) => '$n added — the rest could not be',
    });

    // Back to the list, which is where the result is.
    if (result.added > 0) {
      context.pop();
    }
  }

  void _say(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The extension, lower cased, or empty.
  ///
  /// From the name rather than from a field: `PlatformFile` exposes a URI, and on
  /// Android a `content://` URI carries no usable path to take a suffix from.
  static String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// What the function will accept for an attachment.
  static String _mimeFor(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };

  /// A photo of a list, a text file, or a PDF from a delivery app.
  ///
  /// Narrow on purpose. A picker that offers every file on the device is a picker
  /// somebody uses wrongly once and then does not trust — and of these, only
  /// Gemini reads the PDF, so widening it further would mean refusing more files
  /// after they had been chosen rather than before.
  static const List<String> _extensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'txt',
    'pdf',
  ];
}

/// Before a file has been picked, and after one that had nothing on it.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.hasRead, required this.sourceName});

  final bool hasRead;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: hasRead ? 'No list in that one' : 'How this works',
      icon: AppIcons.grocery,
      child: Text(
        hasRead
            ? 'Nothing on ${sourceName ?? 'that file'} looked like a shopping '
                  'list. A photo works best straight on, with the writing '
                  'readable.'
            : 'Pick a photo of a list, a .txt, or a PDF. You will get the items '
                  'to check before anything is added — nothing goes on your '
                  'list until you say so.\n\n'
                  'Quantities are kept when the list writes them, so "2 kg rice" '
                  'arrives as two kilos.\n\n'
                  'The file is not saved anywhere.',
        style: context.text.bodyMedium,
      ),
    );
  }
}

/// While the model is reading.
class _Reading extends StatelessWidget {
  const _Reading({required this.sourceName});

  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Reading it',
      icon: AppIcons.grocery,
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: AppIconSize.sm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              'Copying the items out of ${sourceName ?? 'the file'}. You will '
              'get them to check.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The items, before anything is written.
class _Found extends StatelessWidget {
  const _Found({
    required this.import,
    required this.onToggle,
    required this.onRename,
  });

  final GroceryImport import;
  final ValueChanged<int> onToggle;
  final void Function(int index, String name) onRename;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Is this right?',
      icon: AppIcons.grocery,
      trailing: Text(
        '${import.kept.length} of ${import.candidates.length}',
        style: context.text.metadata,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Untick anything you do not want, and fix any name that is close but '
            'wrong. Anything already on your list is merged rather than added '
            'twice.',
            style: context.text.metadata,
          ),
          const SizedBox(height: AppSpacing.space3),

          for (final (int index, ImportCandidate candidate)
              in import.candidates.indexed) ...<Widget>[
            if (index > 0) const DashboardRule(),
            _CandidateRow(
              key: ValueKey<String>('$index-${candidate.item.name}'),
              candidate: candidate,
              isEnabled: !import.isBusy,
              onToggle: () => onToggle(index),
              onRename: (String name) => onRename(index, name),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line: keep it or not, what it is called, and how much.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.isEnabled,
    required this.onToggle,
    required this.onRename,
    super.key,
  });

  final ImportCandidate candidate;
  final bool isEnabled;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colors = context.colors;
    final bool isKept = candidate.isKept;
    final String amount = _amount();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: <Widget>[
          // A square rather than a Material checkbox, matching the fridge scan.
          // Everything in this app is drawn from the same few shapes, and a stock
          // checkbox is the one control that announces it came from elsewhere.
          Semantics(
            checked: isKept,
            label: candidate.item.name,
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

          // Borderless, so twenty of these read as a list to check rather than as
          // a form to fill in.
          Expanded(
            child: TextFormField(
              initialValue: candidate.item.name,
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

          // The amount, read-only. Editing it belongs on the list itself, where
          // there is a field for it — putting a second input on every row here
          // would turn a confirmation into data entry.
          if (amount.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.space2),
            Text(
              amount,
              style: context.text.metadata.copyWith(
                color: isKept ? colors.textSecondary : colors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `2 kg`, `3`, or empty.
  String _amount() {
    final double? quantity = candidate.item.quantity;
    final String unit = candidate.item.unit;

    if (quantity == null) {
      return unit;
    }

    final String figure = quantity == quantity.roundToDouble()
        ? '${quantity.round()}'
        : quantity.toStringAsFixed(1);

    return unit.isEmpty ? figure : '$figure $unit';
  }

  static const double _boxSize = 18;
  static const double _boxBorder = 1.5;
  static const double _tickSize = 16;
}
