-- Sprint 41 — what we can cook with what is in.
--
-- The pantry has existed since Sprint 39 and nothing has read it. This is the
-- function that makes it worth filling in, and the one that finally applies the
-- `ingredientMatch` weight the scorer has been declaring since Sprint 33.
--
-- **Server-side, and that is a payload decision rather than a preference.** The
-- spin fetches up to 200 candidate meals with `meals`-only columns; adding the
-- ingredient join would bring roughly six nested rows per meal into the one
-- interaction that must not wait. This returns one small row per meal instead —
-- two integers and at most three names.
--
-- It is also the same shape as `meals_blocked_by_dislikes` from Sprint 35: the
-- caller's own data never leaves the database, and there is no argument for a
-- client to get wrong.

-- ---------------------------------------------------------------------------
-- How much of each meal is already in the kitchen.
-- ---------------------------------------------------------------------------
--
-- **Staples and optional ingredients are out of the denominator**, which is the
-- rule docs/USER_FLOWS.md §12 states as an acceptance criterion: "salt, pepper,
-- oil, water, common seasonings are assumed present and never reduce a match
-- percentage. Otherwise every meal caps around 80% and the number stops meaning
-- anything."
--
-- Optional goes for the same reason plus a better one: a recipe listing coriander
-- as a garnish is a recipe somebody can cook without it, so counting it as missing
-- would report 80% for a meal that is actually ready.
--
-- **`needed = 0` is a real answer.** A meal whose every ingredient is a staple has
-- nothing to be missing, and the caller treats it as complete rather than as a
-- division by zero.
create or replace function public.pantry_match()
returns table (
  meal_id uuid,
  needed integer,
  have integer,
  missing text[]
)
language sql
stable
security invoker
set search_path = ''
as $$
  with kitchen as (
    select pi.ingredient_id
    from public.pantry_items pi
    join public.profiles p on p.active_household_id = pi.household_id
    where p.id = auth.uid()
  ),
  -- Every ingredient that actually counts, with whether we have it.
  required as (
    select
      mi.meal_id,
      mi.ingredient_id,
      i.name,
      (k.ingredient_id is not null) as in_kitchen
    from public.meal_ingredients mi
    join public.ingredients i on i.id = mi.ingredient_id
    left join kitchen k on k.ingredient_id = mi.ingredient_id
    where mi.is_optional = false
      and i.is_staple = false
  )
  select
    r.meal_id,
    count(*)::integer as needed,
    count(*) filter (where r.in_kitchen)::integer as have,
    -- At most three names, alphabetical. The result screen can say "everything
    -- but the bay leaves" for one or two; "everything but nine things" is not a
    -- sentence, so past that the count carries the meaning and the names are
    -- noise on the wire.
    (
      array_agg(r.name order by r.name)
      filter (where not r.in_kitchen)
    )[1:3] as missing
  from required r
  group by r.meal_id
$$;

comment on function public.pantry_match() is
  'Per meal: how many non-staple, non-optional ingredients it needs, how many are in the caller''s pantry, and up to three of the missing names. Sprint 41.';

-- Authenticated only. The function reads the caller's pantry, and there is none
-- without a session.
grant execute on function public.pantry_match() to authenticated;

-- The lookup this function leans on. `pantry_items` is already indexed by its
-- unique `(household_id, ingredient_id)`, and `meal_ingredients` by both sides
-- from migration 0008 — this is the one remaining hop, from a household to its
-- pantry rows.
create index if not exists pantry_items_household_idx
  on public.pantry_items (household_id);
