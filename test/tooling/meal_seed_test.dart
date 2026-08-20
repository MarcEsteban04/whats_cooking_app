import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_cooking/core/domain/food_taxonomy.dart';

/// Checks the catalogue seed in `supabase/seed/` without a database.
///
/// `supabase/seed/04_verify_seed.sql` asks the same questions of a live
/// Postgres, and it is the authority once the seed has been applied. This asks
/// them of the *files*, which is the only place they can be answered before
/// someone pastes 400 rows into a production SQL editor. A cuisine the Dart
/// enums do not know, a misspelt ingredient, a vegan meal with fish sauce in
/// it — all of those are cheaper to find here.
///
/// It is not a parser for SQL in general. It reads the one shape these files
/// use: parenthesised `values` rows whose first field is a quoted string.
void main() {
  final Directory seed = Directory('supabase/seed');

  late List<_Ingredient> ingredients;
  late List<_Meal> meals;
  late List<_Link> links;

  setUpAll(() {
    ingredients = _read(seed, '01_ingredients.sql')
        .where((List<String> row) => row.length == 3 || row.length == 4)
        .map(_Ingredient.fromRow)
        .toList();

    meals = _read(seed, '02_meals.sql')
        .where((List<String> row) => row.length == _Meal.fieldCount)
        .map(_Meal.fromRow)
        .toList();

    links = _read(
      seed,
      '03_meal_ingredients.sql',
    ).where((List<String> row) => row.length == 5).map(_Link.fromRow).toList();
  });

  group('the files parse into the catalogue they claim to hold', () {
    test('every file yields rows', () {
      // A silent parse failure would make every check below vacuously true,
      // which is the one way this file could lie.
      expect(ingredients, hasLength(greaterThan(100)));
      expect(meals, hasLength(greaterThanOrEqualTo(60)));
      expect(links, hasLength(greaterThan(300)));
    });
  });

  group('the vocabulary matches the Dart enums', () {
    // docs/food_taxonomy: "Every value mirrors a database constraint. A
    // mismatch is a failed insert rather than a silent shrug." That holds only
    // while the seed and the enums agree, and nothing else checks that they do.
    test('every cuisine is one the app knows', () {
      for (final _Meal meal in meals) {
        expect(
          Cuisine.fromValue(meal.cuisine),
          isNotNull,
          reason: '${meal.name}: unknown cuisine "${meal.cuisine}"',
        );
      }
    });

    test('every meal category is one the schema accepts', () {
      const Set<String> categories = <String>{
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'dessert',
      };

      for (final _Meal meal in meals) {
        expect(
          categories,
          contains(meal.category),
          reason: '${meal.name}: unknown category "${meal.category}"',
        );
      }
    });

    test('every difficulty is one the schema accepts', () {
      for (final _Meal meal in meals) {
        expect(
          <String>{'easy', 'medium', 'hard'},
          contains(meal.difficulty),
          reason: '${meal.name}: unknown difficulty "${meal.difficulty}"',
        );
      }
    });

    test('every dietary tag is one the app knows', () {
      final Set<String> known = DietaryTag.values
          .map((DietaryTag tag) => tag.value)
          .toSet();

      for (final _Meal meal in meals) {
        for (final String tag in meal.dietaryTags) {
          expect(known, contains(tag), reason: '${meal.name}: "$tag"');
        }
      }
    });

    test('every unit comes from the fixed set', () {
      // docs/DATABASE.md §4.6. A stray unit breaks the grocery list's ability
      // to add two quantities together (Sprint 50).
      const Set<String> units = <String>{'g', 'ml', 'pc', 'tbsp', 'tsp', 'cup'};

      for (final _Ingredient ingredient in ingredients) {
        expect(
          units,
          contains(ingredient.unit),
          reason: '${ingredient.name}: "${ingredient.unit}"',
        );
      }
      for (final _Link link in links) {
        expect(
          units,
          contains(link.unit),
          reason: '${link.mealName} / ${link.ingredientName}: "${link.unit}"',
        );
      }
    });
  });

  group('the three files agree with each other', () {
    test('every ingredient a recipe names exists in the vocabulary', () {
      // 03 left-joins so an unmatched name fails the insert loudly rather than
      // dropping the row. This catches the same mistake without a database.
      final Set<String> known = ingredients
          .map((_Ingredient ingredient) => ingredient.name)
          .toSet();

      for (final _Link link in links) {
        expect(
          known,
          contains(link.ingredientName),
          reason: '${link.mealName} names "${link.ingredientName}"',
        );
      }
    });

    test('every meal a recipe names exists in the catalogue', () {
      final Set<String> known = meals
          .map((_Meal meal) => meal.name.toLowerCase())
          .toSet();

      for (final _Link link in links) {
        expect(
          known,
          contains(link.mealName.toLowerCase()),
          reason: 'no such meal: "${link.mealName}"',
        );
      }
    });

    test('no meal is named twice', () {
      // Migration 0014 enforces this in the database. Here it is a typo check:
      // two rows with one name means the second silently overwrites the first.
      final Set<String> seen = <String>{};

      for (final _Meal meal in meals) {
        expect(
          seen.add(meal.name.toLowerCase()),
          isTrue,
          reason: 'duplicate: ${meal.name}',
        );
      }
    });

    test('no ingredient is listed twice for the same meal', () {
      final Set<String> seen = <String>{};

      for (final _Link link in links) {
        final String key =
            '${link.mealName.toLowerCase()}/${link.ingredientName}';
        expect(seen.add(key), isTrue, reason: 'duplicate: $key');
      }
    });
  });

  group('every meal is complete enough to cook', () {
    test('three steps or more', () {
      for (final _Meal meal in meals) {
        expect(
          meal.steps,
          greaterThanOrEqualTo(3),
          reason: '${meal.name} has ${meal.steps}',
        );
      }
    });

    test('two required ingredients or more', () {
      // Two, not three. Tortang talong is an eggplant and an egg, and padding
      // it to reach a threshold would be worse data than the threshold is
      // worth. The precise net for a misspelt ingredient is the vocabulary
      // check above, which names the offending row; this is only a floor
      // against a meal that lost its list entirely.
      final Map<String, int> required = <String, int>{};
      for (final _Link link in links.where((_Link l) => !l.isOptional)) {
        required.update(
          link.mealName.toLowerCase(),
          (int n) => n + 1,
          ifAbsent: () => 1,
        );
      }

      for (final _Meal meal in meals) {
        expect(
          required[meal.name.toLowerCase()] ?? 0,
          greaterThanOrEqualTo(2),
          reason: meal.name,
        );
      }
    });

    test('a description worth reading', () {
      for (final _Meal meal in meals) {
        expect(
          meal.description.length,
          greaterThanOrEqualTo(20),
          reason: meal.name,
        );
      }
    });

    test('at least one mood tag', () {
      // The tags are what "surprise me" and the mood filters read
      // (docs/USER_FLOWS.md §6).
      for (final _Meal meal in meals) {
        expect(meal.tags, isNotEmpty, reason: meal.name);
      }
    });

    test('plausible cost and time', () {
      for (final _Meal meal in meals) {
        expect(
          meal.cost,
          inInclusiveRange(50, 1500),
          reason: '${meal.name} costs ${meal.cost}',
        );
        expect(
          meal.minutes,
          inInclusiveRange(5, 240),
          reason: '${meal.name} takes ${meal.minutes} minutes',
        );
        expect(meal.servings, inInclusiveRange(1, 12), reason: meal.name);
      }
    });
  });

  group('the catalogue is broad enough to spin', () {
    // Sprint 30 filters by cuisine, budget, time and diet at once, and Sprint
    // 32 refuses repeats. A spin that finds nothing is the one failure this
    // product cannot survive, so the pool has to survive several filters
    // intersecting.
    test('at least 60 meals', () {
      expect(meals, hasLength(greaterThanOrEqualTo(60)));
    });

    test('Filipino is at least a quarter of it', () {
      // docs/MVP_SCOPE.md: "Filipino-leaning".
      final int filipino = meals
          .where((_Meal meal) => meal.cuisine == 'filipino')
          .length;

      expect(filipino * 4, greaterThanOrEqualTo(meals.length));
    });

    test('no cuisine or category is thinner than four', () {
      for (final MapEntry<String, int> entry in <String, int>{
        ..._countBy(meals, (_Meal meal) => meal.cuisine),
      }.entries) {
        expect(entry.value, greaterThanOrEqualTo(4), reason: entry.key);
      }

      final Map<String, int> byCategory = _countBy(
        meals,
        (_Meal meal) => meal.category,
      );
      expect(byCategory.keys, hasLength(5));
      for (final MapEntry<String, int> entry in byCategory.entries) {
        expect(entry.value, greaterThanOrEqualTo(4), reason: entry.key);
      }
    });

    test('the quick and cheap filters both land on something', () {
      expect(
        meals.where((_Meal meal) => meal.minutes <= 30).length,
        greaterThanOrEqualTo(12),
      );
      expect(
        meals.where((_Meal meal) => meal.cost / meal.servings <= 100).length,
        greaterThanOrEqualTo(12),
      );
    });

    test('a vegetarian can spin', () {
      expect(
        meals.where((_Meal m) => m.dietaryTags.contains('vegetarian')).length,
        greaterThanOrEqualTo(6),
      );
    });
  });

  group('dietary tags tell the truth', () {
    // These are the checks that matter most. Dietary tags are a hard filter,
    // never a penalty — a wrong one does not skew a score, it offers someone
    // food they will not eat.
    //
    // The lists are spelled out rather than derived from an ingredient's
    // category, because category is about where a thing sits in a shop and this
    // question is about what it came from. Tofu and milk are not the same
    // answer.
    const Set<String> flesh = <String>{
      'chicken thigh',
      'chicken breast',
      'whole chicken',
      'chicken wing',
      'chicken liver',
      'pork belly',
      'pork shoulder',
      'pork ribs',
      'ground pork',
      'beef sirloin',
      'ground beef',
      'oxtail',
      'beef tripe',
      'bacon',
    };
    const Set<String> seafood = <String>{
      'salmon fillet',
      'canned tuna',
      'shrimp',
      'anchovy',
      'shrimp paste',
      'fish sauce',
      'oyster sauce',
    };
    const Set<String> fromAnimals = <String>{
      'egg',
      'milk',
      'butter',
      'cheddar cheese',
      'mozzarella cheese',
      'parmesan cheese',
      'mascarpone',
      'condensed milk',
      'evaporated milk',
      'honey',
    };
    const Set<String> wheat = <String>{
      'all-purpose flour',
      'bread flour',
      'spaghetti',
      'macaroni',
      'egg noodles',
      'panko breadcrumbs',
      'wonton wrapper',
      'lumpia wrapper',
      'burger bun',
      'ladyfinger biscuit',
      'soy sauce',
    };

    /// Every ingredient name a meal uses, optional ones included — a garnish
    /// still breaks a diet.
    Set<String> usedBy(_Meal meal) => links
        .where(
          (_Link link) =>
              link.mealName.toLowerCase() == meal.name.toLowerCase(),
        )
        .map((_Link link) => link.ingredientName)
        .toSet();

    void expectNoneOf(String tag, Set<String> forbidden, String why) {
      for (final _Meal meal in meals.where(
        (_Meal meal) => meal.dietaryTags.contains(tag),
      )) {
        final Set<String> offending = usedBy(meal).intersection(forbidden);
        expect(
          offending,
          isEmpty,
          reason: '${meal.name} is tagged $tag but $why: $offending',
        );
      }
    }

    test('vegetarian meals contain no meat or fish', () {
      expectNoneOf('vegetarian', <String>{
        ...flesh,
        ...seafood,
      }, 'contains animal flesh');
    });

    test('vegan meals contain nothing from an animal', () {
      expectNoneOf('vegan', <String>{
        ...flesh,
        ...seafood,
        ...fromAnimals,
      }, 'contains an animal product');
    });

    test('pescatarian meals contain no meat', () {
      expectNoneOf('pescatarian', flesh, 'contains meat');
    });

    test('gluten-free meals contain no wheat', () {
      // Tortilla is deliberately absent: corn and wheat tortillas share a name
      // and the catalogue does not distinguish them yet. No gluten-free meal
      // uses one, so the gap costs nothing today — but it is the first thing to
      // fix if one ever does.
      expectNoneOf('gluten_free', wheat, 'contains wheat');
    });

    test('every vegan meal is tagged vegetarian too', () {
      // A user who filtered on vegetarian and was denied a vegan meal would be
      // right to find that strange.
      for (final _Meal meal in meals.where(
        (_Meal meal) => meal.dietaryTags.contains('vegan'),
      )) {
        expect(meal.dietaryTags, contains('vegetarian'), reason: meal.name);
      }
    });
  });

  group('the ingredient vocabulary', () {
    test('the staples are marked, and only the staples', () {
      // docs/USER_FLOWS.md §12. Too few and every match reads low for want of
      // an onion; too many and a 100% match promises a meal nobody can cook.
      final List<String> staples = ingredients
          .where((_Ingredient ingredient) => ingredient.isStaple)
          .map((_Ingredient ingredient) => ingredient.name)
          .toList();

      expect(staples, hasLength(inInclusiveRange(8, 12)));
      expect(staples, contains('salt'));
      expect(staples, contains('cooking oil'));
      expect(staples, isNot(contains('chicken thigh')));
    });

    test('names are lowercase, as the schema requires', () {
      // `check (name = lower(trim(name)))` on the table.
      for (final _Ingredient ingredient in ingredients) {
        expect(ingredient.name, ingredient.name.toLowerCase().trim());
      }
    });

    test('no ingredient is declared twice', () {
      final Set<String> seen = <String>{};
      for (final _Ingredient ingredient in ingredients) {
        expect(seen.add(ingredient.name), isTrue, reason: ingredient.name);
      }
    });

    test('the vocabulary has not drifted far ahead of the catalogue', () {
      // `ingredients` is append-only and Sprint 26's custom meals will use
      // entries the catalogue does not, so a few unused names are expected.
      // Many would mean the two files have stopped being edited together.
      final Set<String> used = links
          .map((_Link link) => link.ingredientName)
          .toSet();
      final List<String> unused = ingredients
          .map((_Ingredient ingredient) => ingredient.name)
          .where((String name) => !used.contains(name))
          .toList();

      expect(unused, hasLength(lessThan(20)), reason: unused.join(', '));
    });
  });
}

Map<String, int> _countBy<T>(List<T> items, String Function(T) key) {
  final Map<String, int> counts = <String, int>{};
  for (final T item in items) {
    counts.update(key(item), (int n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

class _Ingredient {
  _Ingredient(this.name, this.category, this.unit, this.isStaple);

  factory _Ingredient.fromRow(List<String> row) => _Ingredient(
    _unquote(row[0]),
    _unquote(row[1]),
    _unquote(row[2]),
    row.length > 3 && row[3].trim() == 'true',
  );

  final String name;
  final String category;
  final String unit;
  final bool isStaple;
}

class _Meal {
  _Meal({
    required this.name,
    required this.description,
    required this.cuisine,
    required this.category,
    required this.difficulty,
    required this.minutes,
    required this.cost,
    required this.servings,
    required this.steps,
    required this.dietaryTags,
    required this.tags,
  });

  factory _Meal.fromRow(List<String> row) => _Meal(
    name: _unquote(row[0]),
    description: _unquote(row[1]),
    cuisine: _unquote(row[2]),
    category: _cast(row[3]),
    difficulty: _cast(row[4]),
    minutes: int.parse(row[5].trim()),
    cost: double.parse(row[6].trim()),
    servings: int.parse(row[7].trim()),
    // The steps are a nested `jsonb_build_array(...)` call, and counting its
    // arguments needs the same splitter that found this row.
    steps: _split(
      row[9]
          .trim()
          .replaceFirst('jsonb_build_array(', '')
          .replaceFirst(RegExp(r'\)$'), ''),
    ).length,
    dietaryTags: _arrayLiteral(row[10]),
    tags: _arrayLiteral(row[11]),
  );

  /// name, description, cuisine, category, difficulty, minutes, cost,
  /// servings, calories, steps, diet, tags.
  static const int fieldCount = 12;

  final String name;
  final String description;
  final String cuisine;
  final String category;
  final String difficulty;
  final int minutes;
  final double cost;
  final int servings;
  final int steps;
  final Set<String> dietaryTags;
  final Set<String> tags;
}

class _Link {
  _Link(
    this.mealName,
    this.ingredientName,
    this.quantity,
    this.unit,
    this.isOptional,
  );

  factory _Link.fromRow(List<String> row) => _Link(
    _unquote(row[0]),
    _unquote(row[1]),
    double.parse(row[2].trim()),
    _unquote(row[3]),
    row[4].trim() == 'true',
  );

  final String mealName;
  final String ingredientName;
  final double quantity;
  final String unit;
  final bool isOptional;
}

/// Every `values` row in [file], as a list of raw field strings.
///
/// Filtered to groups whose first field is a quoted string, which is what
/// separates a data row from the column lists and subqueries that share the
/// same parentheses.
List<List<String>> _read(Directory directory, String file) {
  final String sql = File('${directory.path}/$file').readAsStringSync();

  return _groups(_stripComments(sql))
      .map(_split)
      .where((List<String> row) => row.isNotEmpty && row.first.startsWith("'"))
      .toList();
}

/// Drops `--` comments, leaving anything inside a string literal alone.
String _stripComments(String sql) {
  final StringBuffer out = StringBuffer();
  bool inString = false;

  for (int i = 0; i < sql.length; i++) {
    final String char = sql[i];

    if (inString) {
      out.write(char);
      if (char == "'") {
        // A doubled quote is an escaped apostrophe, not the end of the string.
        if (i + 1 < sql.length && sql[i + 1] == "'") {
          out.write(sql[++i]);
        } else {
          inString = false;
        }
      }
      continue;
    }

    if (char == "'") {
      inString = true;
      out.write(char);
      continue;
    }

    if (char == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
      while (i < sql.length && sql[i] != '\n') {
        i++;
      }
      out.write('\n');
      continue;
    }

    out.write(char);
  }

  return out.toString();
}

/// The contents of every parenthesised group in [sql], at any nesting depth.
///
/// Every depth, not only the outermost: the meal rows sit inside the `with
/// catalogue (...) as (...)` that wraps them, and the ingredient links inside a
/// `from (...) as items`. Nested parentheses are still written into their
/// parent's text so that [_split] can see them and leave their commas alone.
List<String> _groups(String sql) {
  final List<String> groups = <String>[];
  final List<StringBuffer> open = <StringBuffer>[];
  bool inString = false;

  void writeAll(String text) {
    for (final StringBuffer buffer in open) {
      buffer.write(text);
    }
  }

  for (int i = 0; i < sql.length; i++) {
    final String char = sql[i];

    if (inString) {
      writeAll(char);
      if (char == "'") {
        // A doubled quote is an escaped apostrophe, not the end of the string.
        if (i + 1 < sql.length && sql[i + 1] == "'") {
          writeAll(sql[++i]);
        } else {
          inString = false;
        }
      }
      continue;
    }

    switch (char) {
      case "'":
        inString = true;
        writeAll(char);
      case '(':
        writeAll(char);
        open.add(StringBuffer());
      case ')':
        if (open.isNotEmpty) {
          groups.add(open.removeLast().toString());
        }
        writeAll(char);
      default:
        writeAll(char);
    }
  }

  return groups;
}

/// Splits on commas that are not inside a string or a nested group.
List<String> _split(String group) {
  final List<String> fields = <String>[];
  final StringBuffer current = StringBuffer();
  int depth = 0;
  bool inString = false;

  for (int i = 0; i < group.length; i++) {
    final String char = group[i];

    if (inString) {
      current.write(char);
      if (char == "'") {
        if (i + 1 < group.length && group[i + 1] == "'") {
          current.write(group[++i]);
        } else {
          inString = false;
        }
      }
      continue;
    }

    switch (char) {
      case "'":
        inString = true;
        current.write(char);
      case '(' || '[':
        depth++;
        current.write(char);
      case ')' || ']':
        depth--;
        current.write(char);
      case ',' when depth == 0:
        fields.add(current.toString().trim());
        current.clear();
      default:
        current.write(char);
    }
  }

  if (current.toString().trim().isNotEmpty) {
    fields.add(current.toString().trim());
  }

  return fields;
}

/// `'text'` to `text`, undoubling escaped apostrophes.
String _unquote(String field) {
  final String trimmed = field.trim();
  if (!trimmed.startsWith("'")) {
    return trimmed;
  }
  final int end = trimmed.lastIndexOf("'");
  return trimmed.substring(1, end).replaceAll("''", "'");
}

/// `'dinner'::meal_category` to `dinner`.
String _cast(String field) => _unquote(field.split('::').first);

/// `'{vegetarian,vegan}'::dietary_tag[]` to `{vegetarian, vegan}`.
Set<String> _arrayLiteral(String field) {
  final String inner = _cast(field).replaceAll('{', '').replaceAll('}', '');
  return inner
      .split(',')
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toSet();
}
