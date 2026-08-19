import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/utils/formatters.dart';

void main() {
  group('AppFormat.peso', () {
    test('drops the fraction, because costs are estimates', () {
      expect(AppFormat.peso(180), '₱180');
      expect(AppFormat.peso(220.4), '₱220');
    });

    test('groups thousands', () {
      expect(AppFormat.peso(1250), '₱1,250');
    });

    test('handles zero', () {
      expect(AppFormat.peso(0), '₱0');
    });
  });

  group('AppFormat.cookingTime', () {
    test('minutes below an hour', () {
      expect(AppFormat.cookingTime(30), '30 min');
      expect(AppFormat.cookingTime(59), '59 min');
    });

    test('a whole hour drops the minutes', () {
      expect(AppFormat.cookingTime(60), '1 hr');
      expect(AppFormat.cookingTime(120), '2 hr');
    });

    test('hours and minutes together', () {
      expect(AppFormat.cookingTime(90), '1 hr 30 min');
      expect(AppFormat.cookingTime(245), '4 hr 5 min');
    });
  });

  group('AppFormat plurals', () {
    test('servings', () {
      expect(AppFormat.servings(1), '1 serving');
      expect(AppFormat.servings(2), '2 servings');
    });

    test('people', () {
      expect(AppFormat.people(1), '1 person');
      expect(AppFormat.people(2), '2 people');
    });
  });

  group('AppFormat.metadata', () {
    test('joins with the interpunct the design uses', () {
      expect(
        AppFormat.metadata(<String?>['Japanese', '30 min', '₱220']),
        'Japanese · 30 min · ₱220',
      );
    });

    test(
      'drops nulls and empties rather than leaving a dangling separator',
      () {
        expect(
          AppFormat.metadata(<String?>['Japanese', null, '', '₱220']),
          'Japanese · ₱220',
        );
      },
    );

    test('an all-empty list yields an empty string, not a separator', () {
      expect(AppFormat.metadata(<String?>[null, '']), isEmpty);
    });
  });

  group('AppFormat.percent', () {
    test('rounds to whole percent', () {
      expect(AppFormat.percent(1), '100%');
      expect(AppFormat.percent(0.857), '86%');
      expect(AppFormat.percent(0), '0%');
    });
  });
}
