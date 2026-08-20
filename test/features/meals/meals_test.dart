import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';
import 'package:whats_cooking/core/theme/theme.dart';
import 'package:whats_cooking/core/widgets/cards/meal_card.dart';
import 'package:whats_cooking/core/widgets/chips/app_filter_chip.dart';
import 'package:whats_cooking/features/meals/data/repositories/in_memory_meal_repository.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_draft.dart';
import 'package:whats_cooking/features/meals/domain/entities/meal_query.dart';
import 'package:whats_cooking/features/meals/domain/repositories/meal_repository.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meal_repository_provider.dart';
import 'package:whats_cooking/features/meals/presentation/providers/meals_controller.dart';
import 'package:whats_cooking/features/meals/presentation/screens/meals_screen.dart';

import '../../support/component_harness.dart';

/// Meal discovery (Sprint 22): the feed, search, filters, sorting, pagination.
void main() {
  late InMemoryMealRepository repository;
  late ProviderContainer container;

  setUp(() {
    // No simulated latency in the unit tests. The widget tests below set their
    // own and pump past it.
    repository = InMemoryMealRepository(latency: Duration.zero);
    container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  MealsController controller() =>
      container.read(mealsControllerProvider.notifier);

  Future<MealPage> search(MealQuery query, {int offset = 0, int limit = 20}) =>
      repository.search(query: query, offset: offset, limit: limit);

  group('Meal decodes a PostgREST row', () {
    Map<String, dynamic> row({
      String cuisine = 'filipino',
      String category = 'dinner',
      List<String> dietary = const <String>[],
    }) {
      return <String, dynamic>{
        'id': 'row-1',
        'name': 'Chicken Adobo',
        'description': 'Soy, vinegar, garlic.',
        'image_url': null,
        'cuisine': cuisine,
        'category': category,
        'difficulty': 'easy',
        'cooking_time_minutes': 45,
        'estimated_cost': 260,
        'servings': 4,
        'calories': 520,
        'instructions': <String>['Marinate.', 'Sear.', 'Simmer.'],
        'dietary_tags': dietary,
        'tags': <String>['comfort'],
      };
    }

    test('reads every field the feed and the detail screen need', () {
      final Meal meal = Meal.fromRow(row());

      expect(meal.name, 'Chicken Adobo');
      expect(meal.cuisine, Cuisine.filipino);
      expect(meal.category, MealCategory.dinner);
      expect(meal.difficulty, Difficulty.easy);
      expect(meal.cookingTimeMinutes, 45);
      expect(meal.estimatedCost, 260);
      expect(meal.servings, 4);
      expect(meal.instructions, hasLength(3));
      expect(meal.tags, contains('comfort'));
    });

    test('cost per serving is the number every budget question means', () {
      // 260 pesos feeding four is not the same price as 260 feeding two, and
      // every budget filter in the app compares per head.
      expect(Meal.fromRow(row()).costPerServing, 65);
    });

    test('an unknown cuisine hides one meal, not the whole page', () {
      // A cuisine added to the database before the app ships a build that knows
      // it would otherwise throw and take the entire feed down.
      final Meal meal = Meal.fromRow(row(cuisine: 'martian'));

      expect(meal.cuisine, Cuisine.other);
      expect(meal.name, 'Chicken Adobo');
    });

    test('an unknown dietary tag is dropped, never guessed', () {
      // The one place guessing is dangerous. A tag the app cannot interpret must
      // not become a tag it thinks it understands.
      final Meal meal = Meal.fromRow(
        row(dietary: <String>['vegan', 'not_a_real_tag']),
      );

      expect(meal.dietaryTags, <DietaryTag>{DietaryTag.vegan});
    });
  });

  group('MealQuery', () {
    test('toggling a filter adds it, toggling again removes it', () {
      const MealQuery empty = MealQuery();
      final MealQuery one = empty.toggleCuisine(Cuisine.korean);

      expect(one.cuisines, <Cuisine>{Cuisine.korean});
      expect(one.toggleCuisine(Cuisine.korean).cuisines, isEmpty);
    });

    test('equality is by value, so an unchanged query is detectable', () {
      // The controller skips the round trip when the query has not changed, and
      // that only works if two equal queries compare equal.
      const MealQuery a = MealQuery(
        search: 'adobo',
        cuisines: <Cuisine>{Cuisine.filipino, Cuisine.korean},
      );
      const MealQuery b = MealQuery(
        search: 'adobo',
        cuisines: <Cuisine>{Cuisine.korean, Cuisine.filipino},
      );

      expect(a, b, reason: 'set order should not matter');
      expect(a.copyWith(search: 'sinigang'), isNot(a));
    });

    test('clearing keeps the sort and drops the filters', () {
      // A sort is a preference about reading the feed, not a filter hiding food.
      const MealQuery query = MealQuery(
        search: 'adobo',
        sort: MealSort.cheapest,
        maxCostPerServing: 80,
      );

      final MealQuery cleared = query.cleared();

      expect(cleared.hasFilters, isFalse);
      expect(cleared.sort, MealSort.cheapest);
    });

    test('a cleared limit differs from an unset one', () {
      const MealQuery query = MealQuery(maxCostPerServing: 100);

      expect(query.copyWith(clearMaxCost: true).maxCostPerServing, isNull);
      expect(query.copyWith().maxCostPerServing, 100);
    });

    test('the narrowest filter is named for the empty state', () {
      // docs/USER_FLOWS.md §7: an empty result offers to relax the narrowest
      // filter. Naming which one is what makes it one tap out of a dead end.
      expect(const MealQuery().narrowestFilterLabel, isNull);
      expect(
        const MealQuery(search: 'pizzza').narrowestFilterLabel,
        contains('pizzza'),
      );
      expect(
        const MealQuery(cuisines: <Cuisine>{Cuisine.korean})
            .narrowestFilterLabel,
        contains('Korean'),
      );
    });
  });

  group('the repository filters on the server', () {
    test('search matches the name, case-insensitively', () async {
      final MealPage page = await search(const MealQuery(search: 'ADOBO'));

      expect(page.meals, hasLength(1));
      expect(page.meals.single.name, 'Chicken Adobo');
    });

    test(
      'search that matches nothing returns an empty page, not an error',
      () async {
        final MealPage page = await search(const MealQuery(search: 'zzz'));

        expect(page.meals, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );

    test('cuisine and category filters are additive', () async {
      final MealPage filipino = await search(
        const MealQuery(cuisines: <Cuisine>{Cuisine.filipino}),
      );
      expect(
        filipino.meals.every((Meal m) => m.cuisine == Cuisine.filipino),
        isTrue,
      );

      final MealPage both = await search(
        const MealQuery(
          cuisines: <Cuisine>{Cuisine.filipino},
          categories: <MealCategory>{MealCategory.dessert},
        ),
      );

      expect(both.meals, hasLength(lessThan(filipino.meals.length)));
      expect(
        both.meals.every(
          (Meal m) =>
              m.cuisine == Cuisine.filipino &&
              m.category == MealCategory.dessert,
        ),
        isTrue,
      );
    });

    test('the quick filter is a ceiling on cooking time', () async {
      final MealPage page = await search(
        const MealQuery(maxCookingTimeMinutes: 20),
      );

      expect(page.meals, isNotEmpty);
      expect(page.meals.every((Meal m) => m.cookingTimeMinutes <= 20), isTrue);
    });

    test('the budget filter is per head, not per recipe', () async {
      // The distinction that makes the filter honest: a 320-peso meal for four
      // is inside a 100-peso budget and a 160-peso meal for two is not.
      final MealPage page = await search(
        const MealQuery(maxCostPerServing: 60),
      );

      expect(page.meals, isNotEmpty);
      expect(page.meals.every((Meal m) => m.costPerServing <= 60), isTrue);
      expect(
        page.meals.any((Meal m) => m.estimatedCost > 60),
        isTrue,
        reason: 'a cheap-per-head meal can still cost more than 60 in total',
      );
    });
  });

  group('sorting', () {
    test(
      'alphabetical, quickest and cheapest each order by their own key',
      () async {
        final List<Meal> byName = (await search(const MealQuery())).meals;
        expect(
          byName.map((Meal m) => m.name).toList(),
          equals(List<String>.from(byName.map((Meal m) => m.name))..sort()),
        );

        final List<Meal> byTime = (await search(
          const MealQuery(sort: MealSort.quickest),
        )).meals;
        for (int i = 1; i < byTime.length; i++) {
          expect(
            byTime[i].cookingTimeMinutes,
            greaterThanOrEqualTo(byTime[i - 1].cookingTimeMinutes),
          );
        }

        final List<Meal> byCost = (await search(
          const MealQuery(sort: MealSort.cheapest),
        )).meals;
        for (int i = 1; i < byCost.length; i++) {
          expect(
            byCost[i].costPerServing,
            greaterThanOrEqualTo(byCost[i - 1].costPerServing),
          );
        }
      },
    );

    test('every sort is a total order, so paging cannot duplicate a meal', () async {
      // `List.sort` is not stable in Dart. Without the id tiebreaker, two meals
      // sharing a cooking time can swap places between the request for page one
      // and the request for page two — the reader sees one twice and never sees
      // another at all.
      for (final MealSort sort in MealSort.values) {
        final List<String> first = await _idsFor(sort);
        final List<String> second = await _idsFor(sort);

        expect(first, isNotEmpty, reason: sort.name);
        expect(first, second, reason: sort.name);
      }
    });
  });

  group('pagination', () {
    test('pages tile the result set with no gaps and no repeats', () async {
      const int size = 5;
      final List<String> seen = <String>[];
      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        final MealPage page = await search(
          const MealQuery(),
          offset: offset,
          limit: size,
        );
        seen.addAll(page.meals.map((Meal m) => m.id));
        offset += page.meals.length;
        hasMore = page.hasMore;

        expect(page.meals, hasLength(lessThanOrEqualTo(size)));
      }

      final MealPage all = await search(const MealQuery(), limit: 500);

      expect(seen, all.meals.map((Meal m) => m.id).toList());
      expect(seen.toSet(), hasLength(seen.length), reason: 'no repeats');
    });

    test('hasMore is false on the page that ends the list', () async {
      final MealPage all = await search(const MealQuery(), limit: 500);
      final MealPage exact = await search(
        const MealQuery(),
        limit: all.meals.length,
      );

      expect(
        exact.hasMore,
        isFalse,
        reason: 'asking for exactly the whole list should not promise more',
      );
    });
  });

  group('the controller', () {
    test('loads the first page on build', () async {
      final MealFeed feed = await container.read(
        mealsControllerProvider.future,
      );

      expect(feed.meals, isNotEmpty);
      expect(feed.query, const MealQuery());
    });

    test('a new query reloads from the first page', () async {
      await container.read(mealsControllerProvider.future);

      await controller().toggleCategory(MealCategory.dessert);
      final MealFeed feed = container.read(mealsControllerProvider).value!;

      expect(feed.query.categories, <MealCategory>{MealCategory.dessert});
      expect(
        feed.meals.every((Meal m) => m.category == MealCategory.dessert),
        isTrue,
      );
    });

    test('an unchanged query does not re-fetch', () async {
      // The search field reports the same text when a keystroke is typed and
      // undone inside the debounce window, and re-querying for it flickers the
      // list for nothing.
      final MealFeed first = await container.read(
        mealsControllerProvider.future,
      );

      await controller().search('');

      expect(
        container.read(mealsControllerProvider).value,
        same(first),
        reason: 'the same feed object, not merely an equal one',
      );
    });

    test('loadMore appends rather than replacing', () async {
      final ProviderContainer paged = ProviderContainer(
        overrides: [
          mealRepositoryProvider.overrideWithValue(
            _SmallPageRepository(repository),
          ),
        ],
      );
      addTearDown(paged.dispose);

      final MealFeed first = await paged.read(mealsControllerProvider.future);
      expect(first.meals, hasLength(_SmallPageRepository.pageSize));
      expect(first.hasMore, isTrue);

      await paged.read(mealsControllerProvider.notifier).loadMore();
      final MealFeed second = paged.read(mealsControllerProvider).value!;

      expect(second.meals, hasLength(greaterThan(first.meals.length)));
      expect(
        second.meals.take(first.meals.length),
        first.meals,
        reason: 'the pages already read must stay where they were',
      );
      expect(
        second.meals.map((Meal m) => m.id).toSet(),
        hasLength(second.meals.length),
      );
    });

    test('loadMore does nothing when there is no further page', () async {
      final MealFeed feed = await container.read(
        mealsControllerProvider.future,
      );
      expect(feed.hasMore, isFalse, reason: 'the sample fits in one page');

      await controller().loadMore();

      expect(container.read(mealsControllerProvider).value, same(feed));
    });

    test('a failed page keeps the pages that worked', () async {
      // A failed third page must not discard the two that loaded. The screen
      // shows a retry at the foot of the list it already has.
      final _SmallPageRepository paging = _SmallPageRepository(repository);
      final ProviderContainer paged = ProviderContainer(
        overrides: [mealRepositoryProvider.overrideWithValue(paging)],
      );
      addTearDown(paged.dispose);

      final MealFeed first = await paged.read(mealsControllerProvider.future);
      paging.failNext = true;

      await paged.read(mealsControllerProvider.notifier).loadMore();
      final MealFeed after = paged.read(mealsControllerProvider).value!;

      expect(after.meals, first.meals);
      expect(after.loadMoreFailure, isNotNull);
      expect(after.isLoadingMore, isFalse);
    });

    test('a read failure surfaces as an error state', () async {
      repository.failReads = true;

      // Subscribed and pumped rather than awaiting `.future`: awaiting the
      // future of a keepAlive provider whose build throws never returns, so the
      // test times out instead of failing.
      final ProviderSubscription<AsyncValue<MealFeed>> subscription = container
          .listen(mealsControllerProvider, (_, _) {});
      addTearDown(subscription.close);

      await pumpEventQueue();

      expect(container.read(mealsControllerProvider).hasError, isTrue);
    });

    test('reloading keeps the previous list on screen', () async {
      // The screen dims what it has rather than replacing it with a skeleton. A
      // filter tap that blanks the list makes an instant interaction feel slow.
      final _SlowRepository slow = _SlowRepository(repository);
      final ProviderContainer container2 = ProviderContainer(
        overrides: [mealRepositoryProvider.overrideWithValue(slow)],
      );
      addTearDown(container2.dispose);

      await container2.read(mealsControllerProvider.future);

      slow.gate = Completer<void>();
      final Future<void> pending = container2
          .read(mealsControllerProvider.notifier)
          .toggleCategory(MealCategory.dessert);

      final MealFeed during = container2.read(mealsControllerProvider).value!;
      expect(during.isReloading, isTrue);
      expect(during.meals, isNotEmpty, reason: 'the old list is still there');

      slow.gate!.complete();
      await pending;

      expect(
        container2.read(mealsControllerProvider).value!.isReloading,
        isFalse,
      );
    });
  });

  group('the Meals screen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      double textScale = 1,
      Size? surfaceSize,
    }) async {
      if (surfaceSize != null) {
        tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
                size: surfaceSize ?? const Size(400, 800),
              ),
              child: const MealsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testInBothThemes('shows the feed once it loads', (
      WidgetTester tester,
      Brightness brightness,
    ) async {
      await pumpScreen(tester, brightness: brightness);

      expect(find.text('Meals'), findsOneWidget);
      expect(find.byType(MealCard), findsWidgets);
      expect(find.text('Beef and Broccoli'), findsOneWidget);
    });

    testWidgets('a filter pill narrows the feed', (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Beef and Broccoli'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppFilterChip, 'Desserts'));
      await tester.pumpAndSettle();

      expect(find.text('Turon'), findsOneWidget);
      expect(find.text('Beef and Broccoli'), findsNothing);
    });

    testWidgets('clearing brings the whole catalogue back', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(AppFilterChip, 'Desserts'));
      await tester.pumpAndSettle();
      expect(find.text('Beef and Broccoli'), findsNothing);

      await tester.tap(find.textContaining('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Beef and Broccoli'), findsOneWidget);
    });

    testWidgets('searching filters after the debounce, not on each keystroke', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'turon');
      await tester.pump();

      expect(
        find.text('Beef and Broccoli'),
        findsOneWidget,
        reason: 'not yet — the field debounces at 300 ms',
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Turon'), findsOneWidget);
      expect(find.text('Beef and Broccoli'), findsNothing);
    });

    testWidgets('an empty result names the filter to relax', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'sushi burrito');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.textContaining('sushi burrito'), findsWidgets);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (WidgetTester tester) async {
      repository.failReads = true;

      await pumpScreen(tester);

      expect(find.text('Try Again'), findsOneWidget);

      repository.failReads = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.byType(MealCard), findsWidgets);
    });

    testWidgets('says when the list has ended', (WidgetTester tester) async {
      // Rather than leaving the reader to wonder whether more is loading.
      await pumpScreen(tester);
      await tester.scrollUntilVisible(
        find.textContaining('That is all'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.textContaining('That is all'), findsOneWidget);
    });

    testWidgets('survives 1.3x scale on a 320 px screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        textScale: AppTypography.maxTextScale,
        surfaceSize: kSmallPhone,
      );

      expectNoOverflow(tester);
    });
  });
}

/// The ids a sort produces, from a fresh repository.
///
/// Called twice per sort so the comparison is between two independent runs
/// rather than between a list and itself.
Future<List<String>> _idsFor(MealSort sort) async {
  final InMemoryMealRepository repository = InMemoryMealRepository(
    latency: Duration.zero,
  );
  final MealPage page = await repository.search(
    query: MealQuery(sort: sort),
    limit: 500,
  );
  return page.meals.map((Meal meal) => meal.id).toList();
}

/// Wraps a repository with a page size small enough to need several pages.
class _SmallPageRepository implements MealRepository {
  _SmallPageRepository(this._inner);

  final MealRepository _inner;

  /// Makes the next call throw, for the failed-page case.
  bool failNext = false;

  static const int pageSize = 4;

  @override
  Future<MealPage> search({
    required MealQuery query,
    int offset = 0,
    int limit = kMealPageSize,
  }) async {
    if (failNext) {
      failNext = false;
      throw Exception('page failed');
    }
    return _inner.search(query: query, offset: offset, limit: pageSize);
  }

  @override
  Future<Meal> create(MealDraft draft) => _inner.create(draft);
}

/// A repository whose reads can be held open, for observing the reloading state.
class _SlowRepository implements MealRepository {
  _SlowRepository(this._inner);

  final MealRepository _inner;

  /// Completed by the test to let the pending read finish.
  Completer<void>? gate;

  @override
  Future<MealPage> search({
    required MealQuery query,
    int offset = 0,
    int limit = kMealPageSize,
  }) async {
    if (gate case final Completer<void> pending) {
      await pending.future;
      gate = null;
    }
    return _inner.search(query: query, offset: offset, limit: limit);
  }

  @override
  Future<Meal> create(MealDraft draft) => _inner.create(draft);
}
