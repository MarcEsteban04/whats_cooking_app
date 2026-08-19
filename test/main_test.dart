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

    // Proves the whole Sprint 06 wiring assembles: the ProviderScope resolves
    // appRouterProvider, GoRouter builds its initial location, and the route's
    // widget reaches the tree. Sprint 09 replaces this placeholder with the
    // splash route.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text("What's Cooking?"), findsOneWidget);
  });
}
