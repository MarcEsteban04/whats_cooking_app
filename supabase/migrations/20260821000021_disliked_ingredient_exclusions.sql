-- Sprint 35 — making disliked ingredients mean something.
--
-- Since migration 0011 the app has captured free-text foods a household avoids,
-- stored them in `user_preferences.disliked_ingredient_names`, and shown the
-- count on the profile screen under the words "We will never suggest these."
-- Nothing read them. The roulette has been offering meals built on the one
-- ingredient somebody told us they cannot stand, which is worse than never
-- having asked — a promise made in the interface and broken by the engine.
--
-- 0011 planned to reconcile those names into `disliked_ingredients` (uuid[]) and
-- have the engine filter on ids. **This resolves at query time instead**, and the
-- difference matters: a name that matches nothing today matches tomorrow when the
-- catalogue grows, and a one-off reconciliation at save time would never notice.
-- Names stay the source of truth. `disliked_ingredients` remains for the pantry
-- and grocery features (Sprint 48+), which genuinely do want a stable id.

-- ---------------------------------------------------------------------------
-- Normalising a typed food to the catalogue's own spelling.
-- ---------------------------------------------------------------------------
--
-- `ingredients.name` is constrained to `lower(trim(name))`, so the catalogue side
-- needs nothing. This is the other side: what somebody types into a text field at
-- eleven at night.
create or replace function public.normalize_food_name(raw text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select nullif(regexp_replace(lower(trim(raw)), '\s+', ' ', 'g'), '')
$$;

comment on function public.normalize_food_name(text) is
  'Lowercases, trims and collapses internal whitespace. Matches the constraint on ingredients.name.';

-- ---------------------------------------------------------------------------
-- The meals the caller's disliked foods rule out.
-- ---------------------------------------------------------------------------
--
-- Reads the caller's own preferences via auth.uid() rather than taking a list of
-- names as an argument. Two reasons: the list never leaves the database, and
-- there is no parameter for a client to get wrong — a spin cannot accidentally
-- ask for somebody else's exclusions, or forget to ask for its own.
--
-- **Matching is exact, plus the obvious plural.** "onion" is typed and "onions"
-- is in the catalogue, or the reverse; that pair is worth handling and is where
-- the cleverness stops. Substring matching was the tempting version and it is
-- badly wrong here: `name like '%egg%'` throws away every aubergine recipe for
-- somebody who cannot eat eggs, and `'%oil%'` takes out anything with boiled
-- potatoes. An exclusion that silently over-excludes is indistinguishable from an
-- empty catalogue, and the reader has no way to find out why.
--
-- **Optional ingredients do not block.** A recipe listing coriander as a garnish
-- is a recipe somebody who hates coriander can cook, and excluding it would cost
-- them dinner over something they were always going to leave out.
create or replace function public.meals_blocked_by_dislikes()
returns table (meal_id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
  with typed as (
    select distinct public.normalize_food_name(entry) as name
    from public.user_preferences up
    cross join unnest(up.disliked_ingredient_names) as entry
    where up.user_id = auth.uid()
  ),
  -- The catalogue rows those names reach: an exact hit, or the same word with a
  -- trailing "s" on either side of the comparison.
  matched as (
    select i.id
    from public.ingredients i
    join typed t
      on i.name = t.name
      or i.name = t.name || 's'
      or t.name = i.name || 's'
  )
  select distinct mi.meal_id
  from public.meal_ingredients mi
  join matched m on m.id = mi.ingredient_id
  where mi.is_optional = false
$$;

comment on function public.meals_blocked_by_dislikes() is
  'Meal ids the caller''s disliked_ingredient_names rule out. Exact plus simple-plural matching; optional ingredients do not block. Sprint 35.';

-- Callable by a signed-in user only. `anon` is deliberately not granted: the
-- function reads the caller's preferences, and there are none without a session.
grant execute on function public.normalize_food_name(text) to authenticated, anon;
grant execute on function public.meals_blocked_by_dislikes() to authenticated;

-- The join this function lives on. `meal_ingredients (ingredient_id)` already
-- exists from 0008; this is the other side, so a lookup by name does not scan the
-- catalogue.
create index if not exists ingredients_name_idx on public.ingredients (name);

-- ---------------------------------------------------------------------------
-- Cooking preferences: how much effort a household wants to be offered.
-- ---------------------------------------------------------------------------
--
-- The roulette has been able to filter by difficulty for a session since Sprint
-- 29, but there was nowhere to say it once and mean it — so somebody who never
-- wants a three-hour braise on a weeknight had to re-say so on every spin. This
-- is the standing answer, and it seeds the filter the same way `default_budget`
-- and `max_cooking_time` already do.
--
-- Null means no preference, which is not the same as 'easy'.
alter table public.user_preferences
  add column if not exists max_difficulty difficulty;

comment on column public.user_preferences.max_difficulty is
  'Hardest recipe the household wants offered. Null means no preference. Seeds the roulette difficulty filter. Sprint 35.';
