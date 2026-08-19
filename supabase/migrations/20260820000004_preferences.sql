-- ---------------------------------------------------------------------------
-- 0004 · User preferences, favourites, dislikes
-- See docs/DATABASE.md §4.8-4.9
-- ---------------------------------------------------------------------------

create table if not exists user_preferences (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null unique references profiles(id) on delete cascade,
  favorite_cuisines     text[] not null default '{}',
  disliked_ingredients  uuid[] not null default '{}',
  -- Applied as a hard filter by the recommendation engine, never a penalty.
  dietary_tags          dietary_tag[] not null default '{}',
  default_budget        numeric(10,2) check (default_budget is null or default_budget >= 0),
  max_cooking_time      smallint check (max_cooking_time is null or max_cooking_time > 0),
  preferred_servings    smallint not null default 2 check (preferred_servings > 0),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Favourites are visible to household members.
create table if not exists favorite_meals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  meal_id     uuid not null references meals(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (user_id, meal_id)
);

-- Dislikes are strictly private. A partner seeing what you dislike is a social
-- cost with no product benefit; the engine reads both server-side regardless
-- (docs/ARCHITECTURE.md §8.3).
create table if not exists disliked_meals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  meal_id     uuid not null references meals(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (user_id, meal_id)
);
