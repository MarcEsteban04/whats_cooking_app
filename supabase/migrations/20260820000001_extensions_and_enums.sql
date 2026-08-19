-- ---------------------------------------------------------------------------
-- 0001 · Extensions and enumerated types
-- See docs/DATABASE.md §3
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "pg_trgm";       -- trigram search on meal names

-- Enums are created defensively so the file can be re-run during setup.
do $$ begin
  create type meal_category as enum ('breakfast','lunch','dinner','snack','dessert');
exception when duplicate_object then null; end $$;

do $$ begin
  create type meal_type as enum ('breakfast','lunch','dinner','snack');
exception when duplicate_object then null; end $$;

do $$ begin
  create type difficulty as enum ('easy','medium','hard');
exception when duplicate_object then null; end $$;

do $$ begin
  create type household_role as enum ('owner','member');
exception when duplicate_object then null; end $$;

do $$ begin
  create type invite_status as enum ('pending','accepted','expired','revoked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type vote_choice as enum ('like','pass');
exception when duplicate_object then null; end $$;

do $$ begin
  create type dietary_tag as enum (
    'vegetarian','vegan','pescatarian','halal','kosher',
    'gluten_free','dairy_free','nut_free','low_carb','keto'
  );
exception when duplicate_object then null; end $$;

-- Cuisine is check-constrained text rather than an enum: the catalogue will
-- gain cuisines over time, and altering an enum in production is far more
-- disruptive than editing a constraint (docs/DATABASE.md §3).
