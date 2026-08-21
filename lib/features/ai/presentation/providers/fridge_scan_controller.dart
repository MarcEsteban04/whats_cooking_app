import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';

part 'fridge_scan_controller.g.dart';

/// One thing the photo might have shown (Sprint 49).
///
/// Kept and editable, both of which matter: recognition is wrong often enough
/// that a list you can only accept whole is a list that poisons the pantry, and a
/// poisoned pantry poisons the roulette.
@immutable
class ScanCandidate {
  const ScanCandidate({required this.name, this.isKept = true});

  final String name;

  /// Starts true.
  ///
  /// **Opt-out rather than opt-in**, which is the one place this screen trusts the
  /// model — and it is safe to, because nothing is written until somebody presses
  /// the button. Twelve unticked boxes is twelve taps to use a feature whose whole
  /// promise was not typing.
  final bool isKept;

  ScanCandidate copyWith({String? name, bool? isKept}) =>
      ScanCandidate(name: name ?? this.name, isKept: isKept ?? this.isKept);
}

/// Where the scan has got to.
@immutable
class FridgeScan {
  const FridgeScan({
    this.isReading = false,
    this.isAdding = false,
    this.hasRead = false,
    this.candidates = const <ScanCandidate>[],
    this.failure,
  });

  /// The photo is with the model.
  final bool isReading;

  /// The kept items are being written to the pantry.
  final bool isAdding;

  /// A read has finished at least once.
  ///
  /// Distinguishes "nothing found" from "nothing asked yet", which are the same
  /// empty list and very different sentences.
  final bool hasRead;

  final List<ScanCandidate> candidates;
  final AppException? failure;

  List<ScanCandidate> get kept => <ScanCandidate>[
    for (final ScanCandidate candidate in candidates)
      if (candidate.isKept && candidate.name.trim().isNotEmpty) candidate,
  ];

  bool get isBusy => isReading || isAdding;
}

/// Reading the fridge (Sprint 49).
///
/// **Nothing here writes to the pantry on its own.** The roadmap's words are
/// "detected ingredients presented *for confirmation*, never inserted silently",
/// and the reason is arithmetic rather than caution: recognition is wrong often
/// enough that trusting it would poison the pantry, and the pantry is what the
/// roulette leans on. [addKept] exists and is only ever called by a button.
///
/// The photo never reaches this class as anything but bytes on their way out, and
/// it is never held: no field keeps it, so there is nothing to leak into a state
/// dump or to still be in memory when the screen is left.
@riverpod
class FridgeScanController extends _$FridgeScanController {
  @override
  FridgeScan build() => const FridgeScan();

  /// Sends a photo and turns the answer into candidates.
  Future<void> read(Uint8List image, {String mimeType = 'image/jpeg'}) async {
    if (state.isBusy) {
      return;
    }

    // The previous candidates go, unlike the recipe generator's last recipe. A
    // second photo is a second fridge; leaving the first photo's items on screen
    // beside the second's would produce a list nobody could vouch for.
    state = const FridgeScan(isReading: true);

    try {
      final List<String> names = await ref
          .read(assistantRepositoryProvider)
          .readFridge(image: image, mimeType: mimeType);

      state = FridgeScan(
        hasRead: true,
        candidates: <ScanCandidate>[
          for (final String name in names) ScanCandidate(name: name),
        ],
      );
    } on Object catch (error, stackTrace) {
      state = FridgeScan(
        hasRead: true,
        failure: ErrorMapper.map(error, stackTrace),
      );
    }
  }

  /// Keeps or drops one.
  void toggle(int index) => _replace(
    index,
    (ScanCandidate candidate) =>
        candidate.copyWith(isKept: !candidate.isKept),
  );

  /// Corrects a name.
  ///
  /// The correction is what makes this feature safe to use at all — "kangkong"
  /// read as "spinach" is the common case, not the rare one, and it is a fix
  /// somebody makes in two seconds if the field lets them.
  void rename(int index, String name) =>
      _replace(index, (ScanCandidate candidate) => candidate.copyWith(name: name));

  /// Writes the kept items to the kitchen.
  ///
  /// Returns how many landed, and the first failure if there was one. **Sequential
  /// and tolerant**: each name has to be resolved against the shared vocabulary and
  /// possibly added to it, so one bad name should cost that name rather than the
  /// other seven. "Six of eight added" is a true sentence; "nothing added because
  /// of malunggay" is a worse outcome dressed as safety.
  ///
  /// No quantities and no dates. A photo establishes *that* there is rice, which is
  /// exactly what a null quantity means in this app — and inventing "1 kg" would be
  /// the one number nobody typed.
  Future<({int added, AppException? failure})> addKept() async {
    final List<ScanCandidate> kept = state.kept;
    if (kept.isEmpty || state.isBusy) {
      return (added: 0, failure: null);
    }

    state = FridgeScan(
      isAdding: true,
      hasRead: state.hasRead,
      candidates: state.candidates,
    );

    int added = 0;
    AppException? failure;

    for (final ScanCandidate candidate in kept) {
      final AppException? error = await ref
          .read(pantryControllerProvider.notifier)
          .add(name: candidate.name.trim());

      if (error == null) {
        added += 1;
      } else {
        failure ??= error;
      }
    }

    // Cleared on the way out. The list has been dealt with, and leaving it on
    // screen behind a snackbar invites adding it twice.
    state = const FridgeScan();

    return (added: added, failure: failure);
  }

  /// Back to the start, for another photo.
  void reset() => state = const FridgeScan();

  void _replace(int index, ScanCandidate Function(ScanCandidate) change) {
    if (index < 0 || index >= state.candidates.length || state.isBusy) {
      return;
    }

    state = FridgeScan(
      hasRead: state.hasRead,
      candidates: <ScanCandidate>[
        for (final (int at, ScanCandidate candidate)
            in state.candidates.indexed)
          if (at == index) change(candidate) else candidate,
      ],
    );
  }
}
