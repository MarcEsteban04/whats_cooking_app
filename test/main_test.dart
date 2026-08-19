import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/main.dart';

void main() {
  testWidgets('app boots through ProviderScope onto the router', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WhatsCookingApp()));
    await tester.pumpAndSettle();

    // Proves the whole wiring assembles: the ProviderScope resolves
    // appRouterProvider, GoRouter runs its guard from the initial `/splash`
    // location, and a screen reaches the tree.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('a cold start with no session lands on Welcome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WhatsCookingApp()));
    await tester.pumpAndSettle();

    // The guard's signed-out path, end to end: splash has nothing to restore,
    // so it moves on rather than sitting there (docs/NAVIGATION_MAP.md §2).
    expect(find.text('Welcome'), findsOneWidget);
  });
}
