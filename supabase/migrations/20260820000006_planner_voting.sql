-- ---------------------------------------------------------------------------
-- 0006 · Meal plans (v1.3) and Can't Agree voting (v1.1)
-- See docs/DATABASE.md §4.13-4.14
--
-- Created now so the schema is complete and RLS is uniform. The features
-- themselves ship later.
-- ---------------------------------------------------------------------------

create table if not exists meal_plans (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  meal_id       uuid not null references meals(id) on delete cascade,
  planned_date  date not null,
  meal_type     meal_type not null,
  created_by    uuid not null references profiles(id) on delete cascade,
  created_at    timestamptz not null default now(),
  -- One meal per slot.
  unique (household_id, planned_date, meal_type)
);

create table if not exists vote_sessions (
  id                  uuid primary key default gen_random_uuid(),
  household_id        uuid not null references households(id) on delete cascade,
  -- Frozen on the session so both partners genuinely vote on the same meals.
  -- Regenerating per user would make a "match" meaningless.
  candidate_meal_ids  uuid[] not null check (array_length(candidate_meal_ids, 1) > 0),
  started_by          uuid not null references profiles(id) on delete cascade,
  resolved_meal_id    uuid references meals(id) on delete set null,
  created_at          timestamptz not null default now(),
  resolved_at         timestamptz
);

create table if not exists meal_votes (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references vote_sessions(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  meal_id     uuid not null references meals(id) on delete cascade,
  choice      vote_choice not null,
  created_at  timestamptz not null default now(),
  unique (session_id, user_id, meal_id)
);
