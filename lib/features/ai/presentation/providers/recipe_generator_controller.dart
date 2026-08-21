import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/features/ai/domain/entities/generated_recipe.dart';
import 'package:whats_cooking/features/ai/presentation/providers/ai_context.dart';
import 'package:whats_cooking/features/ai/presentation/providers/assistant_controller.dart';

part 'recipe_generator_controller.g.dart';

/// Where the recipe writer has got to (Sprint 48).
@immutable
class RecipeIdea {
  const RecipeIdea({
    this.isWriting = false,
    this.recipe,
    this.failure,
    this.attempts = 0,
  });

  final bool isWriting;

  /// The last recipe that came back, or null before the first one.
  final GeneratedRecipe? recipe;

  final AppException? failure;

  /// How many have been asked for this visit.
  ///
  /// Drives the wording — the second button says "try another", not "write one" —
  /// and it is the honest way to say it, because the first recipe is not
  /// necessarily the one anybody wants.
  final int attempts;

  bool get hasRecipe => recipe != null;
}

/// Asking the assistant to invent a meal (Sprint 48).
///
/// **This is how the library grows without typing.** Every other route into
/// `meals` costs somebody twelve fields, which is why a household's own food goes
/// in slowly or not at all — and the roulette is only as good as the library it
/// draws from. A recipe written from what is already in the kitchen is the one
/// place the AI adds something the deterministic engine could never do.
///
/// **Nothing here saves.** The controller holds a recipe; the screen shows it; the
/// meal form stores it. See [GeneratedRecipe.toDraft].
///
/// Not `keepAlive`. A recipe belongs to the moment somebody asked for it — coming
/// back to this screen a day later and finding last night's suggestion still on it
/// would read as a saved thing that is not saved.
@riverpod
class RecipeGenerator extends _$RecipeGenerator {
  @override
  RecipeIdea build() => const RecipeIdea();

  /// Writes one.
  ///
  /// [ingredients] is what to build around — normally the pantry, which is what
  /// makes this better than asking a chat app the same question. [note] is
  /// whatever somebody typed, and it is optional: an empty kitchen and an empty
  /// note still gets a recipe, because "I do not know, surprise me" is a real
  /// request.
  Future<void> write({
    required List<String> ingredients,
    String? note,
  }) async {
    if (state.isWriting) {
      return;
    }

    // The previous recipe stays on screen while the next is written. Blanking it
    // would mean a tap on "try another" throws away a perfectly good suggestion
    // before knowing whether the replacement arrives.
    state = RecipeIdea(
      isWriting: true,
      recipe: state.recipe,
      attempts: state.attempts,
    );

    try {
      final GeneratedRecipe recipe = await ref
          .read(assistantRepositoryProvider)
          .generateRecipe(
            ingredients: ingredients,
            note: note,
            context: householdAiContext(ref),
          );

      state = RecipeIdea(recipe: recipe, attempts: state.attempts + 1);
    } on Object catch (error, stackTrace) {
      state = RecipeIdea(
        recipe: state.recipe,
        failure: ErrorMapper.map(error, stackTrace),
        attempts: state.attempts,
      );
    }
  }

  /// Forgets the recipe, after it has been saved or turned down.
  void clear() => state = const RecipeIdea();
}
