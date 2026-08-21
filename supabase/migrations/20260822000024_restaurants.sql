-- Sprint 45 — the other library.
--
-- Some nights nobody is cooking. "Where should we eat?" is the same argument with
-- the same non-answer, so it gets the same solution: a list we wrote, and a spin
-- over it (Sprint 46).
--
-- **Manually added, with no discovery layer.** No maps, no ratings API, no
-- location search. A list of places we already like is better than every
-- restaurant in the city, and it needs no third-party dependency to keep working.

-- ---------------------------------------------------------------------------
-- How far away, as a decision rather than a distance.
-- ---------------------------------------------------------------------------
--
-- Kilometres would need a location permission, a maps provider and a coordinate
-- per row, to produce a number nobody uses. The real question at seven in the
-- evening is *can we walk, do we have to ride, or is it a trip* — three values
-- answer it and cost nothing.
do $$ begin
  create type proximity as enum ('walk','short_ride','worth_the_trip');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- The places we go.
-- ---------------------------------------------------------------------------
--
-- **Always household-scoped, unlike `meals`.** There is no public catalogue of
-- restaurants and there should not be: a seeded list of places somebody else likes
-- in a city we may not live in is worse than an empty screen, because an empty
-- screen at least asks the right question. So `household_id` is `not null` here
-- where on `meals` it is nullable, and there is no `is_public` column to reason
-- about.
create table if not exists public.restaurants (
  id             uuid primary key default gen_random_uuid(),
  household_id   uuid not null references public.households (id) on delete cascade,

  name           text not null check (length(trim(name)) > 0),

  -- The same twelve values `meals.cuisine` uses, as a text check for the same
  -- reason that column is: the list is app vocabulary that changes with releases,
  -- and widening a check is a migration where widening an enum is a migration plus
  -- a lock.
  cuisine        text not null check (
    cuisine in (
      'filipino','japanese','korean','chinese','thai','vietnamese',
      'italian','mexican','american','indian','mediterranean','other'
    )
  ),

  -- A head, not a bill. The number both roulettes filter on, and the number two
  -- people actually think in.
  cost_per_head  numeric(10,2) not null check (cost_per_head >= 0),

  proximity      proximity not null default 'short_ride',
  delivers       boolean not null default false,

  notes          text,

  -- What we get there. The single most useful field on the table, and the reason
  -- this is a list we keep rather than a maps integration — no API returns it.
  go_to_order    text,

  -- So the moods work over restaurants too (Sprint 46). Same vocabulary as
  -- `meals.tags`: `comfort`, `spicy`, `budget`, `sharing`.
  tags           text[] not null default '{}',

  -- Ours, in the same sense a saved meal is. A boolean rather than a join table,
  -- and that is a deliberate difference from `favorite_meals`: that table exists
  -- because meals are shared and public while a favourite is one person's opinion.
  -- These rows are household-private and written by the only person who edits
  -- them, so a per-user join table would be a second table and a join for nothing.
  is_favorite    boolean not null default false,

  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- The same place added twice is a data-entry slip, not two restaurants.
  constraint restaurants_name_unique unique (household_id, name)
);

comment on table public.restaurants is
  'Places the household eats out at. Manually curated, always household-scoped, no discovery layer. Sprint 45.';

comment on column public.restaurants.go_to_order is
  'What we order there. No API returns this, which is why the list is kept by hand.';

-- There is deliberately **no `is_hidden`**, unlike `disliked_meals`. Hiding exists
-- for meals because the catalogue is public and cannot be deleted; every row here
-- is one we wrote, so deleting it is available and honest. A flag that means
-- "deleted but not really" is a flag somebody has to remember the rules of.

-- The query the list screen makes: one household's places, favourites first, then
-- by name.
create index if not exists restaurants_household_idx
  on public.restaurants (household_id, is_favorite desc, name);

-- The filters Sprint 46's roulette will apply.
create index if not exists restaurants_household_cuisine_idx
  on public.restaurants (household_id, cuisine);
create index if not exists restaurants_household_cost_idx
  on public.restaurants (household_id, cost_per_head);

alter table public.restaurants enable row level security;

-- One policy for all four verbs, because there is one rule: your household's
-- places are yours to read and change, and nobody else's exist as far as you are
-- concerned.
drop policy if exists "household members manage restaurants" on public.restaurants;
create policy "household members manage restaurants"
  on public.restaurants
  for all
  to authenticated
  using (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurants.household_id
        and hm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurants.household_id
        and hm.user_id = auth.uid()
    )
  );

grant select, insert, update, delete on public.restaurants to authenticated;

-- `updated_at` on write, matching the trigger the other tables use.
drop trigger if exists restaurants_set_updated_at on public.restaurants;
create trigger restaurants_set_updated_at
  before update on public.restaurants
  for each row
  execute function public.set_updated_at();
