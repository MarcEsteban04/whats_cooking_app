-- ---------------------------------------------------------------------------
-- 0005 · Meal history, pantry, grocery
-- See docs/DATABASE.md §4.10-4.12
-- ---------------------------------------------------------------------------

create table if not exists meal_history (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  meal_id       uuid not null references meals(id) on delete restrict,
  decided_by    uuid not null references profiles(id) on delete cascade,
  eaten_at      timestamptz not null default now(),
  meal_type     meal_type not null,
  actual_cost   numeric(10,2) check (actual_cost is null or actual_cost >= 0),
  source        text not null default 'roulette' check (
    source in ('roulette','manual','planner','ai')
  ),
  -- Cooked vs ordered. Feeds the statistics screen.
  was_cooked    boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists pantry_items (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references households(id) on delete cascade,
  ingredient_id    uuid not null references ingredients(id) on delete cascade,
  -- Null means "we have some" without a tracked amount.
  quantity         numeric(10,2) check (quantity is null or quantity >= 0),
  unit             text,
  expiration_date  date,
  added_by         uuid references profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- Adding an ingredient already present updates quantity rather than
  -- creating a duplicate row.
  unique (household_id, ingredient_id)
);

create table if not exists grocery_lists (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  name          text not null default 'Grocery List',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- One active list per household.
create unique index if not exists grocery_lists_one_active_idx
  on grocery_lists (household_id) where is_active;

create table if not exists grocery_items (
  id                  uuid primary key default gen_random_uuid(),
  grocery_list_id     uuid not null references grocery_lists(id) on delete cascade,
  ingredient_id       uuid references ingredients(id) on delete set null,
  -- Free text matters: someone in a supermarket must be able to add
  -- "the good soy sauce" without our vocabulary approving it first.
  custom_name         text,
  quantity            numeric(10,2) check (quantity is null or quantity > 0),
  unit                text,
  is_completed        boolean not null default false,
  completed_by        uuid references profiles(id) on delete set null,
  completed_at        timestamptz,
  -- Provenance: lets the UI show why an item is on the list, and lets removing
  -- a planned meal clean up after itself.
  added_from_meal_id  uuid references meals(id) on delete set null,
  created_at          timestamptz not null default now(),

  constraint grocery_items_name_ck check (
    (ingredient_id is not null and custom_name is null)
    or (ingredient_id is null and custom_name is not null)
  )
);
