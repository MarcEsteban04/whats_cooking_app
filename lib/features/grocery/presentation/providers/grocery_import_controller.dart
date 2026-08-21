import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/ai/domain/entities/imported_list.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';
import 'package:whats_cooking/features/grocery/presentation/providers/grocery_controller.dart';

part 'grocery_import_controller.g.dart';

/// One line from an imported list, and whether it is being kept.
@immutable
class ImportCandidate {
  const ImportCandidate({required this.item, this.isKept = true});

  final ImportedItem item;

  /// Starts true.
  ///
  /// Opt-out rather than opt-in, like the fridge scan: forty unticked boxes is
  /// forty taps to use a feature whose whole promise was not typing. Safe because
  /// nothing is written until the button.
  final bool isKept;

  ImportCandidate copyWith({ImportedItem? item, bool? isKept}) =>
      ImportCandidate(item: item ?? this.item, isKept: isKept ?? this.isKept);
}

/// Where an import has got to.
@immutable
class GroceryImport {
  const GroceryImport({
    this.isReading = false,
    this.isAdding = false,
    this.hasRead = false,
    this.sourceName,
    this.candidates = const <ImportCandidate>[],
    this.failure,
  });

  final bool isReading;
  final bool isAdding;

  /// A read has finished at least once, so an empty list means "nothing found"
  /// rather than "nothing asked yet".
  final bool hasRead;

  /// The file's name, shown back so somebody can see they picked the right one.
  final String? sourceName;

  final List<ImportCandidate> candidates;
  final AppException? failure;

  List<ImportCandidate> get kept => <ImportCandidate>[
    for (final ImportCandidate candidate in candidates)
      if (candidate.isKept && candidate.item.name.trim().isNotEmpty) candidate,
  ];

  bool get isBusy => isReading || isAdding;
}

/// Importing a shopping list from a file (Sprint 53).
///
/// **Nothing is written until a button says so**, the same rule the fridge scanner
/// follows and for a sharper reason: a misread line here is not a wrong ingredient
/// in a database, it is something somebody buys. OCR on a handwritten list is
/// wrong often enough that an import you cannot correct would be worse than
/// typing.
///
/// The file itself never lands in a field on this class — it arrives as bytes on
/// their way out and is not held, so there is nothing to leak into a state dump or
/// to still be in memory when the screen closes.
@riverpod
class GroceryImportController extends _$GroceryImportController {
  @override
  GroceryImport build() => const GroceryImport();

  /// Sends a picked file and turns the answer into candidates.
  ///
  /// Exactly one of [bytes] or [text] is supplied — a `.txt` is decoded on the
  /// device, because text does not need to be an attachment and sending it as one
  /// would narrow which providers could answer it.
  Future<void> read({
    required String sourceName,
    Uint8List? bytes,
    String? text,
    String mimeType = 'image/jpeg',
  }) async {
    if (state.isBusy) {
      return;
    }

    // The previous file's lines go. A second file is a second list, and leaving
    // the first one's items beside it would produce something nobody could vouch
    // for.
    state = GroceryImport(isReading: true, sourceName: sourceName);

    try {
      final List<ImportedItem> items = await ref
          .read(assistantRepositoryProvider)
          .readShoppingList(bytes: bytes, text: text, mimeType: mimeType);

      state = GroceryImport(
        hasRead: true,
        sourceName: sourceName,
        candidates: <ImportCandidate>[
          for (final ImportedItem item in items) ImportCandidate(item: item),
        ],
      );
    } on Object catch (error, stackTrace) {
      state = GroceryImport(
        hasRead: true,
        sourceName: sourceName,
        failure: ErrorMapper.map(error, stackTrace),
      );
    }
  }

  /// Keeps or drops one line.
  void toggle(int index) => _replace(
    index,
    (ImportCandidate candidate) =>
        candidate.copyWith(isKept: !candidate.isKept),
  );

  /// Corrects a name.
  void rename(int index, String name) => _replace(
    index,
    (ImportCandidate candidate) =>
        candidate.copyWith(item: candidate.item.copyWith(name: name)),
  );

  /// Puts the kept lines on the list.
  ///
  /// Sequential and tolerant, like the fridge scan's: one unresolvable name costs
  /// that name rather than the other nineteen. The repository *merges* rather than
  /// duplicating, so importing a list twice — or importing over a list somebody
  /// has already started — adds quantities instead of producing two lines to read
  /// in an aisle.
  Future<({int added, AppException? failure})> addKept() async {
    final List<ImportCandidate> kept = state.kept;
    if (kept.isEmpty || state.isBusy) {
      return (added: 0, failure: null);
    }

    state = GroceryImport(
      isAdding: true,
      hasRead: state.hasRead,
      sourceName: state.sourceName,
      candidates: state.candidates,
    );

    int added = 0;
    AppException? failure;

    for (final ImportCandidate candidate in kept) {
      final AppException? error = await ref
          .read(groceryControllerProvider.notifier)
          .add(
            name: candidate.item.name.trim(),
            quantity: candidate.item.quantity,
            unit: candidate.item.unit,
          );

      if (error == null) {
        added += 1;
      } else {
        failure ??= error;
      }
    }

    // Cleared on the way out. The list has been dealt with, and leaving it on
    // screen behind a snackbar invites importing it twice.
    state = const GroceryImport();

    return (added: added, failure: failure);
  }

  /// Back to the start, for another file.
  void reset() => state = const GroceryImport();

  void _replace(int index, ImportCandidate Function(ImportCandidate) change) {
    if (index < 0 || index >= state.candidates.length || state.isBusy) {
      return;
    }

    state = GroceryImport(
      hasRead: state.hasRead,
      sourceName: state.sourceName,
      candidates: <ImportCandidate>[
        for (final (int at, ImportCandidate candidate)
            in state.candidates.indexed)
          if (at == index) change(candidate) else candidate,
      ],
    );
  }
}
