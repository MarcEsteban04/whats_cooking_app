-- ===========================================================================
-- Seed 02 · The public meal catalogue
--
-- Run 01_ingredients.sql first, this second, 03_meal_ingredients.sql third.
-- Safe to re-run: upserted on `lower(name)` where `is_public`, the unique index
-- added by migration 0014. Ids survive, so favourites and history do too.
--
-- ---------------------------------------------------------------------------
-- Catalogue shape — docs/DATABASE.md §9 Q4, resolved here
-- ---------------------------------------------------------------------------
--
-- 60 meals. Not a round number chosen for tidiness: Sprint 32 stops the
-- roulette repeating a meal inside a window, and the filters in Sprint 30 cut
-- the pool by cuisine, budget, time and diet at the same time. A spin that
-- finds nothing is the one failure this product cannot survive, so the pool has
-- to stay non-empty after several filters intersect. Sixty leaves roughly a
-- dozen candidates in the narrowest realistic case (one cuisine, under 30
-- minutes, under 200 pesos).
--
-- The split, per docs/MVP_SCOPE.md — "breadth over depth; Filipino-leaning":
--
--   Filipino  20     Japanese   8     Korean     7     Chinese  7
--   Italian    7     Mexican    5     American   6
--
-- Filipino gets a third of the catalogue because it is the food the first users
-- actually cook, and a roulette that keeps landing on carbonara is a roulette
-- they stop trusting. The other six exist so "surprise me" can genuinely
-- surprise.
--
-- Every `meal_category` is represented, because the categories are how people
-- ask the question at different times of day:
--
--   breakfast  6     lunch  14     dinner  25     snack  6     dessert  9
--
-- Costs are in pesos for the servings stated, at 2026 Manila supermarket
-- prices. They are estimates and the app must never present them as anything
-- firmer (docs/DATABASE.md §9 Q5 revisits this in Sprint 23).
--
-- `image_url` is null throughout. Sixty photographs we do not have the rights
-- to would be sixty broken images; the cards carry the cuisine emoji until
-- Sprint 27 sources art.
--
-- ---------------------------------------------------------------------------
-- A note on the column order
-- ---------------------------------------------------------------------------
--
-- `cuisine` and `category` are adjacent, and `category` always carries its
-- `::meal_category` cast. test/tooling/meal_seed_test.dart reads the pair with
-- one regex and asserts both are values the Dart enums know. Keep them
-- adjacent, or that test goes quiet rather than failing.
-- ===========================================================================

with catalogue (
  name, description, cuisine, category, difficulty,
  minutes, cost, servings, calories, steps, diet, tags
) as (
  values

  -- =========================================================================
  -- Filipino · 20
  -- =========================================================================
  ('Chicken Adobo',
   'The one everybody has an opinion about. Soy, vinegar, garlic and patience.',
   'filipino', 'dinner'::meal_category, 'easy'::difficulty,
   45, 260.00, 4, 520,
   jsonb_build_array(
     'Marinate the chicken in soy sauce, crushed garlic and pepper for 20 minutes.',
     'Sear the pieces in a little oil until the skin colours, then set aside.',
     'Pour in the marinade, vinegar and bay leaves. Do not stir until it boils.',
     'Simmer covered for 25 minutes, then uncover and reduce until the sauce coats.',
     'Rest for five minutes before serving with rice.'),
   '{}'::dietary_tag[], '{comfort,make_ahead,one_pot}'::text[]),

  ('Pork Sinigang',
   'Sour, hot and full of vegetables. What you cook when it rains.',
   'filipino', 'dinner'::meal_category, 'easy'::difficulty,
   60, 320.00, 4, 430,
   jsonb_build_array(
     'Boil the pork with onion and tomato until tender, about 35 minutes.',
     'Stir in the tamarind base and season with fish sauce.',
     'Add the radish and string beans and cook for five minutes.',
     'Add the okra, then the kangkong last so it stays green.',
     'Taste for sourness before serving. It should make you sit up.'),
   '{}'::dietary_tag[], '{comfort,soup,rainy_day}'::text[]),

  ('Beef Tapa',
   'Cured beef, garlic rice and a runny egg. Breakfast that eats like dinner.',
   'filipino', 'breakfast'::meal_category, 'easy'::difficulty,
   20, 240.00, 2, 610,
   jsonb_build_array(
     'Slice the beef thinly against the grain.',
     'Marinate in soy sauce, calamansi juice, garlic and a little sugar for 15 minutes.',
     'Fry hot and fast so the edges caramelise rather than steam.',
     'Fry garlic rice in the same pan to pick up what is left behind.',
     'Top with a sunny-side-up egg and a splash of vinegar on the side.'),
   '{}'::dietary_tag[], '{silog,quick,high_protein}'::text[]),

  ('Tortang Talong',
   'Grilled eggplant folded into egg. Cheap, fast and better than it sounds.',
   'filipino', 'lunch'::meal_category, 'easy'::difficulty,
   25, 120.00, 2, 280,
   jsonb_build_array(
     'Grill or broil the eggplants until the skins blister and the flesh collapses.',
     'Peel while warm, leaving the stems on, and flatten each one with a fork.',
     'Beat the eggs with salt and pepper in a shallow dish.',
     'Dip each eggplant, then fry in a little oil until set on both sides.',
     'Serve with rice and banana ketchup or a chopped tomato salad.'),
   '{vegetarian}'::dietary_tag[], '{budget,meatless,quick}'::text[]),

  ('Ginisang Munggo',
   'Mung beans stewed soft with tomato and greens. Pure comfort for pocket change.',
   'filipino', 'lunch'::meal_category, 'easy'::difficulty,
   50, 140.00, 4, 310,
   jsonb_build_array(
     'Boil the mung beans in water until they break down, about 35 minutes.',
     'In another pan, saute garlic, onion and tomato until the tomato melts.',
     'Add the beans with their liquid and simmer for ten minutes.',
     'Season with salt, then fold in the malunggay leaves off the heat.',
     'Loosen with a little water if it thickens past a spoonable stew.'),
   '{vegetarian,vegan}'::dietary_tag[], '{budget,meatless,one_pot}'::text[]),

  ('Chicken Tinola',
   'Clear ginger broth, chicken and greens. The one you cook for someone unwell.',
   'filipino', 'dinner'::meal_category, 'easy'::difficulty,
   45, 280.00, 4, 360,
   jsonb_build_array(
     'Saute plenty of sliced ginger, garlic and onion until fragrant.',
     'Add the chicken pieces and let them colour lightly on all sides.',
     'Cover with water, bring to a boil, then simmer for 25 minutes.',
     'Add the chayote and cook until just tender.',
     'Season with fish sauce and stir in the malunggay leaves at the end.'),
   '{}'::dietary_tag[], '{comfort,soup,sick_day}'::text[]),

  ('Bicol Express',
   'Pork simmered in coconut milk and a serious amount of chili.',
   'filipino', 'dinner'::meal_category, 'medium'::difficulty,
   50, 300.00, 4, 590,
   jsonb_build_array(
     'Render the pork belly in a dry pan until the fat runs and the edges brown.',
     'Add garlic, onion and ginger and cook until soft.',
     'Stir in the shrimp paste and fry it for a full minute.',
     'Pour in the coconut milk and simmer uncovered for 20 minutes.',
     'Add the sliced chilies and cook five minutes more, until the sauce thickens.'),
   '{}'::dietary_tag[], '{spicy,rich,weekend}'::text[]),

  ('Kare-Kare',
   'Oxtail and tripe in peanut sauce. A weekend project with a payoff.',
   'filipino', 'dinner'::meal_category, 'hard'::difficulty,
   150, 450.00, 5, 640,
   jsonb_build_array(
     'Simmer the oxtail and tripe with onion for two hours, until a fork slides in.',
     'Steep the annatto seeds in a ladle of hot broth, then strain out the seeds.',
     'Saute garlic and onion, add the peanut butter and loosen with broth.',
     'Return the meat, pour in the annatto liquid and simmer for 20 minutes.',
     'Blanch the string beans and bok choy separately and arrange on top.',
     'Serve with sauteed shrimp paste on the side, not stirred through.'),
   '{}'::dietary_tag[], '{special_occasion,rich,slow}'::text[]),

  ('Lumpiang Shanghai',
   'Thin pork rolls fried until they shatter. Never make a small batch.',
   'filipino', 'snack'::meal_category, 'medium'::difficulty,
   40, 220.00, 6, 330,
   jsonb_build_array(
     'Mix the pork with finely chopped carrot and onion, egg, salt and pepper.',
     'Fry a teaspoon of the mixture to taste it, and adjust the seasoning.',
     'Roll tightly and thinly, sealing the edge with water.',
     'Fry at a moderate heat until pale gold, then rest them.',
     'Fry a second time, hot and brief, right before serving.'),
   '{}'::dietary_tag[], '{party,fried,make_ahead}'::text[]),

  ('Pancit Bihon',
   'Rice noodles tossed with chicken and vegetables. Feeds a crowd from one pan.',
   'filipino', 'lunch'::meal_category, 'easy'::difficulty,
   35, 200.00, 5, 420,
   jsonb_build_array(
     'Soak the rice noodles in warm water until pliable, then drain.',
     'Saute garlic and onion, add the chicken and cook through.',
     'Add soy sauce and a cup of stock and bring to a simmer.',
     'Stir in the carrot and cabbage and cook until barely tender.',
     'Add the noodles and toss until they drink the liquid. Serve with calamansi.'),
   '{}'::dietary_tag[], '{party,one_pan,budget}'::text[]),

  ('Arroz Caldo',
   'Rice porridge with ginger and chicken. Warm, salty and forgiving.',
   'filipino', 'breakfast'::meal_category, 'easy'::difficulty,
   45, 180.00, 4, 350,
   jsonb_build_array(
     'Saute a generous amount of garlic in oil and set half aside for the top.',
     'Add ginger, onion and the chicken, and season with fish sauce.',
     'Stir in the rice and coat it in the fat for a minute.',
     'Add water a ladle at a time, stirring, until the rice collapses. About 30 minutes.',
     'Serve topped with the reserved garlic, spring onion and a halved boiled egg.'),
   '{}'::dietary_tag[], '{comfort,soup,sick_day}'::text[]),

  ('Garlic Fried Rice and Egg',
   'Yesterday rice, today garlic, one egg. The cheapest good meal there is.',
   'filipino', 'breakfast'::meal_category, 'easy'::difficulty,
   15, 80.00, 2, 480,
   jsonb_build_array(
     'Use cold day-old rice. Fresh rice steams and clumps.',
     'Fry sliced garlic in oil over a low heat until pale gold, then lift it out.',
     'Turn the heat up, add the rice and press it into the pan before tossing.',
     'Season with salt and stir the garlic back through.',
     'Fry the eggs hard-edged and slide them on top.'),
   '{vegetarian}'::dietary_tag[], '{budget,quick,leftovers}'::text[]),

  ('Pork Sisig',
   'Chopped pork, sharp with calamansi and chili. Beer food that became dinner.',
   'filipino', 'dinner'::meal_category, 'medium'::difficulty,
   60, 280.00, 3, 620,
   jsonb_build_array(
     'Simmer the pork belly with onion and pepper until tender, about 40 minutes.',
     'Grill or broil the boiled pork until the edges char, then chop it fine.',
     'Sear the chicken liver, mash it, and use it to bind the mixture.',
     'Toss with chopped onion, chili and plenty of calamansi juice.',
     'Serve on a hot plate. Add mayonnaise only if you want it creamy.'),
   '{}'::dietary_tag[], '{pulutan,spicy,sizzling}'::text[]),

  ('Chicken Inasal',
   'Annatto and lemongrass grilled chicken from Bacolod. Worth the marinade.',
   'filipino', 'dinner'::meal_category, 'medium'::difficulty,
   40, 320.00, 4, 480,
   jsonb_build_array(
     'Marinate the chicken in calamansi, vinegar, ginger, garlic and bruised lemongrass.',
     'Leave it at least an hour, overnight if you can.',
     'Warm the annatto seeds in oil until the oil runs orange, then discard the seeds.',
     'Grill over medium coals, basting with the annatto oil each time you turn it.',
     'Serve with garlic rice and a dipping sauce of vinegar, soy and chili.'),
   '{}'::dietary_tag[], '{grilled,weekend,high_protein}'::text[]),

  ('Laing',
   'Dried taro leaves collapsed into coconut milk. Do not stir it.',
   'filipino', 'lunch'::meal_category, 'easy'::difficulty,
   45, 160.00, 4, 340,
   jsonb_build_array(
     'Layer the dried taro leaves in a pot and pour the coconut milk over them.',
     'Add ginger, garlic and the shrimp paste on top. Do not stir.',
     'Simmer gently, uncovered, for 30 minutes. Stirring early turns it itchy.',
     'Once the leaves have collapsed, stir once and add the chilies.',
     'Cook down until the oil separates and the sauce clings.'),
   '{pescatarian}'::dietary_tag[], '{spicy,rich,meatless}'::text[]),

  ('Ginataang Gulay',
   'Squash and beans in coconut milk. Twenty minutes and no meat needed.',
   'filipino', 'dinner'::meal_category, 'easy'::difficulty,
   30, 150.00, 4, 290,
   jsonb_build_array(
     'Saute garlic, onion and ginger until soft.',
     'Add the squash and coat it in the aromatics.',
     'Pour in the coconut milk and simmer until the squash begins to give.',
     'Add the string beans and cook for five minutes more.',
     'Season with salt. Let some squash break down to thicken the sauce.'),
   '{vegetarian,vegan}'::dietary_tag[], '{meatless,budget,one_pot}'::text[]),

  ('Turon',
   'Banana and brown sugar in a wrapper, fried until it crackles.',
   'filipino', 'dessert'::meal_category, 'easy'::difficulty,
   20, 90.00, 4, 320,
   jsonb_build_array(
     'Halve the bananas lengthways and roll them in brown sugar.',
     'Wrap each piece tightly in a lumpia wrapper, sealing with water.',
     'Fry in shallow oil, turning, until the sugar caramelises dark gold.',
     'Lift onto a rack, not paper, so the shell stays crisp.',
     'Eat within ten minutes. This does not keep.'),
   '{vegetarian}'::dietary_tag[], '{street_food,fried,quick}'::text[]),

  ('Leche Flan',
   'Steamed custard under burnt sugar. Rich enough for small slices.',
   'filipino', 'dessert'::meal_category, 'medium'::difficulty,
   60, 180.00, 6, 380,
   jsonb_build_array(
     'Melt the sugar in the mould over a low flame until amber, then let it set.',
     'Whisk the yolks with condensed and evaporated milk. Do not beat in air.',
     'Strain the mixture twice. This is what makes it smooth.',
     'Cover with foil and steam over a low simmer for 35 minutes, until just set.',
     'Chill for at least four hours before turning it out.'),
   '{vegetarian,gluten_free}'::dietary_tag[], '{special_occasion,make_ahead}'::text[]),

  ('Halo-Halo',
   'Shaved ice, sweet beans and milk. Assembly, not cooking.',
   'filipino', 'dessert'::meal_category, 'easy'::difficulty,
   15, 150.00, 2, 420,
   jsonb_build_array(
     'Spoon the sweetened beans and nata de coco into the bottom of tall glasses.',
     'Pack shaved ice on top, high and loose.',
     'Pour evaporated milk over the ice until it runs down the sides.',
     'Crown with a spoonful of ube halaya.',
     'Hand it over with a long spoon and let them mix it themselves.'),
   '{vegetarian}'::dietary_tag[], '{summer,no_cook,sweet}'::text[]),

  ('Champorado',
   'Chocolate rice porridge. Breakfast that tastes like being eight years old.',
   'filipino', 'breakfast'::meal_category, 'easy'::difficulty,
   30, 110.00, 4, 340,
   jsonb_build_array(
     'Boil the glutinous rice in plenty of water, stirring often.',
     'When the grains soften, drop in the tablea and stir until it dissolves.',
     'Keep stirring. It thickens quickly and catches on the bottom if you stop.',
     'Sweeten to taste and cook to the thickness of loose porridge.',
     'Serve with condensed milk swirled in at the table.'),
   '{vegetarian}'::dietary_tag[], '{comfort,rainy_day,sweet}'::text[]),

  -- =========================================================================
  -- Japanese · 8
  -- =========================================================================
  ('Chicken Katsu Curry',
   'Crisp cutlet, thick curry, rice. The most reliable dinner in this list.',
   'japanese', 'dinner'::meal_category, 'medium'::difficulty,
   50, 340.00, 3, 720,
   jsonb_build_array(
     'Simmer the potato and carrot in water until tender.',
     'Break in the curry roux and stir until it thickens. Keep it warm.',
     'Butterfly the chicken, then flour, egg and panko each piece, pressing firmly.',
     'Shallow-fry until deep gold, four minutes a side, and rest on a rack.',
     'Slice across the cutlet and lay it beside rice with the curry poured over.'),
   '{}'::dietary_tag[], '{comfort,fried,crowd_pleaser}'::text[]),

  ('Salmon Teriyaki',
   'Four ingredients, one pan, twenty-five minutes. Nothing to hide behind.',
   'japanese', 'dinner'::meal_category, 'easy'::difficulty,
   25, 420.00, 2, 480,
   jsonb_build_array(
     'Pat the salmon dry and season it lightly.',
     'Sear skin-side down in a hot pan until the skin crisps, then turn.',
     'Mix soy sauce, mirin, sugar and grated ginger.',
     'Pour the sauce in and let it bubble down around the fish, spooning it over.',
     'Lift out while the centre is still just translucent.'),
   '{pescatarian}'::dietary_tag[], '{quick,healthy,high_protein}'::text[]),

  ('Tamagoyaki',
   'Rolled omelette, faintly sweet. Practice makes it neat.',
   'japanese', 'breakfast'::meal_category, 'medium'::difficulty,
   15, 90.00, 2, 220,
   jsonb_build_array(
     'Beat the eggs with mirin, sugar and a pinch of salt, then strain.',
     'Oil a small pan lightly and pour in a thin layer.',
     'When it sets underneath but is still wet on top, roll it to one side.',
     'Oil again, add another layer, lift the roll so the egg runs beneath, and roll on.',
     'Shape in a bamboo mat or with the pan edge, then slice into thick pieces.'),
   '{vegetarian,gluten_free}'::dietary_tag[], '{quick,bento,budget}'::text[]),

  ('Miso Soup',
   'Kombu broth, miso, tofu. Fifteen minutes and the table feels set.',
   'japanese', 'snack'::meal_category, 'easy'::difficulty,
   15, 110.00, 4, 90,
   jsonb_build_array(
     'Soak the kombu in cold water, then heat it slowly to just below a simmer.',
     'Lift the kombu out before it boils, or the broth turns bitter.',
     'Slide in the cubed tofu and warm it through.',
     'Take the pot off the heat, then whisk the miso in through a ladle.',
     'Never boil miso. Scatter spring onion and serve.'),
   '{vegetarian,vegan}'::dietary_tag[], '{light,soup,meatless}'::text[]),

  ('Oyakodon',
   'Chicken and egg over rice. Named for the pair, and it takes one pan.',
   'japanese', 'lunch'::meal_category, 'easy'::difficulty,
   25, 230.00, 2, 620,
   jsonb_build_array(
     'Simmer sliced onion in soy sauce, mirin and a splash of water.',
     'Add the chicken in one layer and cook until just done.',
     'Beat the eggs loosely. Streaks are the point.',
     'Pour them over and cover for a minute, until barely set.',
     'Slide the whole thing onto hot rice while the egg is still soft.'),
   '{}'::dietary_tag[], '{quick,one_pan,comfort}'::text[]),

  ('Yakisoba',
   'Noodles fried with pork and cabbage in a tangy brown sauce.',
   'japanese', 'lunch'::meal_category, 'easy'::difficulty,
   25, 240.00, 3, 540,
   jsonb_build_array(
     'Loosen the noodles under warm water so they separate.',
     'Fry the pork in a very hot pan until the fat renders.',
     'Add the cabbage and carrot and keep everything moving.',
     'Push in the noodles, then the worcestershire sauce, and toss to coat.',
     'Leave it alone for a moment at the end so parts of it catch and crisp.'),
   '{}'::dietary_tag[], '{quick,one_pan,street_food}'::text[]),

  ('Onigiri',
   'Rice, tuna, a strip of nori. Cold food that survives a bag.',
   'japanese', 'snack'::meal_category, 'easy'::difficulty,
   20, 100.00, 3, 260,
   jsonb_build_array(
     'Season warm rice with a little salt and let it cool enough to handle.',
     'Mix the drained tuna with mayonnaise.',
     'Wet your hands, take a handful of rice and press a dimple into it.',
     'Spoon the filling in, close the rice over it and shape a firm triangle.',
     'Wrap with nori just before eating so it stays crisp.'),
   '{pescatarian}'::dietary_tag[], '{bento,no_cook,leftovers}'::text[]),

  ('Matcha Mochi',
   'Chewy, green, faintly bitter. Sweet without being a cake.',
   'japanese', 'dessert'::meal_category, 'medium'::difficulty,
   40, 160.00, 6, 240,
   jsonb_build_array(
     'Whisk the glutinous rice flour, sugar and matcha with the coconut milk until smooth.',
     'Cover and steam for 20 minutes, stirring once halfway.',
     'The dough is ready when it turns glossy and pulls away from the bowl.',
     'Cool until handleable, then dust a surface with more rice flour.',
     'Cut into squares with an oiled knife and dust to stop them sticking.'),
   '{vegetarian,gluten_free}'::dietary_tag[], '{chewy,make_ahead,sweet}'::text[]),

  -- =========================================================================
  -- Korean · 7
  -- =========================================================================
  ('Kimchi Jjigae',
   'The stew that gets better as the kimchi gets older.',
   'korean', 'dinner'::meal_category, 'easy'::difficulty,
   35, 280.00, 3, 410,
   jsonb_build_array(
     'Fry the pork belly in a dry pot until the fat renders out.',
     'Add the kimchi and its juice and fry it hard for five minutes.',
     'Stir in the gochugaru, then cover with water and bring to a boil.',
     'Simmer for 15 minutes, then add the tofu in slabs and warm through.',
     'Finish with spring onion. Serve with rice, not bread.'),
   '{}'::dietary_tag[], '{spicy,soup,comfort}'::text[]),

  ('Bibimbap',
   'A bowl arranged in sections, then ruined on purpose.',
   'korean', 'lunch'::meal_category, 'medium'::difficulty,
   40, 260.00, 2, 620,
   jsonb_build_array(
     'Season and fry the beef quickly in a hot pan, then set it aside.',
     'Blanch the spinach and bean sprouts separately and dress each with sesame oil.',
     'Julienne and fry the carrot until just soft.',
     'Pack hot rice into bowls and arrange each component in its own wedge.',
     'Top with a fried egg and gochujang, and stir it all together at the table.'),
   '{}'::dietary_tag[], '{colourful,balanced,leftovers}'::text[]),

  ('Korean Fried Chicken',
   'Twice-fried, sauced hot, eaten immediately. The crunch is the whole point.',
   'korean', 'dinner'::meal_category, 'medium'::difficulty,
   50, 380.00, 4, 780,
   jsonb_build_array(
     'Dry the wings thoroughly and toss them in corn starch with salt.',
     'Fry at a moderate heat for eight minutes, then lift out and rest.',
     'Raise the heat and fry again for three minutes, until hard and blistered.',
     'Simmer gochujang, honey, garlic and soy into a glossy sauce.',
     'Toss the wings in the sauce off the heat and scatter sesame seeds.'),
   '{}'::dietary_tag[], '{party,fried,spicy}'::text[]),

  ('Tteokbokki',
   'Chewy rice cakes in a sweet, hot sauce. Ready before you change your mind.',
   'korean', 'snack'::meal_category, 'easy'::difficulty,
   25, 180.00, 2, 460,
   jsonb_build_array(
     'Soak the rice cakes in warm water for ten minutes if they are firm.',
     'Bring water, gochujang, gochugaru and sugar to a simmer.',
     'Add the rice cakes and stir often so they do not stick.',
     'Cook until the sauce thickens enough to coat, about eight minutes.',
     'Finish with spring onion and let it sit two minutes before eating.'),
   '{vegetarian}'::dietary_tag[], '{spicy,street_food,quick}'::text[]),

  ('Japchae',
   'Glass noodles, beef and vegetables, each cooked apart and tossed together.',
   'korean', 'lunch'::meal_category, 'medium'::difficulty,
   40, 260.00, 4, 430,
   jsonb_build_array(
     'Boil the sweet potato noodles for six minutes, rinse, and cut them roughly.',
     'Fry the beef, mushroom and carrot separately so nothing steams.',
     'Blanch the spinach and squeeze it dry.',
     'Toss everything with soy sauce, sesame oil and a little sugar.',
     'Serve at room temperature. It is better after twenty minutes.'),
   '{}'::dietary_tag[], '{party,colourful,make_ahead}'::text[]),

  ('Samgyeopsal',
   'Pork belly grilled at the table and eaten in lettuce. Sharing, not plating.',
   'korean', 'dinner'::meal_category, 'easy'::difficulty,
   30, 420.00, 3, 690,
   jsonb_build_array(
     'Slice the pork belly thick, about a centimetre.',
     'Heat a grill pan hard. No oil. The belly brings its own.',
     'Grill in batches without crowding, turning once, until the edges crisp.',
     'Cut into strips with scissors as it comes off the heat.',
     'Wrap in lettuce with a slice of grilled garlic and a dab of sesame oil and salt.'),
   '{low_carb}'::dietary_tag[], '{grilled,sharing,weekend}'::text[]),

  ('Hotteok',
   'Yeasted pancakes with a molten brown sugar and peanut middle.',
   'korean', 'dessert'::meal_category, 'medium'::difficulty,
   45, 120.00, 5, 310,
   jsonb_build_array(
     'Warm the milk, stir in the yeast and a spoon of sugar, and wait until it foams.',
     'Mix into the flour with a pinch of salt and knead to a soft dough.',
     'Cover and leave until doubled, about an hour.',
     'Mix brown sugar with crushed peanuts for the filling.',
     'Fill each ball, seal it, then press flat in an oiled pan and fry both sides.'),
   '{vegetarian}'::dietary_tag[], '{street_food,sweet,baking}'::text[]),

  -- =========================================================================
  -- Chinese · 7
  -- =========================================================================
  ('Beef and Broccoli',
   'A stir-fry that lives or dies on how hot the pan is.',
   'chinese', 'dinner'::meal_category, 'easy'::difficulty,
   25, 340.00, 3, 420,
   jsonb_build_array(
     'Slice the beef thinly across the grain and toss it with corn starch and soy sauce.',
     'Blanch the broccoli for 90 seconds and drain it well.',
     'Get the pan smoking, then sear the beef in one layer without stirring.',
     'Add garlic, oyster sauce and a splash of water and let it bubble.',
     'Return the broccoli and toss until the sauce glosses everything.'),
   '{}'::dietary_tag[], '{quick,stir_fry,high_protein}'::text[]),

  ('Yang Chow Fried Rice',
   'The fried rice that empties the fridge and still looks deliberate.',
   'chinese', 'lunch'::meal_category, 'easy'::difficulty,
   25, 240.00, 4, 520,
   jsonb_build_array(
     'Use cold day-old rice, broken up with your fingers.',
     'Scramble the eggs first, roughly, and lift them out.',
     'Fry the shrimp until just pink, then the carrot and corn.',
     'Add the rice and press it flat in the pan before tossing.',
     'Return the egg, season with soy sauce and finish with spring onion.'),
   '{}'::dietary_tag[], '{leftovers,one_pan,party}'::text[]),

  ('Sweet and Sour Pork',
   'Crisp pork, sharp sauce, pineapple. Sauce it at the last second.',
   'chinese', 'dinner'::meal_category, 'medium'::difficulty,
   40, 300.00, 4, 610,
   jsonb_build_array(
     'Cube the pork and toss it in corn starch until dry to the touch.',
     'Fry in batches until pale, rest, then fry again hot until crisp.',
     'Simmer ketchup, vinegar and sugar into a syrupy sauce.',
     'Stir-fry the bell pepper and pineapple briefly, keeping them firm.',
     'Add the pork and sauce, toss twice, and serve at once.'),
   '{}'::dietary_tag[], '{crowd_pleaser,fried,sweet}'::text[]),

  ('Wonton Noodle Soup',
   'Clear broth, thin noodles, pork dumplings. Fold a big batch and freeze them.',
   'chinese', 'lunch'::meal_category, 'medium'::difficulty,
   45, 260.00, 3, 480,
   jsonb_build_array(
     'Mix the pork with ginger, soy sauce and sesame oil.',
     'Spoon a little onto each wrapper, wet the edge and pleat it closed.',
     'Simmer a broth of ginger, spring onion and stock, and keep it clear.',
     'Boil the wontons in water until they float, then lift them into bowls.',
     'Cook the noodles separately, add the bok choy, and ladle the broth over.'),
   '{}'::dietary_tag[], '{comfort,soup,make_ahead}'::text[]),

  ('Mapo Tofu',
   'Silken tofu in a numbing chili sauce. Thirty minutes, mostly waiting.',
   'chinese', 'dinner'::meal_category, 'easy'::difficulty,
   30, 200.00, 3, 380,
   jsonb_build_array(
     'Toast the sichuan peppercorns dry, then crush them.',
     'Brown the ground pork hard, until it stops releasing liquid.',
     'Add the chili bean paste and fry until the oil turns red.',
     'Pour in water, slide in the cubed tofu and simmer without stirring.',
     'Thicken with a corn starch slurry, then add the pepper and spring onion.'),
   '{}'::dietary_tag[], '{spicy,quick,rice_partner}'::text[]),

  ('Siomai',
   'Steamed pork and shrimp dumplings. Better than the ones at the corner.',
   'chinese', 'snack'::meal_category, 'medium'::difficulty,
   45, 220.00, 6, 290,
   jsonb_build_array(
     'Chop the shrimp coarsely and mix it with the pork, carrot and sesame oil.',
     'Chill the filling for 15 minutes so it holds together.',
     'Push a spoonful into each wrapper and squeeze it into an open cup.',
     'Steam over a rolling boil for 12 minutes, lined so they do not stick.',
     'Serve with soy sauce, calamansi and chili oil.'),
   '{}'::dietary_tag[], '{make_ahead,steamed,party}'::text[]),

  ('Buchi',
   'Sesame-covered glutinous balls with sweet bean inside. Merienda, always.',
   'chinese', 'dessert'::meal_category, 'medium'::difficulty,
   50, 140.00, 8, 260,
   jsonb_build_array(
     'Mix the glutinous rice flour and sugar with hot water into a soft dough.',
     'Roll into balls, flatten each, and enclose a spoon of sweetened bean paste.',
     'Roll between wet palms, then coat thoroughly in sesame seeds.',
     'Fry in moderate oil, moving them constantly so they puff evenly.',
     'They are done when they float and the shell sounds hollow.'),
   '{vegetarian}'::dietary_tag[], '{fried,chewy,merienda}'::text[]),

  -- =========================================================================
  -- Italian · 7
  -- =========================================================================
  ('Spaghetti Aglio e Olio',
   'Pasta, garlic, oil, chili. Nothing to buy and nowhere to hide.',
   'italian', 'dinner'::meal_category, 'easy'::difficulty,
   20, 150.00, 2, 520,
   jsonb_build_array(
     'Salt the pasta water properly. It is the only seasoning here.',
     'Slice the garlic thinly and warm it in olive oil over a low heat.',
     'Do not let the garlic brown. Pale gold and it is already too far.',
     'Add chili, a ladle of pasta water, and swirl until it turns creamy.',
     'Toss the drained pasta through with parsley and finish off the heat.'),
   '{vegetarian,vegan}'::dietary_tag[], '{budget,quick,pantry}'::text[]),

  ('Carbonara',
   'Egg, cheese, pork, pepper. No cream, and the pan comes off the heat.',
   'italian', 'dinner'::meal_category, 'easy'::difficulty,
   25, 280.00, 3, 680,
   jsonb_build_array(
     'Beat the eggs with grated parmesan and a lot of black pepper.',
     'Render the bacon slowly until crisp, and keep the fat.',
     'Cook the pasta and save a mug of the water.',
     'Off the heat, toss the pasta with the bacon fat, then the egg mixture.',
     'Loosen with pasta water until it flows. If it scrambles, the pan was too hot.'),
   '{}'::dietary_tag[], '{quick,rich,crowd_pleaser}'::text[]),

  ('Margherita Pizza',
   'Dough, tomato, mozzarella, basil. A weekend that smells right.',
   'italian', 'dinner'::meal_category, 'medium'::difficulty,
   90, 320.00, 4, 620,
   jsonb_build_array(
     'Mix flour, yeast, salt and water into a shaggy dough and knead ten minutes.',
     'Rise until doubled, about an hour, then divide and shape.',
     'Crush the tomatoes by hand and season them. Do not cook them.',
     'Heat the oven and a tray as hot as they go.',
     'Stretch, top thinly, and bake seven minutes. Basil goes on after.'),
   '{vegetarian}'::dietary_tag[], '{weekend,baking,sharing}'::text[]),

  ('Chicken Parmigiana',
   'Breaded chicken under tomato and cheese. Nobody has ever refused it.',
   'italian', 'dinner'::meal_category, 'medium'::difficulty,
   50, 360.00, 3, 700,
   jsonb_build_array(
     'Flatten the chicken breasts to an even thickness.',
     'Flour, egg and crumb each one, pressing the coating on.',
     'Fry until gold on both sides. It finishes in the oven.',
     'Sit them in a dish, spoon tomato sauce over and cover with the cheeses.',
     'Bake for 15 minutes, until the cheese blisters and the sauce bubbles at the edge.'),
   '{}'::dietary_tag[], '{comfort,baking,crowd_pleaser}'::text[]),

  ('Minestrone',
   'Whatever vegetables you have, plus beans and a handful of pasta.',
   'italian', 'lunch'::meal_category, 'easy'::difficulty,
   40, 180.00, 4, 260,
   jsonb_build_array(
     'Sweat the onion, carrot and celery slowly in oil for ten minutes.',
     'Add the tomatoes and let them cook down before adding liquid.',
     'Cover with water, add the beans, and simmer for 20 minutes.',
     'Stir in the zucchini and the pasta and cook until the pasta is done.',
     'Season hard at the end. Minestrone needs more salt than you expect.'),
   '{vegetarian,vegan}'::dietary_tag[], '{soup,meatless,healthy}'::text[]),

  ('Pesto Pasta',
   'Basil pounded with nuts and cheese. Twenty minutes, no cooking beyond pasta.',
   'italian', 'lunch'::meal_category, 'easy'::difficulty,
   20, 240.00, 2, 580,
   jsonb_build_array(
     'Toast the pine nuts dry until they smell nutty, then cool them.',
     'Blend basil, nuts, garlic and parmesan, trickling in oil.',
     'Stop while it still has texture. Over-blending turns it bitter and dull.',
     'Toss with hot pasta off the heat, loosened with pasta water.',
     'Never cook pesto in the pan. Heat is what kills the colour.'),
   '{vegetarian}'::dietary_tag[], '{quick,fresh,meatless}'::text[]),

  ('Tiramisu',
   'Coffee, mascarpone, cocoa. No oven, but it needs a night in the fridge.',
   'italian', 'dessert'::meal_category, 'medium'::difficulty,
   40, 320.00, 6, 440,
   jsonb_build_array(
     'Whisk the yolks with sugar over simmering water until pale and thick.',
     'Cool, then fold in the mascarpone until smooth.',
     'Whip the whites separately and fold them through in two additions.',
     'Dip each biscuit in strong coffee for one second only. Longer and it collapses.',
     'Layer biscuit and cream twice, then chill overnight and dust with cocoa.'),
   '{vegetarian}'::dietary_tag[], '{no_bake,make_ahead,special_occasion}'::text[]),

  -- =========================================================================
  -- Mexican · 5
  -- =========================================================================
  ('Chicken Tacos',
   'Spiced chicken, cabbage, lime. Put it on the table and let people build.',
   'mexican', 'dinner'::meal_category, 'easy'::difficulty,
   30, 280.00, 3, 520,
   jsonb_build_array(
     'Toss the diced chicken with cumin, chili powder, salt and lime juice.',
     'Fry hot in a wide pan until the edges catch.',
     'Shred the cabbage finely and dress it with lime and salt.',
     'Warm the tortillas one at a time in a dry pan until they puff.',
     'Fill, top with cilantro, and squeeze more lime over than feels sensible.'),
   '{}'::dietary_tag[], '{quick,sharing,fresh}'::text[]),

  ('Beef Burrito',
   'Everything rolled into one thing you can eat with one hand.',
   'mexican', 'lunch'::meal_category, 'easy'::difficulty,
   30, 300.00, 2, 780,
   jsonb_build_array(
     'Brown the beef with onion, cumin and chili powder until dry.',
     'Warm the beans through and mash about half of them.',
     'Have the rice hot and seasoned with lime and salt.',
     'Warm the tortillas until pliable, or they will crack when rolled.',
     'Layer in a line, fold the ends in, roll tight, and sear the seam in a dry pan.'),
   '{}'::dietary_tag[], '{filling,portable,budget}'::text[]),

  ('Quesadillas',
   'Cheese between tortillas. Fifteen minutes and everybody is happy.',
   'mexican', 'snack'::meal_category, 'easy'::difficulty,
   15, 160.00, 2, 480,
   jsonb_build_array(
     'Slice the pepper and onion thinly and fry them until soft and sweet.',
     'Grate the cheese. Sliced cheese slides out and burns in the pan.',
     'Cover half a tortilla with cheese, add the vegetables, and fold it over.',
     'Dry-fry over medium heat, pressing down, until the cheese runs.',
     'Rest one minute before cutting, or the filling escapes.'),
   '{vegetarian}'::dietary_tag[], '{quick,meatless,kid_friendly}'::text[]),

  ('Chili con Carne',
   'A pot of beef and beans that is better tomorrow than today.',
   'mexican', 'dinner'::meal_category, 'easy'::difficulty,
   60, 320.00, 4, 560,
   jsonb_build_array(
     'Brown the beef in batches. Crowding the pan steams it grey.',
     'Add onion, cumin and chili powder and fry until the spices smell toasted.',
     'Pour in the tomatoes, scraping the base, and bring to a simmer.',
     'Add the beans and cook uncovered for 40 minutes, stirring now and then.',
     'Season at the end and let it sit off the heat for ten minutes.'),
   '{gluten_free}'::dietary_tag[], '{make_ahead,one_pot,batch}'::text[]),

  ('Churros',
   'Piped dough fried and rolled in sugar, with chocolate to dip.',
   'mexican', 'dessert'::meal_category, 'medium'::difficulty,
   35, 140.00, 4, 380,
   jsonb_build_array(
     'Boil water with butter and salt, then beat in the flour all at once.',
     'Cook the paste on the heat for two minutes until it leaves the pan clean.',
     'Cool slightly, then beat the eggs in one at a time.',
     'Pipe lengths straight into moderate oil and fry until deep gold.',
     'Roll in sugar while hot and serve with warm chocolate.'),
   '{vegetarian}'::dietary_tag[], '{fried,street_food,sharing}'::text[]),

  -- =========================================================================
  -- American · 6
  -- =========================================================================
  ('Classic Cheeseburger',
   'Thin patty, hard sear, melted cheese. Do not press it while it cooks.',
   'american', 'dinner'::meal_category, 'easy'::difficulty,
   25, 280.00, 2, 720,
   jsonb_build_array(
     'Divide the beef and shape loose balls. Do not work the meat.',
     'Get a heavy pan very hot, then press each ball flat once and leave it.',
     'Season the top, flip after two minutes, and lay the cheese on straight away.',
     'Toast the buns cut-side down in the same pan.',
     'Build with mayonnaise, tomato and lettuce, and eat it immediately.'),
   '{}'::dietary_tag[], '{quick,comfort,grilled}'::text[]),

  ('Buttermilk Pancakes',
   'A stack for a slow morning. Lumpy batter is correct.',
   'american', 'breakfast'::meal_category, 'easy'::difficulty,
   20, 140.00, 4, 420,
   jsonb_build_array(
     'Whisk the dry ingredients, then the milk, egg and melted butter separately.',
     'Combine with a few strokes only. Lumps are what keep them light.',
     'Rest the batter ten minutes while the pan heats to medium.',
     'Cook until bubbles break on the surface, then turn once.',
     'Stack, and pour the honey over the whole tower rather than each layer.'),
   '{vegetarian}'::dietary_tag[], '{weekend,sweet,kid_friendly}'::text[]),

  ('Mac and Cheese',
   'A sauce, a pasta and a browned top. Grate the cheese yourself.',
   'american', 'dinner'::meal_category, 'easy'::difficulty,
   30, 240.00, 4, 660,
   jsonb_build_array(
     'Cook the macaroni one minute short. It finishes in the oven.',
     'Melt butter, stir in the flour and cook two minutes without colouring it.',
     'Add the milk a little at a time, whisking, until smooth and thick.',
     'Take it off the heat before stirring in the cheese, or it turns grainy.',
     'Fold through the pasta, top with more cheese and bake until blistered.'),
   '{vegetarian}'::dietary_tag[], '{comfort,kid_friendly,baking}'::text[]),

  ('Chicken Caesar Salad',
   'A salad that eats like a meal, on the strength of its dressing.',
   'american', 'lunch'::meal_category, 'easy'::difficulty,
   20, 260.00, 2, 430,
   jsonb_build_array(
     'Season the chicken and pan-fry it, then rest it before slicing.',
     'Mash the anchovies with garlic into a paste.',
     'Whisk in mayonnaise, lemon juice and grated parmesan.',
     'Tear the lettuce rather than cutting it, and keep it cold and dry.',
     'Dress at the last moment and shave more parmesan over the top.'),
   '{}'::dietary_tag[], '{healthy,quick,high_protein}'::text[]),

  ('BBQ Pork Ribs',
   'Three hours, mostly unattended. Sauce only at the end.',
   'american', 'dinner'::meal_category, 'hard'::difficulty,
   180, 520.00, 4, 820,
   jsonb_build_array(
     'Pull the membrane off the back of the rack. It never softens.',
     'Rub with paprika, brown sugar, garlic, salt and pepper.',
     'Wrap in foil and bake low, around 150 degrees, for two and a half hours.',
     'Unwrap, brush with sauce, and finish uncovered for 20 minutes.',
     'Rest ten minutes before cutting between the bones.'),
   '{}'::dietary_tag[], '{weekend,slow,sharing}'::text[]),

  ('Chocolate Chip Cookies',
   'Soft in the middle. Take them out before you think they are done.',
   'american', 'dessert'::meal_category, 'easy'::difficulty,
   30, 180.00, 12, 210,
   jsonb_build_array(
     'Beat the softened butter with the sugar until pale and light.',
     'Add the eggs one at a time, then the vanilla.',
     'Fold in the flour with a pinch of salt, stopping while streaks remain.',
     'Stir the chocolate through and chill the dough for 20 minutes.',
     'Bake nine to eleven minutes. The centres should still look underdone.'),
   '{vegetarian}'::dietary_tag[], '{baking,kid_friendly,make_ahead}'::text[])

)
insert into meals (
  name, description, cuisine, category, difficulty,
  cooking_time_minutes, estimated_cost, servings, calories,
  instructions, dietary_tags, tags, is_public
)
select
  name, description, cuisine, category, difficulty,
  minutes, cost, servings, calories,
  steps, diet, tags, true
from catalogue
on conflict (lower(name)) where is_public do update set
  description          = excluded.description,
  cuisine              = excluded.cuisine,
  category             = excluded.category,
  difficulty           = excluded.difficulty,
  cooking_time_minutes = excluded.cooking_time_minutes,
  estimated_cost       = excluded.estimated_cost,
  servings             = excluded.servings,
  calories             = excluded.calories,
  instructions         = excluded.instructions,
  dietary_tags         = excluded.dietary_tags,
  tags                 = excluded.tags,
  updated_at           = now();
