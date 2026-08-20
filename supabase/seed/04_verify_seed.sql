-- ===========================================================================
-- Seed 04 · Catalogue verification
--
-- Run after 01, 02 and 03. Every row must read PASS.
--
-- `verify.sql` at the root answers "did the schema apply?". This answers "is
-- the catalogue fit to spin?" — which is a different question, and a harder
-- one, because a catalogue can be present and still be wrong.
--
-- Each check states its own comparison rather than sharing one, because the
-- questions differ: some are minimums the catalogue may exceed as it grows,
-- and some are violation counts that must be exactly zero.
-- ===========================================================================

with

-- ---------------------------------------------------------------------------
-- Size and spread
-- ---------------------------------------------------------------------------
size_check as (
  select
    '01. catalogue size'  as check_name,
    count(*)::text        as found,
    'at least 60'         as expected,
    count(*) >= 60        as ok
  from meals where is_public
),

cuisine_spread as (
  -- Seven cuisines, and the roulette needs every one of them populated: a
  -- cuisine filter that resolves to an empty pool is the one outcome the
  -- product cannot survive (docs/USER_FLOWS.md §6).
  select
    '02. cuisines represented' as check_name,
    count(distinct cuisine)::text as found,
    '7'                        as expected,
    count(distinct cuisine) >= 7 as ok
  from meals where is_public
),

filipino_share as (
  -- docs/MVP_SCOPE.md: "Filipino-leaning". A quarter is the floor; below that
  -- the catalogue stops being the one these users wanted.
  select
    '03. Filipino share'                     as check_name,
    (count(*) filter (where cuisine = 'filipino'))::text as found,
    'at least a quarter of the catalogue'    as expected,
    (count(*) filter (where cuisine = 'filipino')) * 4 >= count(*) as ok
  from meals where is_public
),

category_spread as (
  select
    '04. meal categories represented' as check_name,
    count(distinct category)::text    as found,
    '5'                               as expected,
    count(distinct category) = 5      as ok
  from meals where is_public
),

thin_categories as (
  -- Not just present — usable. Three meals in a category means the same
  -- breakfast twice a week once Sprint 32 starts refusing repeats.
  select
    '05. no category thinner than 4' as check_name,
    coalesce(min(n), 0)::text        as found,
    'at least 4 in every category'   as expected,
    coalesce(min(n), 0) >= 4         as ok
  from (
    select count(*) as n from meals where is_public group by category
  ) per_category
),

-- ---------------------------------------------------------------------------
-- Completeness of each row
-- ---------------------------------------------------------------------------
visibility_check as (
  select
    '06. public meals own no household' as check_name,
    count(*)::text                      as found,
    '0'                                 as expected,
    count(*) = 0                        as ok
  from meals
  where is_public and household_id is not null
),

instruction_check as (
  -- A meal with no method is a name and a price. Sprint 23 renders these
  -- verbatim, so an empty array ships as an empty screen.
  select
    '07. every meal has 3+ steps' as check_name,
    count(*)::text                as found,
    '0 short of 3 steps'          as expected,
    count(*) = 0                  as ok
  from meals
  where is_public and jsonb_array_length(instructions) < 3
),

description_check as (
  select
    '08. every meal has a description' as check_name,
    count(*)::text                     as found,
    '0 missing'                        as expected,
    count(*) = 0                       as ok
  from meals
  where is_public
    and (description is null or length(trim(description)) < 20)
),

ingredient_count_check as (
  -- Two, not three. Tortang talong is an eggplant and an egg, and padding the
  -- recipe to clear a threshold would be worse data than the threshold is
  -- worth. This is a floor against a meal that lost its list entirely; the
  -- precise net for a misspelt ingredient is the left join in 03, which fails
  -- the insert and names the column.
  select
    '09. every meal has 2+ required ingredients' as check_name,
    count(*)::text                               as found,
    '0 short of 2'                               as expected,
    count(*) = 0                                 as ok
  from meals m
  where m.is_public
    and (
      select count(*) from meal_ingredients mi
      where mi.meal_id = m.id and not mi.is_optional
    ) < 2
),

orphan_check as (
  select
    '10. no meal without ingredients' as check_name,
    count(*)::text                    as found,
    '0'                               as expected,
    count(*) = 0                      as ok
  from meals m
  where m.is_public
    and not exists (
      select 1 from meal_ingredients mi where mi.meal_id = m.id
    )
),

-- ---------------------------------------------------------------------------
-- Plausibility
-- ---------------------------------------------------------------------------
cost_check as (
  -- Costs are estimates, but an estimate outside this range is a typo, and a
  -- typo here feeds the budget filter directly.
  select
    '11. costs are plausible in pesos' as check_name,
    count(*)::text                     as found,
    '0 outside 50-1500'                as expected,
    count(*) = 0                       as ok
  from meals
  where is_public and (estimated_cost < 50 or estimated_cost > 1500)
),

time_check as (
  select
    '12. cooking times are plausible' as check_name,
    count(*)::text                    as found,
    '0 outside 5-240 minutes'         as expected,
    count(*) = 0                      as ok
  from meals
  where is_public
    and (cooking_time_minutes < 5 or cooking_time_minutes > 240)
),

quick_meal_check as (
  -- docs/USER_FLOWS.md §6 offers "something quick" as a first-class filter. It
  -- has to land on something.
  select
    '13. enough meals under 30 minutes' as check_name,
    count(*)::text                      as found,
    'at least 12'                       as expected,
    count(*) >= 12                      as ok
  from meals
  where is_public and cooking_time_minutes <= 30
),

budget_meal_check as (
  -- Same argument for the budget filter. Per serving, not per meal, because
  -- that is what the filter compares.
  select
    '14. enough meals under 100 pesos a head' as check_name,
    count(*)::text                            as found,
    'at least 12'                             as expected,
    count(*) >= 12                            as ok
  from meals
  where is_public and estimated_cost / servings <= 100
),

tag_check as (
  select
    '15. every meal carries mood tags' as check_name,
    count(*)::text                     as found,
    '0 untagged'                       as expected,
    count(*) = 0                       as ok
  from meals
  where is_public and cardinality(tags) = 0
),

-- ---------------------------------------------------------------------------
-- Dietary tags — the checks that matter most
-- ---------------------------------------------------------------------------
-- Dietary tags are a hard filter, never a penalty
-- (supabase/migrations/…_preferences.sql). A wrong tag does not skew a score;
-- it offers someone food they will not eat. These four checks are the reason
-- this file exists.
--
-- The lists are spelled out rather than derived from `ingredients.category`,
-- because category is about where a thing sits in a shop and these questions
-- are about what it came from. Tofu and milk are not the same answer.
animal_flesh as (
  select unnest(array[
    'chicken thigh','chicken breast','whole chicken','chicken wing',
    'chicken liver','pork belly','pork shoulder','pork ribs','ground pork',
    'beef sirloin','ground beef','oxtail','beef tripe','bacon'
  ]) as name
),
seafood as (
  select unnest(array[
    'salmon fillet','canned tuna','shrimp','anchovy','shrimp paste',
    'fish sauce','oyster sauce'
  ]) as name
),
animal_products as (
  select unnest(array[
    'egg','milk','butter','cheddar cheese','mozzarella cheese',
    'parmesan cheese','mascarpone','condensed milk','evaporated milk','honey'
  ]) as name
),
gluten as (
  select unnest(array[
    'all-purpose flour','bread flour','spaghetti','macaroni','egg noodles',
    'panko breadcrumbs','wonton wrapper','lumpia wrapper','burger bun',
    'ladyfinger biscuit','soy sauce'
  ]) as name
),

vegetarian_check as (
  select
    '16. vegetarian meals contain no meat or fish' as check_name,
    count(*)::text                                as found,
    '0 violations'                                as expected,
    count(*) = 0                                  as ok
  from meals m
  join meal_ingredients mi on mi.meal_id = m.id
  join ingredients i on i.id = mi.ingredient_id
  where m.is_public
    and 'vegetarian' = any (m.dietary_tags)
    and i.name in (select name from animal_flesh union select name from seafood)
),

vegan_check as (
  select
    '17. vegan meals contain nothing from an animal' as check_name,
    count(*)::text                                   as found,
    '0 violations'                                   as expected,
    count(*) = 0                                     as ok
  from meals m
  join meal_ingredients mi on mi.meal_id = m.id
  join ingredients i on i.id = mi.ingredient_id
  where m.is_public
    and 'vegan' = any (m.dietary_tags)
    and i.name in (
      select name from animal_flesh
      union select name from seafood
      union select name from animal_products
    )
),

vegan_implies_vegetarian as (
  -- Every vegan meal is also vegetarian. A user who filtered on vegetarian and
  -- was denied a vegan meal would be right to find that strange.
  select
    '18. vegan meals are tagged vegetarian too' as check_name,
    count(*)::text                              as found,
    '0 missing the pair'                        as expected,
    count(*) = 0                                as ok
  from meals
  where is_public
    and 'vegan' = any (dietary_tags)
    and not ('vegetarian' = any (dietary_tags))
),

pescatarian_check as (
  select
    '19. pescatarian meals contain no meat' as check_name,
    count(*)::text                          as found,
    '0 violations'                          as expected,
    count(*) = 0                            as ok
  from meals m
  join meal_ingredients mi on mi.meal_id = m.id
  join ingredients i on i.id = mi.ingredient_id
  where m.is_public
    and 'pescatarian' = any (m.dietary_tags)
    and i.name in (select name from animal_flesh)
),

gluten_free_check as (
  -- Tortilla is deliberately absent from the gluten list: corn and wheat
  -- tortillas share a name, and the catalogue does not distinguish them yet.
  -- No gluten_free meal uses one, so the gap costs nothing today — but it is
  -- the thing to fix first if one ever does.
  select
    '20. gluten-free meals contain no wheat' as check_name,
    count(*)::text                           as found,
    '0 violations'                           as expected,
    count(*) = 0                             as ok
  from meals m
  join meal_ingredients mi on mi.meal_id = m.id
  join ingredients i on i.id = mi.ingredient_id
  where m.is_public
    and 'gluten_free' = any (m.dietary_tags)
    and i.name in (select name from gluten)
),

dietary_coverage as (
  -- A vegetarian user must be able to spin. Six is thin but workable across
  -- five categories; below that the filter is a dead end.
  select
    '21. enough vegetarian meals to spin' as check_name,
    count(*)::text                        as found,
    'at least 6'                          as expected,
    count(*) >= 6                         as ok
  from meals
  where is_public and 'vegetarian' = any (dietary_tags)
),

-- ---------------------------------------------------------------------------
-- The ingredient vocabulary
-- ---------------------------------------------------------------------------
staple_check as (
  select
    '22. staples are marked'    as check_name,
    count(*)::text              as found,
    'at least 8'                as expected,
    count(*) >= 8               as ok
  from ingredients where is_staple
),

unused_ingredients as (
  -- Informational, not a failure. `ingredients` is an append-only shared
  -- vocabulary (docs/DATABASE.md §4.6), and custom meals in Sprint 26 will
  -- reach for entries the catalogue does not use. A large number here means the
  -- vocabulary has drifted ahead of the catalogue, which is worth a look.
  select
    '23. ingredients used by no meal' as check_name,
    count(*)::text                    as found,
    'under 20 is healthy'             as expected,
    count(*) < 20                     as ok
  from ingredients i
  where not exists (
    select 1 from meal_ingredients mi where mi.ingredient_id = i.id
  )
),

unit_check as (
  -- docs/DATABASE.md §4.6 fixes the unit vocabulary. A stray unit breaks the
  -- grocery list's ability to add two quantities together (Sprint 50).
  select
    '24. units come from the fixed set' as check_name,
    count(*)::text                      as found,
    '0 unknown units'                   as expected,
    count(*) = 0                        as ok
  from (
    select default_unit as unit from ingredients
    union all
    select unit from meal_ingredients
  ) all_units
  where unit not in ('g','ml','pc','tbsp','tsp','cup')
)

select check_name, found, expected,
       case when ok then 'PASS' else 'FAIL' end as result
from (
  select * from size_check
  union all select * from cuisine_spread
  union all select * from filipino_share
  union all select * from category_spread
  union all select * from thin_categories
  union all select * from visibility_check
  union all select * from instruction_check
  union all select * from description_check
  union all select * from ingredient_count_check
  union all select * from orphan_check
  union all select * from cost_check
  union all select * from time_check
  union all select * from quick_meal_check
  union all select * from budget_meal_check
  union all select * from tag_check
  union all select * from vegetarian_check
  union all select * from vegan_check
  union all select * from vegan_implies_vegetarian
  union all select * from pescatarian_check
  union all select * from gluten_free_check
  union all select * from dietary_coverage
  union all select * from staple_check
  union all select * from unused_ingredients
  union all select * from unit_check
) checks
order by check_name;
