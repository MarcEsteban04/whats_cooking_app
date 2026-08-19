/// The read-through cache table from docs/ARCHITECTURE.md §4.
///
/// "Read-through, deliberately modest — the MVP is explicitly **not**
/// offline-first" (docs/PRD.md non-goal 7). Shared household data makes conflict
/// resolution disproportionate to the benefit, so this caches reads and never
/// queues writes.
///
/// The one entry that is a product requirement rather than an optimisation is
/// [meals]: docs/USER_FLOWS.md §18 states that **the roulette must work against
/// cache alone**. A user with no signal still gets a decision — that is the core
/// promise, and it does not get a network dependency.
enum CachePolicy {
  /// The meal catalogue's first page, and any detail that has been viewed.
  meals(ttl: Duration(hours: 24)),

  /// A single meal's detail, cached on view.
  mealDetail(ttl: Duration(hours: 24)),

  /// The signed-in user's preferences. Refreshed on change.
  preferences(ttl: null),

  /// Pantry contents. Network first, cache as fallback.
  pantry(ttl: null, isNetworkFirst: true),

  /// Grocery list. Network first, and realtime keeps it fresh while on screen.
  grocery(ttl: null, isNetworkFirst: true),

  /// Meal history, for the repetition penalty.
  history(ttl: Duration(hours: 1)),

  /// The active household. Refreshed on change.
  household(ttl: null);

  const CachePolicy({required this.ttl, this.isNetworkFirst = false});

  /// How long a cached value stays usable.
  ///
  /// Null means *session*: valid until the app restarts or the value is
  /// invalidated explicitly. A session TTL is right for data the app is told
  /// about when it changes — writing a TTL for it would mean re-fetching
  /// something already known to be current.
  final Duration? ttl;

  /// Whether to try the network first and fall back to cache.
  ///
  /// True for the two household-shared collections, where a partner's change
  /// matters more than instant paint. False elsewhere, where painting from cache
  /// immediately and refreshing behind it is the better trade.
  final bool isNetworkFirst;

  /// Whether a value written at [writtenAt] is still usable [now].
  bool isFresh({required DateTime writtenAt, required DateTime now}) {
    final Duration? ttl = this.ttl;
    if (ttl == null) {
      // Session-scoped: freshness is decided by the cache being cleared on
      // launch, not by elapsed time.
      return true;
    }
    return now.difference(writtenAt) < ttl;
  }

  /// The key prefix under which entries for this policy are stored.
  String get keyPrefix => 'cache.$name.';
}
