-- Sprint 46 — what we decided on the nights nobody cooked.
--
-- The other roulette needs the other history: a repetition window is only a
-- promise if something remembers, and "not that place again" is the same
-- complaint as "not chicken again".

-- ---------------------------------------------------------------------------
-- Where we ate out.
-- ---------------------------------------------------------------------------
--
-- **A separate table, not a nullable `restaurant_id` on `meal_history`.** The two
-- share a shape and not a meaning: one records cooking and the other records going
-- out, every query wants one or the other, and a single table would need a check
-- constraint asserting exactly one of two foreign keys is set — which is the shape
-- of a table doing two jobs. docs/DATABASE.md §4.16 records the same reasoning.
--
-- **No uniqueness.** A household can eat at the same place twice in a day, so a
-- duplicate here is indistinguishable from the truth — which is also why the write
-- never retries.
create table if not exists public.restaurant_history (
  id              uuid primary key default gen_random_uuid(),
  household_id    uuid not null references public.households (id) on delete cascade,

  -- `restrict`, not `cascade`. Deleting a place should not quietly erase the
  -- evenings we spent there, and the app has no flow that deletes one with history
  -- behind it — so this turns a silent data loss into a refused delete somebody can
  -- see.
  restaurant_id   uuid not null references public.restaurants (id) on delete restrict,

  decided_by      uuid not null references public.profiles (id) on delete cascade,
  eaten_at        timestamptz not null default now(),

  -- Copied at decision time, because the restaurant's own price will drift and a
  -- history that silently re-prices last month is a history nobody can budget from.
  estimated_cost  numeric(10,2) check (estimated_cost is null or estimated_cost >= 0),
  actual_cost     numeric(10,2) check (actual_cost is null or actual_cost >= 0),

  created_at      timestamptz not null default now()
);

comment on table public.restaurant_history is
  'Nights the household ate out. Separate from meal_history: same shape, different meaning. Sprint 46.';

-- The query the repetition window makes: this household's recent visits, newest
-- first.
create index if not exists restaurant_history_household_idx
  on public.restaurant_history (household_id, eaten_at desc);

-- And the per-place lookback the scorer uses.
create index if not exists restaurant_history_restaurant_idx
  on public.restaurant_history (restaurant_id, eaten_at desc);

alter table public.restaurant_history enable row level security;

drop policy if exists "household members read restaurant history"
  on public.restaurant_history;
create policy "household members read restaurant history"
  on public.restaurant_history
  for select
  to authenticated
  using (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurant_history.household_id
        and hm.user_id = auth.uid()
    )
  );

-- Writing requires being the one who decided, the same rule `meal_history` uses:
-- the row records who made the call, so it cannot be attributed to somebody else
-- even by sending the column explicitly.
drop policy if exists "household members write restaurant history"
  on public.restaurant_history;
create policy "household members write restaurant history"
  on public.restaurant_history
  for insert
  to authenticated
  with check (
    decided_by = auth.uid()
    and exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurant_history.household_id
        and hm.user_id = auth.uid()
    )
  );

-- Deletable, so a mis-tap can be undone — and that recomputes the repetition
-- window, which is the whole point of being able to.
drop policy if exists "household members delete restaurant history"
  on public.restaurant_history;
create policy "household members delete restaurant history"
  on public.restaurant_history
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurant_history.household_id
        and hm.user_id = auth.uid()
    )
  );

-- No update policy. An evening already had is not a thing to edit — except for
-- what it cost, which is the one fact learned afterwards.
drop policy if exists "household members correct restaurant cost"
  on public.restaurant_history;
create policy "household members correct restaurant cost"
  on public.restaurant_history
  for update
  to authenticated
  using (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurant_history.household_id
        and hm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.household_members hm
      where hm.household_id = restaurant_history.household_id
        and hm.user_id = auth.uid()
    )
  );

grant select, insert, update, delete on public.restaurant_history to authenticated;
