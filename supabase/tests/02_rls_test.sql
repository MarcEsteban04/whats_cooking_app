-- ===========================================================================
-- Row Level Security tests — Sprint 15
--
-- HOW TO USE
--   Supabase dashboard → SQL Editor → New query → paste → Run.
--   "Success. No rows returned" means every check passed. Any failure raises
--   immediately and names the check that broke.
--
-- Runs inside a transaction and rolls back, leaving nothing behind.
--
-- WHY THIS EXISTS
--   A policy that grants correctly but fails to deny is indistinguishable from
--   a working policy until it is a breach. verify.sql proves policies exist;
--   this proves they refuse.
--
--   The SQL editor normally runs as a role that bypasses RLS, so every
--   assertion below runs after `set local role authenticated` with a forged
--   JWT claim, which is what makes auth.uid() resolve to a specific user.
-- ===========================================================================

begin;

-- Fixed IDs so they can be referenced across role switches.
-- Deliberately unmistakable, so a stray row is obvious if cleanup ever fails.
--   A = 1111...  B = 2222...
--   A and B start in separate households.

-- --- Setup, as the privileged role ----------------------------------------
do $$
declare
  user_a uuid := '11111111-1111-1111-1111-111111111111';
  user_b uuid := '22222222-2222-2222-2222-222222222222';
  hh_a   uuid;
  hh_b   uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', user_a, 'authenticated',
     'authenticated', 'rls-a@example.com', crypt('pw', gen_salt('bf')),
     now(), now(), now(), '{"provider":"email"}'::jsonb,
     '{"display_name":"Ana"}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', user_b, 'authenticated',
     'authenticated', 'rls-b@example.com', crypt('pw', gen_salt('bf')),
     now(), now(), now(), '{"provider":"email"}'::jsonb,
     '{"display_name":"Ben"}'::jsonb);

  select active_household_id into hh_a from profiles where id = user_a;
  select active_household_id into hh_b from profiles where id = user_b;

  -- A public catalogue meal, and one private to each household.
  insert into meals (id, name, cuisine, category, cooking_time_minutes,
                     estimated_cost, is_public)
  values ('aaaaaaaa-0000-0000-0000-000000000001',
          'Public Adobo', 'filipino', 'dinner', 35, 180, true);

  insert into meals (id, name, cuisine, category, cooking_time_minutes,
                     estimated_cost, is_public, created_by, household_id)
  values ('aaaaaaaa-0000-0000-0000-000000000002',
          'Ana Secret Recipe', 'filipino', 'dinner', 20, 120, false,
          user_a, hh_a),
         ('bbbbbbbb-0000-0000-0000-000000000003',
          'Ben Secret Recipe', 'japanese', 'dinner', 25, 200, false,
          user_b, hh_b);

  -- B's private data, which A must never see.
  insert into disliked_meals (user_id, meal_id)
  values (user_b, 'aaaaaaaa-0000-0000-0000-000000000001');

  insert into favorite_meals (user_id, meal_id)
  values (user_b, 'aaaaaaaa-0000-0000-0000-000000000001');

  insert into meal_history (household_id, meal_id, decided_by, meal_type)
  values (hh_b, 'aaaaaaaa-0000-0000-0000-000000000001', user_b, 'dinner');

  insert into pantry_items (household_id, ingredient_id)
  select hh_b, id from ingredients limit 1;
end $$;

-- Ensure there is at least one ingredient for the pantry row above.
insert into ingredients (name, category, default_unit)
values ('rls-test-onion', 'vegetable', 'pc')
on conflict (name) do nothing;

-- =========================================================================
-- Act as user A
-- =========================================================================
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  user_b uuid := '22222222-2222-2222-2222-222222222222';
  n int;
begin
  -- --- Grants ---
  if auth.uid() <> '11111111-1111-1111-1111-111111111111' then
    raise exception 'FAIL 0: impersonation did not take effect; auth.uid() = %',
      auth.uid();
  end if;

  select count(*) into n from profiles
   where id = '11111111-1111-1111-1111-111111111111';
  if n <> 1 then raise exception 'FAIL 1a: A cannot read their own profile'; end if;

  select count(*) into n from user_preferences;
  if n <> 1 then
    raise exception 'FAIL 1b: A sees % preference rows, expected only their own', n;
  end if;

  select count(*) into n from meals
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if n <> 1 then raise exception 'FAIL 1c: A cannot read a public meal'; end if;

  select count(*) into n from meals
   where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  if n <> 1 then raise exception 'FAIL 1d: A cannot read their own private meal'; end if;

  -- --- Denials: the half that matters ---
  select count(*) into n from profiles where id = user_b;
  if n <> 0 then
    raise exception 'FAIL 2a: A can read the profile of a user in another household';
  end if;

  select count(*) into n from user_preferences where user_id = user_b;
  if n <> 0 then raise exception 'FAIL 2b: A can read another user preferences'; end if;

  select count(*) into n from disliked_meals where user_id = user_b;
  if n <> 0 then
    raise exception 'FAIL 2c: A can read another user dislikes; these are private';
  end if;

  select count(*) into n from favorite_meals where user_id = user_b;
  if n <> 0 then
    raise exception 'FAIL 2d: A can read favourites of a user outside their household';
  end if;

  select count(*) into n from meals
   where id = 'bbbbbbbb-0000-0000-0000-000000000003';
  if n <> 0 then raise exception 'FAIL 2e: A can read another household private meal'; end if;

  select count(*) into n from meal_history;
  if n <> 0 then raise exception 'FAIL 2f: A can read another household meal history'; end if;

  select count(*) into n from pantry_items;
  if n <> 0 then raise exception 'FAIL 2g: A can read another household pantry'; end if;

  select count(*) into n from households;
  if n <> 1 then
    raise exception 'FAIL 2h: A sees % households, expected only their own', n;
  end if;

  select count(*) into n from household_members;
  if n <> 1 then
    raise exception 'FAIL 2i: A sees % memberships, expected only their own', n;
  end if;

  -- --- Writes into someone else's household ---
  begin
    insert into meal_history (household_id, meal_id, decided_by, meal_type)
    select active_household_id, 'aaaaaaaa-0000-0000-0000-000000000001',
           '11111111-1111-1111-1111-111111111111', 'dinner'
      from profiles where id = user_b;
    -- The select returns no rows (A cannot see B's profile), so nothing is
    -- inserted. Verify that rather than assuming.
    if (select count(*) from meal_history) <> 0 then
      raise exception 'FAIL 3a: A wrote history into another household';
    end if;
  exception when insufficient_privilege then null;
  end;

  begin
    update profiles set display_name = 'hacked' where id = user_b;
    if exists (select 1 from profiles where display_name = 'hacked') then
      raise exception 'FAIL 3b: A modified another user profile';
    end if;
  exception when insufficient_privilege then null;
  end;

  -- A meal must be attributed to its creator.
  begin
    insert into meals (name, cuisine, category, cooking_time_minutes,
                       estimated_cost, is_public, created_by, household_id)
    select 'Forged', 'filipino', 'dinner', 10, 10, false, user_b,
           active_household_id
      from profiles where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'FAIL 3c: A created a meal attributed to another user';
  exception when insufficient_privilege then null;
       when others then
         if sqlstate <> '42501' then raise; end if;
  end;

  -- Nobody may insert into the public catalogue from the client.
  begin
    insert into meals (name, cuisine, category, cooking_time_minutes,
                       estimated_cost, is_public, created_by)
    values ('Sneaky Public', 'filipino', 'dinner', 10, 10, true,
            '11111111-1111-1111-1111-111111111111');
    raise exception 'FAIL 3d: a client inserted into the public catalogue';
  exception when insufficient_privilege then null;
       when others then
         if sqlstate <> '42501' then raise; end if;
  end;
end $$;

-- =========================================================================
-- Put A and B in the same household, then re-check what changes
-- =========================================================================
reset role;
reset request.jwt.claims;

do $$
declare
  hh_a uuid;
begin
  select active_household_id into hh_a
    from profiles where id = '11111111-1111-1111-1111-111111111111';

  insert into household_members (household_id, user_id, role)
  values (hh_a, '22222222-2222-2222-2222-222222222222', 'member');

  update households set is_personal = false where id = hh_a;

  -- B's favourite and dislike now belong to a household member.
end $$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  user_b uuid := '22222222-2222-2222-2222-222222222222';
  n int;
begin
  select count(*) into n from profiles where id = user_b;
  if n <> 1 then
    raise exception 'FAIL 4a: A cannot read the profile of their own household member';
  end if;

  select count(*) into n from favorite_meals where user_id = user_b;
  if n <> 1 then
    raise exception 'FAIL 4b: A cannot read a household member favourites; couple scoring needs these';
  end if;

  -- The asymmetry that matters: favourites are shared, dislikes are not.
  select count(*) into n from disliked_meals where user_id = user_b;
  if n <> 0 then
    raise exception 'FAIL 4c: dislikes leaked to a household member; they are private by design';
  end if;

  -- Preferences stay private even inside a household.
  select count(*) into n from user_preferences where user_id = user_b;
  if n <> 0 then
    raise exception 'FAIL 4d: preferences leaked to a household member';
  end if;
end $$;

-- =========================================================================
-- Act as an anonymous caller
-- =========================================================================
reset role;
reset request.jwt.claims;

set local role anon;

do $$
declare n int;
begin
  -- Guest mode reads the public catalogue before signup (PRD US-A-01).
  select count(*) into n from meals where is_public;
  if n < 1 then
    raise exception 'FAIL 5a: anonymous cannot read the public catalogue; guest mode would break';
  end if;

  select count(*) into n from meals where not is_public;
  if n <> 0 then
    raise exception 'FAIL 5b: anonymous can read private meals';
  end if;

  -- Everything else must be refused, by grant or by policy.
  begin
    select count(*) into n from profiles;
    if n <> 0 then raise exception 'FAIL 5c: anonymous can read profiles'; end if;
  exception when insufficient_privilege then null;
  end;

  begin
    select count(*) into n from meal_history;
    if n <> 0 then raise exception 'FAIL 5d: anonymous can read meal history'; end if;
  exception when insufficient_privilege then null;
  end;

  begin
    select count(*) into n from user_preferences;
    if n <> 0 then raise exception 'FAIL 5e: anonymous can read preferences'; end if;
  exception when insufficient_privilege then null;
  end;

  begin
    insert into meals (name, cuisine, category, cooking_time_minutes,
                       estimated_cost, is_public)
    values ('Anon Meal', 'filipino', 'dinner', 10, 10, true);
    raise exception 'FAIL 5f: anonymous inserted a meal';
  exception when insufficient_privilege then null;
       when others then
         if sqlstate <> '42501' then raise; end if;
  end;
end $$;

reset role;

do $$ begin raise notice 'ALL RLS TESTS PASSED'; end $$;

rollback;
