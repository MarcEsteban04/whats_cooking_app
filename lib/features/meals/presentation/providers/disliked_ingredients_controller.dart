import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:whats_cooking/core/utils/logger.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/profile/presentation/providers/profile_controller.dart';

part 'disliked_ingredients_controller.g.dart';

/// Meals ruled out by the foods this household said they avoid (Sprint 35).
///
/// The other half of a promise the app has been making since migration 0011. The
/// preferences screen says "We will never suggest these" over a list of typed
/// foods, and until this sprint nothing read the list — so the roulette was free
/// to offer a meal built on the one ingredient somebody cannot stand.
///
/// **Refetched whenever the profile changes**, which is a slightly blunter
/// dependency than it wants to be — an avatar edit re-asks a question whose
/// inputs did not move. That costs one small RPC on a screen nobody spins from,
/// and the alternative was watching a narrower slice of a generated notifier,
/// which this Riverpod version does not offer. The blunt version is correct; the
/// precise one would have been cheaper.
///
/// **A failure here does not fail the spin.** That is a real trade and worth being
/// explicit about: ignoring the exclusions leaves a promise unkept, and throwing
/// leaves the household with no dinner at all. Migrations in this project are
/// applied by hand, so the realistic failure is a build that has landed ahead of
/// its migration — and in that window a roulette that refuses to spin is worse
/// than one that spins imperfectly. It says so loudly in the log rather than
/// quietly returning an empty set.
///
/// `keepAlive`, because every spin reads it and the answer only changes when the
/// preferences do.
@Riverpod(keepAlive: true)
Future<Set<String>> mealsBlockedByDislikes(Ref ref) async {
  // Watched, not read. The dependency is what makes this refresh after somebody
  // adds a food on the preferences screen — without it the exclusion would not
  // take effect until the app restarted.
  final List<String> avoided =
      ref.watch(profileControllerProvider).value?.preferences.dislikedFoods ??
      const <String>[];

  if (avoided.isEmpty) {
    // Nothing to ask about. The function would return an empty set anyway, and
    // this is the common case — most households avoid nothing.
    return const <String>{};
  }

  try {
    return await ref.read(mealRepositoryProvider).mealsBlockedByDislikes();
  } on Object catch (error) {
    AppLog.warning(
      'Could not check disliked ingredients — meals containing them may be '
      'offered. Apply the latest migration.',
      name: 'dislikedIngredients',
      data: <String, Object?>{
        'avoided': avoided.length,
        'reason': error.toString(),
      },
    );
    return const <String>{};
  }
}
