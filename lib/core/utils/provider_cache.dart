import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Caching for `autoDispose` providers (Sprint 27).
extension ProviderCache on Ref {
  /// Keeps this provider's value for [duration] after the last listener leaves.
  ///
  /// The middle ground between the two settings a provider otherwise has, and
  /// both of those are wrong for a screen you step in and out of. `autoDispose`
  /// re-fetches every time — tap a meal, read it, go back, tap it again, and the
  /// ingredients arrive from the network twice for no reason. `keepAlive` never
  /// lets go, so every meal a user browsed in this session sits in memory until
  /// the app closes.
  ///
  /// A window instead: still cached while the reader is bouncing between a list
  /// and the thing they tapped, gone by the time they have moved on. It is not a
  /// cache in the store-and-invalidate sense — nothing is written anywhere, and
  /// `ref.invalidate` still works exactly as before, which is what the meal form
  /// relies on after a save.
  ///
  /// Deliberately not applied to writes or to anything a stale answer would
  /// misreport. The favourite and dislike sets are `keepAlive` and updated in
  /// place, so they are never read from here.
  void cacheFor(Duration duration) {
    final KeepAliveLink link = keepAlive();
    final Timer timer = Timer(duration, link.close);

    // Cancelled if the provider is disposed some other way first — an explicit
    // `invalidate`, or the container going down. Without this the timer fires
    // against a closed link during a test's tear-down.
    onDispose(timer.cancel);
  }
}

/// How long a read stays cached.
///
/// Long enough to cover going back and tapping the same meal again, or
/// re-opening a list you just left; short enough that a household editing its
/// own recipes on two devices is not reading minutes-old data. Nothing measured
/// this — it is a judgement, and the number to change if the app ever feels
/// stale rather than slow.
const Duration kReadCacheWindow = Duration(seconds: 45);
