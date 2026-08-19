-- ---------------------------------------------------------------------------
-- 0002 · Profiles, households, membership, invites
-- See docs/DATABASE.md §4.1-4.4
--
-- profiles and households reference each other, so the circular foreign key is
-- added after both tables exist.
-- ---------------------------------------------------------------------------

create table if not exists profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  display_name          text not null,
  avatar_url            text,
  active_household_id   uuid,
  onboarding_completed  boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

comment on column profiles.active_household_id is
  'Current household context for every scoped write. Every user has at least a personal household, so this is never null after provisioning.';

create table if not exists households (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  created_by        uuid not null references profiles(id) on delete cascade,
  -- True for the household auto-created at signup. Flipped to false when a
  -- partner is invited in.
  is_personal       boolean not null default true,
  default_budget    numeric(10,2),
  default_servings  smallint not null default 2 check (default_servings > 0),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

do $$ begin
  alter table profiles
    add constraint profiles_active_household_fk
    foreign key (active_household_id) references households(id) on delete set null;
exception when duplicate_object then null; end $$;

create table if not exists household_members (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  user_id       uuid not null references profiles(id) on delete cascade,
  role          household_role not null default 'member',
  joined_at     timestamptz not null default now(),
  unique (household_id, user_id)
);

create table if not exists household_invites (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  -- 8 characters, ambiguous glyphs excluded: these get read aloud and typed.
  code          text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  created_by    uuid not null references profiles(id) on delete cascade,
  status        invite_status not null default 'pending',
  expires_at    timestamptz not null default (now() + interval '7 days'),
  accepted_by   uuid references profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);
