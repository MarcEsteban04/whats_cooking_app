-- ---------------------------------------------------------------------------
-- 0009 · Row Level Security
-- See docs/DATABASE.md §6 and docs/ARCHITECTURE.md §8
--
-- RLS is the security boundary, not client code. Deny by default: RLS is
-- enabled on every table, and no policy means no access.
--
-- Household-scoped tables all use public.is_household_member(), which is
-- SECURITY DEFINER and therefore does not recurse through these policies.
-- ---------------------------------------------------------------------------

alter table profiles           enable row level security;
alter table households         enable row level security;
alter table household_members  enable row level security;
alter table household_invites  enable row level security;
alter table meals              enable row level security;
alter table ingredients        enable row level security;
alter table meal_ingredients   enable row level security;
alter table user_preferences   enable row level security;
alter table favorite_meals     enable row level security;
alter table disliked_meals     enable row level security;
alter table meal_history       enable row level security;
alter table pantry_items       enable row level security;
alter table grocery_lists      enable row level security;
alter table grocery_items      enable row level security;
alter table meal_plans         enable row level security;
alter table vote_sessions      enable row level security;
alter table meal_votes         enable row level security;

-- --- profiles ---------------------------------------------------------------
drop policy if exists "read own profile" on profiles;
create policy "read own profile" on profiles
  for select using (id = auth.uid());

drop policy if exists "read household members profiles" on profiles;
create policy "read household members profiles" on profiles
  for select using (
    exists (
      select 1 from household_members hm
      where hm.user_id = profiles.id
        and public.is_household_member(hm.household_id)
    )
  );

drop policy if exists "update own profile" on profiles;
create policy "update own profile" on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- --- households -------------------------------------------------------------
drop policy if exists "members read household" on households;
create policy "members read household" on households
  for select using (public.is_household_member(id));

drop policy if exists "authenticated create household" on households;
create policy "authenticated create household" on households
  for insert with check (created_by = auth.uid());

drop policy if exists "owner updates household" on households;
create policy "owner updates household" on households
  for update using (
    exists (
      select 1 from household_members hm
      where hm.household_id = households.id
        and hm.user_id = auth.uid()
        and hm.role = 'owner'
    )
  );

-- --- household_members ------------------------------------------------------
drop policy if exists "members read membership" on household_members;
create policy "members read membership" on household_members
  for select using (public.is_household_member(household_id));

drop policy if exists "join household" on household_members;
create policy "join household" on household_members
  for insert with check (user_id = auth.uid());

-- Members may remove themselves; owners may remove anyone.
drop policy if exists "leave or remove member" on household_members;
create policy "leave or remove member" on household_members
  for delete using (
    user_id = auth.uid()
    or exists (
      select 1 from household_members owner
      where owner.household_id = household_members.household_id
        and owner.user_id = auth.uid()
        and owner.role = 'owner'
    )
  );

-- --- household_invites ------------------------------------------------------
drop policy if exists "members read invites" on household_invites;
create policy "members read invites" on household_invites
  for select using (public.is_household_member(household_id));

drop policy if exists "members create invites" on household_invites;
create policy "members create invites" on household_invites
  for insert with check (
    created_by = auth.uid() and public.is_household_member(household_id)
  );

drop policy if exists "members revoke invites" on household_invites;
create policy "members revoke invites" on household_invites
  for update using (public.is_household_member(household_id));

-- --- meals ------------------------------------------------------------------
drop policy if exists "read visible meals" on meals;
create policy "read visible meals" on meals
  for select using (
    is_public or public.is_household_member(household_id)
  );

drop policy if exists "create own meals" on meals;
create policy "create own meals" on meals
  for insert with check (
    created_by = auth.uid()
    and not is_public
    and public.is_household_member(household_id)
  );

drop policy if exists "update own meals" on meals;
create policy "update own meals" on meals
  for update using (created_by = auth.uid()) with check (created_by = auth.uid());

drop policy if exists "delete own meals" on meals;
create policy "delete own meals" on meals
  for delete using (created_by = auth.uid());

-- --- ingredients ------------------------------------------------------------
-- Shared vocabulary: readable by everyone signed in, append-only. Users must
-- never be blocked because our ingredient list is incomplete.
drop policy if exists "authenticated read ingredients" on ingredients;
create policy "authenticated read ingredients" on ingredients
  for select to authenticated using (true);

drop policy if exists "authenticated add ingredients" on ingredients;
create policy "authenticated add ingredients" on ingredients
  for insert to authenticated with check (true);

-- --- meal_ingredients -------------------------------------------------------
drop policy if exists "read ingredients of visible meals" on meal_ingredients;
create policy "read ingredients of visible meals" on meal_ingredients
  for select using (
    exists (
      select 1 from meals m
      where m.id = meal_ingredients.meal_id
        and (m.is_public or public.is_household_member(m.household_id))
    )
  );

drop policy if exists "manage ingredients of own meals" on meal_ingredients;
create policy "manage ingredients of own meals" on meal_ingredients
  for all using (
    exists (
      select 1 from meals m
      where m.id = meal_ingredients.meal_id and m.created_by = auth.uid()
    )
  );

-- --- user_preferences -------------------------------------------------------
-- Strictly private, with no household exception.
drop policy if exists "own preferences only" on user_preferences;
create policy "own preferences only" on user_preferences
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- favorite_meals ---------------------------------------------------------
-- Shared with household members, because couple scoring depends on it.
drop policy if exists "read household favourites" on favorite_meals;
create policy "read household favourites" on favorite_meals
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from household_members hm
      where hm.user_id = favorite_meals.user_id
        and public.is_household_member(hm.household_id)
    )
  );

drop policy if exists "manage own favourites" on favorite_meals;
create policy "manage own favourites" on favorite_meals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- disliked_meals ---------------------------------------------------------
-- Strictly private. A partner seeing what you dislike is a social cost with no
-- product benefit; the engine reads both server-side regardless.
drop policy if exists "own dislikes only" on disliked_meals;
create policy "own dislikes only" on disliked_meals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- household-scoped tables ------------------------------------------------
-- Identical shape everywhere, which is exactly what the personal-household
-- decision bought: no branch for "household or not".
drop policy if exists "household members read history" on meal_history;
create policy "household members read history" on meal_history
  for select using (public.is_household_member(household_id));

drop policy if exists "household members write history" on meal_history;
create policy "household members write history" on meal_history
  for insert with check (
    public.is_household_member(household_id) and decided_by = auth.uid()
  );

drop policy if exists "household members manage history" on meal_history;
create policy "household members manage history" on meal_history
  for delete using (public.is_household_member(household_id));

drop policy if exists "household members manage pantry" on pantry_items;
create policy "household members manage pantry" on pantry_items
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "household members manage grocery lists" on grocery_lists;
create policy "household members manage grocery lists" on grocery_lists
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "household members manage grocery items" on grocery_items;
create policy "household members manage grocery items" on grocery_items
  for all using (
    exists (
      select 1 from grocery_lists gl
      where gl.id = grocery_items.grocery_list_id
        and public.is_household_member(gl.household_id)
    )
  )
  with check (
    exists (
      select 1 from grocery_lists gl
      where gl.id = grocery_items.grocery_list_id
        and public.is_household_member(gl.household_id)
    )
  );

drop policy if exists "household members manage plans" on meal_plans;
create policy "household members manage plans" on meal_plans
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "household members manage vote sessions" on vote_sessions;
create policy "household members manage vote sessions" on vote_sessions
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "household members read votes" on meal_votes;
create policy "household members read votes" on meal_votes
  for select using (
    exists (
      select 1 from vote_sessions vs
      where vs.id = meal_votes.session_id
        and public.is_household_member(vs.household_id)
    )
  );

drop policy if exists "cast own votes" on meal_votes;
create policy "cast own votes" on meal_votes
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from vote_sessions vs
      where vs.id = meal_votes.session_id
        and public.is_household_member(vs.household_id)
    )
  );
