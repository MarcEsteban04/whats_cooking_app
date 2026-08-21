import 'dart:math';

/// The arithmetic both roulettes share (Sprint 46).
///
/// **Extracted rather than duplicated.** Two roulettes now draw from scores — one
/// over meals, one over restaurants — and the parts that turn points into a
/// decision are *identical* between them: the exponential weighting, the floor and
/// cap, the weighted draw, and the headroom ramp. Those are the pieces where a
/// second copy would drift the first time either was tuned, and the drift would be
/// invisible: both engines would still work, and they would disagree about what
/// "well under budget" is worth.
///
/// **What is not here is the signals**, and that is the honest boundary.
/// docs/ARCHITECTURE.md §5.2 said "the same engine scores restaurants — only the
/// pool changes", and that was an overstatement worth correcting: budget, cuisine
/// preference, variety, favourites, recency and mood are shared, but cooking time
/// and the pantry match are meaningless for a restaurant, and proximity and
/// delivery are meaningless for a meal. A single scorer taking a union of nine
/// fields, four of them always null, would be one function pretending to be two.
///
/// So: the maths is shared, the weight tables are each engine's own, and the two
/// score functions read like what they are.
abstract final class SpinWeighting {
  /// Turns a score into a relative likelihood.
  ///
  /// `exp(score / temperature)`, clamped. Exponential rather than proportional
  /// because "proportional to score" is undefined once a score is negative and
  /// every penalty produces negative scores — clamping at zero would make a
  /// penalised candidate not merely unlikely but impossible, which is an exclusion
  /// nobody asked for.
  static double weightFor(double score, double temperature) {
    if (temperature <= 0) {
      // A temperature of zero would mean "always the best one", which is a
      // ranking. Treated as flat instead: refusing to divide by zero by picking
      // the *other* extreme is the safer of the two failures.
      return 1;
    }
    return exp(score / temperature).clamp(minimumWeight, maximumWeight);
  }

  /// Two percent of a neutral candidate's odds: rare enough to feel like variety,
  /// possible enough that nothing is excluded by arithmetic rather than by a rule.
  static const double minimumWeight = 0.02;

  /// Twenty times. Past this the draw stops being a draw.
  static const double maximumWeight = 20;

  /// Eases a 0–1 headroom so that "just inside" earns much less than "comfortably
  /// inside", without a cliff between them.
  static double ramp(double headroom) => 0.4 + 0.6 * headroom.clamp(0.0, 1.0);

  /// Draws one candidate, weighted.
  ///
  /// Generic over the candidate type so both engines use this one implementation:
  /// the caller says how to read a weight, and everything else is the same
  /// cumulative walk.
  static T? draw<T>(
    List<T> candidates,
    double Function(T) weightOf,
    Random random,
  ) {
    if (candidates.isEmpty) {
      return null;
    }

    final double total = candidates.fold<double>(
      0,
      (double sum, T candidate) => sum + weightOf(candidate),
    );

    // Every weight is floored above zero, so this cannot be zero unless the list
    // is empty — which is handled. Guarded anyway, because a division by a sum is
    // the kind of thing that becomes possible three sprints later.
    if (total <= 0) {
      return candidates[random.nextInt(candidates.length)];
    }

    double roll = random.nextDouble() * total;
    for (final T candidate in candidates) {
      roll -= weightOf(candidate);
      if (roll <= 0) {
        return candidate;
      }
    }

    // Floating-point drift can leave the roll a hair above the sum. The last
    // candidate is the correct answer in that case, not an error.
    return candidates.last;
  }
}
