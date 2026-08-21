import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/domain/food_preferences.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/errors/app_exception.dart';
import 'package:whats_cooking/core/errors/error_mapper.dart';
import 'package:whats_cooking/core/network/backend_health.dart';
import 'package:whats_cooking/core/network/supabase_bootstrap.dart';
import 'package:whats_cooking/features/ai/data/repositories/supabase_assistant_repository.dart';
import 'package:whats_cooking/features/ai/domain/entities/assistant_message.dart';
import 'package:whats_cooking/features/history/domain/entities/meal_history_entry.dart';
import 'package:whats_cooking/features/history/presentation/providers/meal_history_controller.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_item.dart';
import 'package:whats_cooking/features/pantry/domain/entities/pantry_match.dart';
import 'package:whats_cooking/features/pantry/presentation/providers/pantry_controller.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';

part 'assistant_controller.g.dart';

/// The assistant backend.
@Riverpod(keepAlive: true)
AssistantRepository assistantRepository(Ref ref) {
  if (!SupabaseBootstrap.isInitialized) {
    return const UnavailableAssistantRepository();
  }
  return SupabaseAssistantRepository(ref.read(supabaseClientProvider));
}

/// A conversation with the assistant (Sprint 47).
@immutable
class AssistantConversation {
  const AssistantConversation({
    this.messages = const <AssistantMessage>[],
    this.isThinking = false,
    this.failure,
  });

  final List<AssistantMessage> messages;

  /// True between sending and the reply arriving.
  ///
  /// Its own flag rather than an `AsyncLoading`, because the conversation is still
  /// there and still worth reading while the next answer is coming — a loading
  /// state that blanks the screen would hide the question just asked.
  final bool isThinking;

  /// The last failure, or null.
  ///
  /// Kept beside the conversation rather than replacing it: a rate limit is not a
  /// reason to lose what was already said.
  final AppException? failure;

  bool get isEmpty => messages.isEmpty;

  AssistantConversation copyWith({
    List<AssistantMessage>? messages,
    bool? isThinking,
    AppException? failure,
    bool clearFailure = false,
  }) {
    return AssistantConversation(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Asking the app in words (Sprint 47).
///
/// **Context is assembled here, not in the UI and not in the Edge Function.** The
/// function renders whatever it is given as a labelled block of facts; deciding
/// *which* facts is a product judgement, and it is the difference between an
/// assistant that answers "what can we cook tonight" and one that guesses.
///
/// `keepAlive`, so backing out of the screen and returning does not lose the
/// conversation. A chat that forgets the moment you check the pantry is a chat
/// nobody uses twice.
@Riverpod(keepAlive: true)
class AssistantController extends _$AssistantController {
  @override
  AssistantConversation build() => const AssistantConversation();

  /// Asks something.
  Future<void> ask(String question) async {
    final String trimmed = question.trim();
    if (trimmed.isEmpty || state.isThinking) {
      return;
    }

    final List<AssistantMessage> withQuestion = <AssistantMessage>[
      ...state.messages,
      AssistantMessage.user(trimmed),
    ];

    state = state.copyWith(
      messages: withQuestion,
      isThinking: true,
      clearFailure: true,
    );

    try {
      final AssistantReply reply = await ref
          .read(assistantRepositoryProvider)
          .ask(messages: withQuestion, context: _context());

      state = state.copyWith(
        messages: <AssistantMessage>[
          ...withQuestion,
          AssistantMessage(
            role: AssistantRole.assistant,
            content: reply.text,
            provider: reply.provider,
          ),
        ],
        isThinking: false,
      );
    } on Object catch (error, stackTrace) {
      // The question stays in the list. Losing what somebody typed because the
      // answer failed is the one thing that would make them stop trying.
      state = state.copyWith(
        isThinking: false,
        failure: ErrorMapper.map(error, stackTrace),
      );
    }
  }

  /// Asks the last question again, after a failure.
  Future<void> retry() async {
    final AssistantMessage? last = state.messages.isEmpty
        ? null
        : state.messages.last;

    if (last == null || !last.isUser) {
      return;
    }

    // Dropped and re-asked rather than resent, so the list does not end up with
    // the same question twice.
    state = state.copyWith(
      messages: state.messages.sublist(0, state.messages.length - 1),
      clearFailure: true,
    );
    await ask(last.content);
  }

  /// Starts over.
  void clear() => state = const AssistantConversation();

  /// What the assistant is told about this household.
  ///
  /// **Chosen, not dumped.** Every value is capped at 300 characters by the Edge
  /// Function, and more importantly every value costs tokens on every turn — so
  /// this sends the facts that change an answer and nothing else.
  ///
  /// The two lists worth explaining:
  ///
  /// * **`can_cook_now`** is what the pantry already covers. This is the single
  ///   most useful thing the app knows and the reason the assistant can answer "we
  ///   only have chicken and eggs" without being told.
  /// * **`some_of_our_meals`** is a *sample*, not the library. Sixty names would
  ///   blow the cap and spend tokens listing food nobody asked about; a dozen is
  ///   enough to teach the model what kind of food this household eats, which is
  ///   what stops it inventing a recipe for something they have never cooked.
  ///
  /// Nothing here is a name or an address. The household's own food is not PII, and
  /// the display name is deliberately absent — the assistant has no use for it and
  /// a prompt is not a place to put one.
  Map<String, Object?> _context() {
    final FoodPreferences? preferences = ref
        .read(profileControllerProvider)
        .value
        ?.preferences;

    final List<PantryItem> pantry =
        ref.read(pantryControllerProvider).value ?? const <PantryItem>[];

    final Map<String, PantryMatch> matches =
        ref.read(pantryMatchesProvider).value ?? const <String, PantryMatch>{};

    final List<Meal> library =
        ref.read(mealsControllerProvider).value?.meals ?? const <Meal>[];

    final Map<String, Meal> byId = <String, Meal>{
      for (final Meal meal in library) meal.id: meal,
    };

    return <String, Object?>{
      if (preferences?.budget case final int budget)
        'budget_per_head_pesos': budget,
      if (preferences?.maxCookingTimeMinutes case final int minutes)
        'max_cooking_minutes': minutes,
      'cooking_for': preferences?.preferredServings,
      if (preferences?.dietaryTags.isNotEmpty ?? false)
        'dietary_needs': preferences!.dietaryTags
            .map((DietaryTag tag) => tag.label)
            .join(', '),
      if (preferences?.dislikedFoods.isNotEmpty ?? false)
        'foods_to_avoid': preferences!.dislikedFoods.join(', '),
      if (preferences?.favouriteCuisines.isNotEmpty ?? false)
        'cuisines_they_like': preferences!.favouriteCuisines
            .map((Cuisine cuisine) => cuisine.label)
            .join(', '),

      if (pantry.isNotEmpty)
        'in_the_kitchen': _capped(
          pantry.map((PantryItem item) => item.name),
          _pantryNames,
        ),

      if (matches.isNotEmpty)
        'can_cook_now': _capped(
          <String>[
            for (final MapEntry<String, PantryMatch> entry in matches.entries)
              if (entry.value.isComplete && byId[entry.key] != null)
                byId[entry.key]!.name,
          ],
          _cookableNames,
        ),

      'eaten_recently': _capped(_recentNames(), _recentCount),

      if (library.isNotEmpty)
        'some_of_our_meals': _capped(
          library.map((Meal meal) => meal.name),
          _librarySample,
        ),
    };
  }

  /// The last few things eaten, newest first.
  List<String> _recentNames() {
    final List<MealHistoryEntry> history =
        ref.read(mealHistoryProvider).value ?? const <MealHistoryEntry>[];

    return <String>[
      for (final MealHistoryEntry entry in history)
        if (entry.meal?.name case final String name) name,
    ];
  }

  /// The first [limit] of [names], joined — or null when there are none.
  ///
  /// Null rather than an empty string, because the function skips empty values and
  /// "in_the_kitchen: " with nothing after it is a line that makes the model think
  /// the kitchen is empty rather than unknown.
  static String? _capped(Iterable<String> names, int limit) {
    final List<String> taken = names.take(limit).toList();
    return taken.isEmpty ? null : taken.join(', ');
  }

  /// Enough to answer "what can I make with this", short enough not to be a
  /// shopping inventory.
  static const int _pantryNames = 20;

  /// The whole point of the pantry, so it gets the most room.
  static const int _cookableNames = 12;

  /// A week's worth. Past that it stops informing "not that again".
  static const int _recentCount = 7;

  /// A sample, to teach the model what kind of food this is. Not the library.
  static const int _librarySample = 12;
}
