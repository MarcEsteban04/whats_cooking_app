-- ===========================================================================
-- Seed 03 · What each catalogue meal is made of
--
-- Run after 01_ingredients.sql and 02_meals.sql.
--
-- ---------------------------------------------------------------------------
-- What is listed, and what is not
-- ---------------------------------------------------------------------------
--
-- The ingredients that decide whether you can cook this tonight — not every
-- last item in the method. Salt, oil, pepper and water appear in the
-- instructions and are left out of the list unless they define the dish (the
-- oil in aglio e olio, the vinegar in adobo).
--
-- That is a deliberate reading of docs/USER_FLOWS.md §12. The pantry match
-- exists to answer "can I make this now?", and padding the denominator with
-- things everyone has makes the percentage a worse answer, not a more precise
-- one.
--
-- `is_optional` marks what a meal is still itself without. Optional
-- ingredients are excluded from the match denominator, so a missing garnish
-- must never be what stops a meal being offered.
--
-- ---------------------------------------------------------------------------
-- Why the joins are LEFT joins
-- ---------------------------------------------------------------------------
--
-- A misspelt ingredient or meal name would silently vanish from an inner join,
-- and the catalogue would quietly ship a recipe missing its main ingredient.
-- With LEFT joins the unmatched row carries a null into a `not null` column and
-- the whole insert fails, naming the column. Loud beats tidy here.
--
-- Re-running is safe: every link for a public meal is deleted first, so an
-- ingredient removed from a recipe here disappears from the database too.
-- Household-private custom meals (Sprint 26) are never touched.
-- ===========================================================================

delete from meal_ingredients
where meal_id in (select id from meals where is_public);

insert into meal_ingredients (meal_id, ingredient_id, quantity, unit, is_optional)
select m.id, i.id, items.quantity, items.unit, items.is_optional
from (
  values

  -- =========================================================================
  -- Filipino
  -- =========================================================================
  ('Chicken Adobo',    'chicken thigh',      800, 'g',  false),
  ('Chicken Adobo',    'soy sauce',          120, 'ml', false),
  ('Chicken Adobo',    'vinegar',             80, 'ml', false),
  ('Chicken Adobo',    'garlic',               6, 'pc', false),
  ('Chicken Adobo',    'bay leaf',             3, 'pc', false),
  ('Chicken Adobo',    'black pepper',         5, 'g',  false),

  ('Pork Sinigang',    'pork belly',         700, 'g',  false),
  ('Pork Sinigang',    'tamarind soup base',  40, 'g',  false),
  ('Pork Sinigang',    'radish',               1, 'pc', false),
  ('Pork Sinigang',    'string beans',       150, 'g',  false),
  ('Pork Sinigang',    'kangkong',           200, 'g',  false),
  ('Pork Sinigang',    'tomato',               2, 'pc', false),
  ('Pork Sinigang',    'okra',               100, 'g',  true),

  ('Beef Tapa',        'beef sirloin',       400, 'g',  false),
  ('Beef Tapa',        'soy sauce',           60, 'ml', false),
  ('Beef Tapa',        'calamansi',            4, 'pc', false),
  ('Beef Tapa',        'garlic',               5, 'pc', false),
  ('Beef Tapa',        'rice',               300, 'g',  false),
  ('Beef Tapa',        'egg',                  2, 'pc', false),

  ('Tortang Talong',   'eggplant',             2, 'pc', false),
  ('Tortang Talong',   'egg',                  3, 'pc', false),
  ('Tortang Talong',   'tomato',               1, 'pc', true),

  ('Ginisang Munggo',  'mung bean',          250, 'g',  false),
  ('Ginisang Munggo',  'malunggay leaves',   100, 'g',  false),
  ('Ginisang Munggo',  'tomato',               2, 'pc', false),
  ('Ginisang Munggo',  'garlic',               5, 'pc', false),
  ('Ginisang Munggo',  'onion',                1, 'pc', false),

  ('Chicken Tinola',   'whole chicken',      900, 'g',  false),
  ('Chicken Tinola',   'ginger',              40, 'g',  false),
  ('Chicken Tinola',   'chayote',              1, 'pc', false),
  ('Chicken Tinola',   'malunggay leaves',   100, 'g',  false),
  ('Chicken Tinola',   'fish sauce',          30, 'ml', false),

  ('Bicol Express',    'pork belly',         700, 'g',  false),
  ('Bicol Express',    'coconut milk',       400, 'ml', false),
  ('Bicol Express',    'green chili',          8, 'pc', false),
  ('Bicol Express',    'shrimp paste',        40, 'g',  false),
  ('Bicol Express',    'garlic',               5, 'pc', false),

  ('Kare-Kare',        'oxtail',             900, 'g',  false),
  ('Kare-Kare',        'beef tripe',         300, 'g',  true),
  ('Kare-Kare',        'peanut butter',      150, 'g',  false),
  ('Kare-Kare',        'annatto seeds',       15, 'g',  false),
  ('Kare-Kare',        'string beans',       150, 'g',  false),
  ('Kare-Kare',        'bok choy',           200, 'g',  false),
  ('Kare-Kare',        'shrimp paste',        40, 'g',  false),

  ('Lumpiang Shanghai','ground pork',        500, 'g',  false),
  ('Lumpiang Shanghai','lumpia wrapper',      30, 'pc', false),
  ('Lumpiang Shanghai','carrot',               1, 'pc', false),
  ('Lumpiang Shanghai','onion',                1, 'pc', false),
  ('Lumpiang Shanghai','egg',                  1, 'pc', false),

  ('Pancit Bihon',     'rice noodles',       400, 'g',  false),
  ('Pancit Bihon',     'chicken breast',     300, 'g',  false),
  ('Pancit Bihon',     'cabbage',            200, 'g',  false),
  ('Pancit Bihon',     'carrot',               1, 'pc', false),
  ('Pancit Bihon',     'soy sauce',           60, 'ml', false),
  ('Pancit Bihon',     'calamansi',            3, 'pc', true),

  ('Arroz Caldo',      'rice',               200, 'g',  false),
  ('Arroz Caldo',      'chicken thigh',      400, 'g',  false),
  ('Arroz Caldo',      'ginger',              40, 'g',  false),
  ('Arroz Caldo',      'garlic',               6, 'pc', false),
  ('Arroz Caldo',      'egg',                  2, 'pc', true),
  ('Arroz Caldo',      'spring onion',        30, 'g',  true),

  ('Garlic Fried Rice and Egg', 'rice',      400, 'g',  false),
  ('Garlic Fried Rice and Egg', 'garlic',      8, 'pc', false),
  ('Garlic Fried Rice and Egg', 'egg',         2, 'pc', false),

  ('Pork Sisig',       'pork belly',         600, 'g',  false),
  ('Pork Sisig',       'chicken liver',      150, 'g',  false),
  ('Pork Sisig',       'onion',                1, 'pc', false),
  ('Pork Sisig',       'calamansi',            4, 'pc', false),
  ('Pork Sisig',       'red chili',            3, 'pc', false),
  ('Pork Sisig',       'mayonnaise',          40, 'ml', true),

  ('Chicken Inasal',   'chicken thigh',      900, 'g',  false),
  ('Chicken Inasal',   'lemongrass',           3, 'pc', false),
  ('Chicken Inasal',   'calamansi',            6, 'pc', false),
  ('Chicken Inasal',   'annatto seeds',       15, 'g',  false),
  ('Chicken Inasal',   'ginger',              30, 'g',  false),
  ('Chicken Inasal',   'vinegar',             80, 'ml', false),

  ('Laing',            'dried taro leaves',  120, 'g',  false),
  ('Laing',            'coconut milk',       400, 'ml', false),
  ('Laing',            'shrimp paste',        30, 'g',  false),
  ('Laing',            'green chili',          5, 'pc', false),
  ('Laing',            'ginger',              20, 'g',  false),

  ('Ginataang Gulay',  'squash',             400, 'g',  false),
  ('Ginataang Gulay',  'string beans',       150, 'g',  false),
  ('Ginataang Gulay',  'coconut milk',       400, 'ml', false),
  ('Ginataang Gulay',  'garlic',               5, 'pc', false),
  ('Ginataang Gulay',  'onion',                1, 'pc', false),

  ('Turon',            'banana',               4, 'pc', false),
  ('Turon',            'lumpia wrapper',       8, 'pc', false),
  ('Turon',            'brown sugar',        100, 'g',  false),

  ('Leche Flan',       'egg',                  8, 'pc', false),
  ('Leche Flan',       'condensed milk',     300, 'ml', false),
  ('Leche Flan',       'evaporated milk',    350, 'ml', false),
  ('Leche Flan',       'sugar',              150, 'g',  false),
  ('Leche Flan',       'calamansi',            1, 'pc', true),

  ('Halo-Halo',        'nata de coco',       100, 'g',  false),
  ('Halo-Halo',        'ube halaya',         100, 'g',  false),
  ('Halo-Halo',        'sweetened beans',    100, 'g',  false),
  ('Halo-Halo',        'evaporated milk',    200, 'ml', false),

  ('Champorado',       'glutinous rice',     250, 'g',  false),
  ('Champorado',       'tablea',              80, 'g',  false),
  ('Champorado',       'condensed milk',     150, 'ml', true),

  -- =========================================================================
  -- Japanese
  -- =========================================================================
  ('Chicken Katsu Curry', 'chicken breast',  500, 'g',  false),
  ('Chicken Katsu Curry', 'panko breadcrumbs', 150, 'g', false),
  ('Chicken Katsu Curry', 'egg',               2, 'pc', false),
  ('Chicken Katsu Curry', 'japanese curry roux', 100, 'g', false),
  ('Chicken Katsu Curry', 'potato',            2, 'pc', false),
  ('Chicken Katsu Curry', 'carrot',            1, 'pc', false),
  ('Chicken Katsu Curry', 'rice',            450, 'g',  false),

  ('Salmon Teriyaki',  'salmon fillet',      350, 'g',  false),
  ('Salmon Teriyaki',  'soy sauce',           60, 'ml', false),
  ('Salmon Teriyaki',  'mirin',               40, 'ml', false),
  ('Salmon Teriyaki',  'ginger',              20, 'g',  false),
  ('Salmon Teriyaki',  'sugar',               30, 'g',  false),

  ('Tamagoyaki',       'egg',                  4, 'pc', false),
  ('Tamagoyaki',       'mirin',               15, 'ml', false),
  ('Tamagoyaki',       'sugar',               10, 'g',  false),

  ('Miso Soup',        'miso paste',          60, 'g',  false),
  ('Miso Soup',        'kombu',               10, 'g',  false),
  ('Miso Soup',        'tofu',               200, 'g',  false),
  ('Miso Soup',        'spring onion',        20, 'g',  true),

  ('Oyakodon',         'chicken thigh',      300, 'g',  false),
  ('Oyakodon',         'egg',                  4, 'pc', false),
  ('Oyakodon',         'onion',                1, 'pc', false),
  ('Oyakodon',         'soy sauce',           45, 'ml', false),
  ('Oyakodon',         'mirin',               30, 'ml', false),
  ('Oyakodon',         'rice',               350, 'g',  false),

  ('Yakisoba',         'egg noodles',        400, 'g',  false),
  ('Yakisoba',         'pork belly',         250, 'g',  false),
  ('Yakisoba',         'cabbage',            200, 'g',  false),
  ('Yakisoba',         'carrot',               1, 'pc', false),
  ('Yakisoba',         'worcestershire sauce', 60, 'ml', false),

  ('Onigiri',          'rice',               400, 'g',  false),
  ('Onigiri',          'canned tuna',        150, 'g',  false),
  ('Onigiri',          'mayonnaise',          40, 'ml', false),
  ('Onigiri',          'nori',                 3, 'pc', false),

  ('Matcha Mochi',     'glutinous rice flour', 250, 'g', false),
  ('Matcha Mochi',     'matcha powder',       15, 'g',  false),
  ('Matcha Mochi',     'sugar',              120, 'g',  false),
  ('Matcha Mochi',     'coconut milk',       200, 'ml', false),

  -- =========================================================================
  -- Korean
  -- =========================================================================
  ('Kimchi Jjigae',    'kimchi',             400, 'g',  false),
  ('Kimchi Jjigae',    'pork belly',         300, 'g',  false),
  ('Kimchi Jjigae',    'tofu',               200, 'g',  false),
  ('Kimchi Jjigae',    'gochugaru',           10, 'g',  false),
  ('Kimchi Jjigae',    'spring onion',        30, 'g',  true),

  ('Bibimbap',         'rice',               400, 'g',  false),
  ('Bibimbap',         'beef sirloin',       200, 'g',  false),
  ('Bibimbap',         'spinach',            150, 'g',  false),
  ('Bibimbap',         'bean sprouts',       150, 'g',  false),
  ('Bibimbap',         'carrot',               1, 'pc', false),
  ('Bibimbap',         'egg',                  2, 'pc', false),
  ('Bibimbap',         'gochujang',           40, 'g',  false),

  ('Korean Fried Chicken', 'chicken wing',  1000, 'g',  false),
  ('Korean Fried Chicken', 'corn starch',    150, 'g',  false),
  ('Korean Fried Chicken', 'gochujang',       60, 'g',  false),
  ('Korean Fried Chicken', 'honey',           60, 'ml', false),
  ('Korean Fried Chicken', 'sesame seeds',    10, 'g',  true),

  ('Tteokbokki',       'rice cake',          400, 'g',  false),
  ('Tteokbokki',       'gochujang',           50, 'g',  false),
  ('Tteokbokki',       'gochugaru',           10, 'g',  false),
  ('Tteokbokki',       'sugar',               20, 'g',  false),
  ('Tteokbokki',       'spring onion',        20, 'g',  true),

  ('Japchae',          'sweet potato noodles', 300, 'g', false),
  ('Japchae',          'beef sirloin',       200, 'g',  false),
  ('Japchae',          'spinach',            150, 'g',  false),
  ('Japchae',          'carrot',               1, 'pc', false),
  ('Japchae',          'mushroom',           150, 'g',  false),
  ('Japchae',          'sesame oil',          30, 'ml', false),

  ('Samgyeopsal',      'pork belly',         800, 'g',  false),
  ('Samgyeopsal',      'lettuce',            200, 'g',  false),
  ('Samgyeopsal',      'garlic',               8, 'pc', false),
  ('Samgyeopsal',      'sesame oil',          30, 'ml', false),
  ('Samgyeopsal',      'kimchi',             200, 'g',  true),

  ('Hotteok',          'all-purpose flour',  300, 'g',  false),
  ('Hotteok',          'yeast',                7, 'g',  false),
  ('Hotteok',          'brown sugar',        120, 'g',  false),
  ('Hotteok',          'peanuts',             60, 'g',  false),
  ('Hotteok',          'milk',               180, 'ml', false),

  -- =========================================================================
  -- Chinese
  -- =========================================================================
  ('Beef and Broccoli','beef sirloin',       450, 'g',  false),
  ('Beef and Broccoli','broccoli',           400, 'g',  false),
  ('Beef and Broccoli','oyster sauce',        60, 'ml', false),
  ('Beef and Broccoli','garlic',               5, 'pc', false),
  ('Beef and Broccoli','corn starch',         20, 'g',  false),

  ('Yang Chow Fried Rice', 'rice',           600, 'g',  false),
  ('Yang Chow Fried Rice', 'shrimp',         200, 'g',  false),
  ('Yang Chow Fried Rice', 'egg',              3, 'pc', false),
  ('Yang Chow Fried Rice', 'carrot',           1, 'pc', false),
  ('Yang Chow Fried Rice', 'corn kernels',   100, 'g',  false),
  ('Yang Chow Fried Rice', 'spring onion',    30, 'g',  true),

  ('Sweet and Sour Pork', 'pork shoulder',   600, 'g',  false),
  ('Sweet and Sour Pork', 'bell pepper',       2, 'pc', false),
  ('Sweet and Sour Pork', 'pineapple',       200, 'g',  false),
  ('Sweet and Sour Pork', 'ketchup',          80, 'ml', false),
  ('Sweet and Sour Pork', 'corn starch',      60, 'g',  false),

  ('Wonton Noodle Soup', 'wonton wrapper',    30, 'pc', false),
  ('Wonton Noodle Soup', 'ground pork',      350, 'g',  false),
  ('Wonton Noodle Soup', 'egg noodles',      300, 'g',  false),
  ('Wonton Noodle Soup', 'bok choy',         200, 'g',  false),
  ('Wonton Noodle Soup', 'ginger',            20, 'g',  false),

  ('Mapo Tofu',        'tofu',               500, 'g',  false),
  ('Mapo Tofu',        'ground pork',        200, 'g',  false),
  ('Mapo Tofu',        'chili bean paste',    50, 'g',  false),
  ('Mapo Tofu',        'sichuan peppercorn',   5, 'g',  false),
  ('Mapo Tofu',        'spring onion',        30, 'g',  true),

  ('Siomai',           'ground pork',        500, 'g',  false),
  ('Siomai',           'shrimp',             200, 'g',  false),
  ('Siomai',           'wonton wrapper',      40, 'pc', false),
  ('Siomai',           'carrot',               1, 'pc', false),
  ('Siomai',           'sesame oil',          20, 'ml', false),

  ('Buchi',            'glutinous rice flour', 300, 'g', false),
  ('Buchi',            'sweetened beans',    200, 'g',  false),
  ('Buchi',            'sesame seeds',        60, 'g',  false),
  ('Buchi',            'sugar',               80, 'g',  false),

  -- =========================================================================
  -- Italian
  -- =========================================================================
  ('Spaghetti Aglio e Olio', 'spaghetti',    250, 'g',  false),
  ('Spaghetti Aglio e Olio', 'garlic',         8, 'pc', false),
  ('Spaghetti Aglio e Olio', 'cooking oil',   80, 'ml', false),
  ('Spaghetti Aglio e Olio', 'red chili',      2, 'pc', false),
  ('Spaghetti Aglio e Olio', 'parsley',       20, 'g',  true),

  ('Carbonara',        'spaghetti',          350, 'g',  false),
  ('Carbonara',        'bacon',              200, 'g',  false),
  ('Carbonara',        'egg',                  4, 'pc', false),
  ('Carbonara',        'parmesan cheese',    100, 'g',  false),
  ('Carbonara',        'black pepper',         8, 'g',  false),

  ('Margherita Pizza', 'bread flour',        400, 'g',  false),
  ('Margherita Pizza', 'yeast',                7, 'g',  false),
  ('Margherita Pizza', 'canned tomatoes',    400, 'g',  false),
  ('Margherita Pizza', 'mozzarella cheese',  250, 'g',  false),
  ('Margherita Pizza', 'basil',               20, 'g',  false),

  ('Chicken Parmigiana', 'chicken breast',   600, 'g',  false),
  ('Chicken Parmigiana', 'all-purpose flour', 100, 'g', false),
  ('Chicken Parmigiana', 'egg',                2, 'pc', false),
  ('Chicken Parmigiana', 'tomato sauce',     400, 'ml', false),
  ('Chicken Parmigiana', 'mozzarella cheese', 200, 'g', false),
  ('Chicken Parmigiana', 'parmesan cheese',   60, 'g',  true),

  ('Minestrone',       'canned tomatoes',    400, 'g',  false),
  ('Minestrone',       'kidney beans',       240, 'g',  false),
  ('Minestrone',       'carrot',               2, 'pc', false),
  ('Minestrone',       'celery',             100, 'g',  false),
  ('Minestrone',       'zucchini',             1, 'pc', false),
  ('Minestrone',       'macaroni',           120, 'g',  false),

  ('Pesto Pasta',      'spaghetti',          250, 'g',  false),
  ('Pesto Pasta',      'basil',               80, 'g',  false),
  ('Pesto Pasta',      'pine nuts',           40, 'g',  false),
  ('Pesto Pasta',      'parmesan cheese',     60, 'g',  false),
  ('Pesto Pasta',      'garlic',               3, 'pc', false),

  ('Tiramisu',         'mascarpone',         500, 'g',  false),
  ('Tiramisu',         'ladyfinger biscuit',  24, 'pc', false),
  ('Tiramisu',         'egg',                  4, 'pc', false),
  ('Tiramisu',         'coffee',              30, 'g',  false),
  ('Tiramisu',         'cocoa powder',        20, 'g',  false),

  -- =========================================================================
  -- Mexican
  -- =========================================================================
  ('Chicken Tacos',    'chicken breast',     500, 'g',  false),
  ('Chicken Tacos',    'tortilla',             9, 'pc', false),
  ('Chicken Tacos',    'cabbage',            150, 'g',  false),
  ('Chicken Tacos',    'lime',                 2, 'pc', false),
  ('Chicken Tacos',    'cumin',                8, 'g',  false),
  ('Chicken Tacos',    'cilantro',            20, 'g',  true),

  ('Beef Burrito',     'tortilla',             2, 'pc', false),
  ('Beef Burrito',     'ground beef',        350, 'g',  false),
  ('Beef Burrito',     'rice',               200, 'g',  false),
  ('Beef Burrito',     'kidney beans',       240, 'g',  false),
  ('Beef Burrito',     'cheddar cheese',     100, 'g',  false),
  ('Beef Burrito',     'chili powder',        10, 'g',  false),

  ('Quesadillas',      'tortilla',             4, 'pc', false),
  ('Quesadillas',      'cheddar cheese',     200, 'g',  false),
  ('Quesadillas',      'bell pepper',          1, 'pc', false),
  ('Quesadillas',      'onion',                1, 'pc', false),

  ('Chili con Carne',  'ground beef',        600, 'g',  false),
  ('Chili con Carne',  'kidney beans',       400, 'g',  false),
  ('Chili con Carne',  'canned tomatoes',    400, 'g',  false),
  ('Chili con Carne',  'chili powder',        15, 'g',  false),
  ('Chili con Carne',  'cumin',               10, 'g',  false),
  ('Chili con Carne',  'onion',                2, 'pc', false),

  ('Churros',          'all-purpose flour',  250, 'g',  false),
  ('Churros',          'butter',              80, 'g',  false),
  ('Churros',          'egg',                  3, 'pc', false),
  ('Churros',          'sugar',              100, 'g',  false),
  ('Churros',          'chocolate chips',    120, 'g',  true),

  -- =========================================================================
  -- American
  -- =========================================================================
  ('Classic Cheeseburger', 'ground beef',    400, 'g',  false),
  ('Classic Cheeseburger', 'burger bun',       2, 'pc', false),
  ('Classic Cheeseburger', 'cheddar cheese',  60, 'g',  false),
  ('Classic Cheeseburger', 'lettuce',         60, 'g',  false),
  ('Classic Cheeseburger', 'tomato',           1, 'pc', true),
  ('Classic Cheeseburger', 'mayonnaise',      30, 'ml', true),

  ('Buttermilk Pancakes', 'all-purpose flour', 300, 'g', false),
  ('Buttermilk Pancakes', 'milk',            350, 'ml', false),
  ('Buttermilk Pancakes', 'egg',               2, 'pc', false),
  ('Buttermilk Pancakes', 'baking powder',    12, 'g',  false),
  ('Buttermilk Pancakes', 'butter',           60, 'g',  false),
  ('Buttermilk Pancakes', 'honey',            60, 'ml', true),

  ('Mac and Cheese',   'macaroni',           400, 'g',  false),
  ('Mac and Cheese',   'cheddar cheese',     300, 'g',  false),
  ('Mac and Cheese',   'milk',               400, 'ml', false),
  ('Mac and Cheese',   'butter',              60, 'g',  false),
  ('Mac and Cheese',   'all-purpose flour',   40, 'g',  false),

  ('Chicken Caesar Salad', 'chicken breast', 350, 'g',  false),
  ('Chicken Caesar Salad', 'lettuce',        300, 'g',  false),
  ('Chicken Caesar Salad', 'parmesan cheese', 60, 'g',  false),
  ('Chicken Caesar Salad', 'mayonnaise',      80, 'ml', false),
  ('Chicken Caesar Salad', 'anchovy',         20, 'g',  true),
  ('Chicken Caesar Salad', 'lemon',            1, 'pc', false),

  ('BBQ Pork Ribs',    'pork ribs',         1500, 'g',  false),
  ('BBQ Pork Ribs',    'bbq sauce',          250, 'ml', false),
  ('BBQ Pork Ribs',    'brown sugar',         80, 'g',  false),
  ('BBQ Pork Ribs',    'paprika',             20, 'g',  false),
  ('BBQ Pork Ribs',    'garlic',               6, 'pc', false),

  ('Chocolate Chip Cookies', 'all-purpose flour', 300, 'g', false),
  ('Chocolate Chip Cookies', 'butter',       200, 'g',  false),
  ('Chocolate Chip Cookies', 'brown sugar',  180, 'g',  false),
  ('Chocolate Chip Cookies', 'egg',            2, 'pc', false),
  ('Chocolate Chip Cookies', 'chocolate chips', 250, 'g', false),
  ('Chocolate Chip Cookies', 'vanilla extract', 10, 'ml', true)

) as items (meal_name, ingredient_name, quantity, unit, is_optional)
left join meals m
  on lower(m.name) = lower(items.meal_name)
 and m.is_public
left join ingredients i
  on i.name = items.ingredient_name;
