/// Non-visual application constants.
///
/// Visual values live in `core/theme/` (docs/DESIGN_SYSTEM.md); these are the
/// product's numbers. Each cites the document it comes from, because a number
/// with no provenance gets "adjusted" by the next person to read it.
abstract final class AppConstants {
  /// The product name, as it appears in copy.
  static const String appName = "What's Cooking?";

  /// docs/app_feature.md, Brand.
  static const String tagline = 'No more "ikaw bahala."';

  /// Who a build with no Supabase credentials considers to be signed in.
  ///
  /// Lives here rather than in either place that needs it, so the auth layer
  /// and the in-memory meal store can agree without depending on each other.
  /// It is not a real user id and never reaches a server: the only code that
  /// compares against it is the fallback that also stamps it.
  static const String localAuthorId = 'local-author';

  // ---------------------------------------------------------------------------
  // Budget (docs/app_feature.md, "Budget")
  // ---------------------------------------------------------------------------

  /// The presets offered before a custom amount.
  static const List<int> budgetPresets = <int>[100, 200, 300, 500];

  /// The starting default, matching the examples throughout the product docs.
  static const int defaultBudget = 300;

  static const int minBudget = 50;

  /// A ceiling on the custom input. Not a product rule — a guard against a
  /// mistyped amount silently disabling the budget filter entirely.
  static const int maxBudget = 10000;

  /// Household size the roulette assumes until told otherwise.
  static const int defaultPartySize = 2;

  // ---------------------------------------------------------------------------
  // Recommendation engine (docs/ARCHITECTURE.md §5.2)
  // ---------------------------------------------------------------------------

  /// How many top-scoring candidates the weighted pick draws from.
  ///
  /// Pure top-1 is deterministic and stops feeling like a roulette; uniform
  /// random over the whole catalogue is what every competitor already does
  /// badly. Ten is the balance the architecture settles on.
  static const int recommendationPoolSize = 10;

  /// Days back that count as "recently eaten" for the repetition penalty
  /// (docs/project_dev.md, Sprint 32).
  static const int repetitionWindowDays = 7;

  /// Longest cooking time offered as a filter, in minutes.
  static const int maxCookingTimeMinutes = 180;

  // ---------------------------------------------------------------------------
  // Paging and input
  // ---------------------------------------------------------------------------

  /// Rows per page in the meal feed.
  static const int pageSize = 20;

  /// Search debounce (docs/COMPONENTS.md §2).
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Default request timeout.
  ///
  /// Sits just above the 2 s P95 spin-latency budget (docs/ARCHITECTURE.md §12)
  /// so a request that will miss the budget fails fast rather than leaving the
  /// user watching a spinner.
  static const Duration requestTimeout = Duration(seconds: 10);

  // ---------------------------------------------------------------------------
  // The north-star metric (docs/ARCHITECTURE.md §10)
  // ---------------------------------------------------------------------------

  /// Time to Decision target: under 60 seconds from app open to accepted meal.
  ///
  /// Not a threshold the app enforces — the number the product is measured
  /// against, kept here so the analytics event and the goal cannot drift apart.
  static const Duration timeToDecisionTarget = Duration(seconds: 60);

  /// The currency the product is priced in (docs/app_feature.md).
  static const String currencyCode = 'PHP';

  // ---------------------------------------------------------------------------
  // Deep links (docs/NAVIGATION_MAP.md §5)
  // ---------------------------------------------------------------------------

  /// The app's custom scheme.
  static const String deepLinkScheme = 'whatscooking';

  /// The HTTPS host for App Links and Universal Links.
  static const String deepLinkHost = 'whatscooking.app';

  /// Where a password-reset email sends the user.
  ///
  /// The custom scheme rather than the HTTPS host, because App Links and
  /// Universal Links need verified domain association files served from that
  /// host — Sprint 69's work. Until then the scheme is the link that actually
  /// opens the app, and a reset link that opens a web page instead is a reset
  /// nobody completes.
  static const String passwordResetRedirect =
      '$deepLinkScheme://reset-password';
}
