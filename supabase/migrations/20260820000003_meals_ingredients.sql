-- ---------------------------------------------------------------------------
-- 0003 · Meals, ingredients and their relationship
-- See docs/DATABASE.md §4.5-4.7
-- ---------------------------------------------------------------------------

create table if not exists meals (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null check (length(trim(name)) > 0),
  description           text,
  image_url             text,
  cuisine               text not null check (
    cuisine in (
      'filipino','japanese','korean','chinese','thai','vietnamese',
      'italian','mexican','american','indian','mediterranean','other'
    )
  ),
  category              meal_category not null,
  difficulty            difficulty not null default 'easy',
  cooking_time_minutes  smallint not null check (cooking_time_minutes > 0),
  estimated_cost        numeric(10,2) not null check (estimated_cost >= 0),
  servings              smallint not null default 2 check (servings > 0),
  calories              integer check (calories is null or calories >= 0),
  -- Ordered array of step strings. Always read as a whole unit and never
  -- queried individually, so a child table would add a join for nothing.
  instructions          jsonb not null default '[]'::jsonb,
  dietary_tags          dietary_tag[] not null default '{}',
  tags                  text[] not null default '{}',
  is_public             boolean not null default false,
  created_by            uuid references profiles(id) on delete set null,
  household_id          uuid references households(id) on delete cascade,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  -- A meal is either in the public catalogue or private to one household.
  -- Never both, never neither.
  constraint meals_visibility_ck check (
    (is_public and household_id is null)
    or (not is_public and household_id is not null)
  )
);

create table if not exists ingredients (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique check (name = lower(trim(name))),
  category      text not null check (
    category in ('protein','vegetable','fruit','grain','dairy','spice','condiment','other')
  ),
  default_unit  text not null,
  -- Staples are assumed present and never reduce a pantry match percentage.
  -- Without this every meal caps near 80% and the number stops meaning
  -- anything (docs/USER_FLOWS.md §12).
  is_staple     boolean not null default false,
  created_at    timestamptz not null default now()
);

create table if not exists meal_ingredients (
  id             uuid primary key default gen_random_uuid(),
  meal_id        uuid not null references meals(id) on delete cascade,
  -- restrict, not cascade: silently emptying recipes is not an acceptable
  -- failure mode.
  ingredient_id  uuid not null references ingredients(id) on delete restrict,
  quantity       numeric(10,2) not null check (quantity > 0),
  unit           text not null,
  is_optional    boolean not null default false,
  unique (meal_id, ingredient_id)
);
