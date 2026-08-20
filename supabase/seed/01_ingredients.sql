-- ===========================================================================
-- Seed 01 · Ingredient vocabulary
--
-- Run this BEFORE 02_meals.sql — the meal links join on these names.
-- Safe to re-run: `on conflict (name)` updates the category and unit and
-- leaves the ids alone, so nothing that references an ingredient breaks.
--
-- See docs/DATABASE.md §4.6.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Staples
--
-- docs/USER_FLOWS.md §12: salt, pepper, oil and water never reduce a pantry
-- match percentage. Without that rule every meal caps near 80% and the number
-- stops carrying information.
--
-- We extend the list to garlic, onion, soy sauce, vinegar, sugar and fish
-- sauce. Not laziness — in the kitchens this app is built for those nine are
-- genuinely always there, and treating them as missing would make a 90 %
-- match read as 60 % for want of an onion. The list is kept deliberately
-- short: mark a real ingredient as a staple and the match starts lying in the
-- other direction, promising a meal nobody can cook tonight.
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit, is_staple) values
  ('salt',          'spice',     'g',  true),
  ('black pepper',  'spice',     'g',  true),
  ('cooking oil',   'condiment', 'ml', true),
  ('water',         'other',     'ml', true),
  ('sugar',         'other',     'g',  true),
  ('garlic',        'vegetable', 'pc', true),
  ('onion',         'vegetable', 'pc', true),
  ('soy sauce',     'condiment', 'ml', true),
  ('vinegar',       'condiment', 'ml', true),
  ('fish sauce',    'condiment', 'ml', true)
on conflict (name) do update
  set category = excluded.category,
      default_unit = excluded.default_unit,
      is_staple = excluded.is_staple;

-- ---------------------------------------------------------------------------
-- Proteins
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('chicken thigh',   'protein', 'g'),
  ('chicken breast',  'protein', 'g'),
  ('whole chicken',   'protein', 'g'),
  ('chicken wing',    'protein', 'g'),
  ('chicken liver',   'protein', 'g'),
  ('pork belly',      'protein', 'g'),
  ('pork shoulder',   'protein', 'g'),
  ('pork ribs',       'protein', 'g'),
  ('ground pork',     'protein', 'g'),
  ('beef sirloin',    'protein', 'g'),
  ('ground beef',     'protein', 'g'),
  ('oxtail',          'protein', 'g'),
  ('beef tripe',      'protein', 'g'),
  ('salmon fillet',   'protein', 'g'),
  ('canned tuna',     'protein', 'g'),
  ('shrimp',          'protein', 'g'),
  ('anchovy',         'protein', 'g'),
  ('egg',             'protein', 'pc'),
  ('tofu',            'protein', 'g'),
  ('bacon',           'protein', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Vegetables
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('eggplant',          'vegetable', 'pc'),
  ('tomato',            'vegetable', 'pc'),
  ('canned tomatoes',   'vegetable', 'g'),
  ('kangkong',          'vegetable', 'g'),
  ('malunggay leaves',  'vegetable', 'g'),
  ('dried taro leaves', 'vegetable', 'g'),
  ('radish',            'vegetable', 'pc'),
  ('string beans',      'vegetable', 'g'),
  ('okra',              'vegetable', 'g'),
  ('bok choy',          'vegetable', 'g'),
  ('cabbage',           'vegetable', 'g'),
  ('carrot',            'vegetable', 'pc'),
  ('celery',            'vegetable', 'g'),
  ('broccoli',          'vegetable', 'g'),
  ('bell pepper',       'vegetable', 'pc'),
  ('green chili',       'vegetable', 'pc'),
  ('red chili',         'vegetable', 'pc'),
  ('spring onion',      'vegetable', 'g'),
  ('potato',            'vegetable', 'pc'),
  ('squash',            'vegetable', 'g'),
  ('chayote',           'vegetable', 'pc'),
  ('lettuce',           'vegetable', 'g'),
  ('bean sprouts',      'vegetable', 'g'),
  ('spinach',           'vegetable', 'g'),
  ('mushroom',          'vegetable', 'g'),
  ('zucchini',          'vegetable', 'pc'),
  ('corn kernels',      'vegetable', 'g'),
  ('kimchi',            'vegetable', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Fruit
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('calamansi', 'fruit', 'pc'),
  ('lemon',     'fruit', 'pc'),
  ('lime',      'fruit', 'pc'),
  ('banana',    'fruit', 'pc'),
  ('pineapple', 'fruit', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Grains, starches and pulses
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('rice',                  'grain', 'g'),
  ('glutinous rice',        'grain', 'g'),
  ('glutinous rice flour',  'grain', 'g'),
  ('rice noodles',          'grain', 'g'),
  ('egg noodles',           'grain', 'g'),
  ('sweet potato noodles',  'grain', 'g'),
  ('spaghetti',             'grain', 'g'),
  ('macaroni',              'grain', 'g'),
  ('bread flour',           'grain', 'g'),
  ('all-purpose flour',     'grain', 'g'),
  ('corn starch',           'grain', 'g'),
  ('panko breadcrumbs',     'grain', 'g'),
  ('tortilla',              'grain', 'pc'),
  ('burger bun',            'grain', 'pc'),
  ('lumpia wrapper',        'grain', 'pc'),
  ('wonton wrapper',        'grain', 'pc'),
  ('rice cake',             'grain', 'g'),
  ('ladyfinger biscuit',    'grain', 'pc'),
  ('mung bean',             'grain', 'g'),
  ('kidney beans',          'grain', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Dairy
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('milk',              'dairy', 'ml'),
  ('butter',            'dairy', 'g'),
  ('cheddar cheese',    'dairy', 'g'),
  ('mozzarella cheese', 'dairy', 'g'),
  ('parmesan cheese',   'dairy', 'g'),
  ('mascarpone',        'dairy', 'g'),
  ('condensed milk',    'dairy', 'ml'),
  ('evaporated milk',   'dairy', 'ml')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Aromatics and spices
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('ginger',              'spice', 'g'),
  ('lemongrass',          'spice', 'pc'),
  ('bay leaf',            'spice', 'pc'),
  ('basil',               'spice', 'g'),
  ('cilantro',            'spice', 'g'),
  ('parsley',             'spice', 'g'),
  ('paprika',             'spice', 'g'),
  ('cumin',               'spice', 'g'),
  ('chili powder',        'spice', 'g'),
  ('annatto seeds',       'spice', 'g'),
  ('gochugaru',           'spice', 'g'),
  ('sichuan peppercorn',  'spice', 'g'),
  ('sesame seeds',        'spice', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Condiments and sauces
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('coconut milk',          'condiment', 'ml'),
  ('oyster sauce',          'condiment', 'ml'),
  ('shrimp paste',          'condiment', 'g'),
  ('tamarind soup base',    'condiment', 'g'),
  ('peanut butter',         'condiment', 'g'),
  ('mayonnaise',            'condiment', 'ml'),
  ('ketchup',               'condiment', 'ml'),
  ('bbq sauce',             'condiment', 'ml'),
  ('tomato sauce',          'condiment', 'ml'),
  ('gochujang',             'condiment', 'g'),
  ('chili bean paste',      'condiment', 'g'),
  ('miso paste',            'condiment', 'g'),
  ('sesame oil',            'condiment', 'ml'),
  ('mirin',                 'condiment', 'ml'),
  ('worcestershire sauce',  'condiment', 'ml'),
  ('japanese curry roux',   'condiment', 'g'),
  ('honey',                 'condiment', 'ml')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;

-- ---------------------------------------------------------------------------
-- Baking and everything else
-- ---------------------------------------------------------------------------
insert into ingredients (name, category, default_unit) values
  ('brown sugar',     'other', 'g'),
  ('baking powder',   'other', 'g'),
  ('yeast',           'other', 'g'),
  ('vanilla extract', 'other', 'ml'),
  ('cocoa powder',    'other', 'g'),
  ('chocolate chips', 'other', 'g'),
  ('tablea',          'other', 'g'),
  ('matcha powder',   'other', 'g'),
  ('coffee',          'other', 'g'),
  ('kombu',           'other', 'g'),
  ('nori',            'other', 'pc'),
  ('pine nuts',       'other', 'g'),
  ('peanuts',         'other', 'g'),
  ('nata de coco',    'other', 'g'),
  ('ube halaya',      'other', 'g'),
  ('sweetened beans', 'other', 'g')
on conflict (name) do update
  set category = excluded.category, default_unit = excluded.default_unit;
