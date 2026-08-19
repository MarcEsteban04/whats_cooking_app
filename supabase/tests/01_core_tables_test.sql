-- ===========================================================================
-- Core table integrity tests — Sprint 12
--
-- HOW TO USE
--   Supabase dashboard → SQL Editor → New query → paste → Run.
--   Finishes with "ALL CORE TABLE TESTS PASSED" or raises on the first
--   failure, naming the check that broke.
--
-- Everything runs inside a transaction that is rolled back at the end, so it
-- leaves no data behind. Safe to run against a database with real data,
-- though running it against production is still a bad habit.
--
-- Covers what Sprint 12 added: primary keys, foreign keys, constraints,
-- timestamps and the signup provisioning trigger. RLS is tested separately in
-- Sprint 15.
-- ===========================================================================

begin;

do $$
declare
  user_a          uuid := gen_random_uuid();
  user_b          uuid := gen_random_uuid();
  household_a     uuid;
  meal_id         uuid;
  ingredient_id   uuid;
  row_count       int;
  after_updated   timestamptz;
begin

  -- =========================================================================
  -- 1. Signup provisioning
  --
  -- The single most important trigger in the schema: it is what lets every
  -- household-scoped table carry a NOT NULL household_id.
  -- =========================================================================
  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', user_a, 'authenticated',
    'authenticated', 'marc-test@example.com',
    crypt('password123', gen_salt('bf')), now(),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Marc"}'::jsonb
  );

  select count(*) into row_count from profiles where id = user_a;
  if row_count <> 1 then
    raise exception 'FAIL 1a: signup did not create a profile';
  end if;

  select count(*) into row_count from user_preferences where user_id = user_a;
  if row_count <> 1 then
    raise exception 'FAIL 1b: signup did not create preferences';
  end if;

  select active_household_id into household_a from profiles where id = user_a;
  if household_a is null then
    raise exception 'FAIL 1c: signup did not set active_household_id';
  end if;

  select count(*) into row_count
    from households where id = household_a and is_personal;
  if row_count <> 1 then
    raise exception 'FAIL 1d: personal household was not created';
  end if;

  select count(*) into row_count
    from household_members
   where household_id = household_a and user_id = user_a and role = 'owner';
  if row_count <> 1 then
    raise exception 'FAIL 1e: signup did not create owner membership';
  end if;

  if (select display_name from profiles where id = user_a) <> 'Marc' then
    raise exception 'FAIL 1f: display_name from metadata was not used';
  end if;

  -- A user with no display_name metadata should still provision, falling back
  -- to the email local part rather than failing.
  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', user_b, 'authenticated',
    'authenticated', 'princess@example.com',
    crypt('password123', gen_salt('bf')), now(),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb
  );

  if (select display_name from profiles where id = user_b) <> 'princess' then
    raise exception 'FAIL 1g: display_name fallback did not use the email local part';
  end if;

  -- =========================================================================
  -- 2. Meal visibility constraint
  --
  -- A meal is public OR private to a household. Never both, never neither.
  -- =========================================================================
  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost,
      is_public, household_id
    ) values ('Impossible', 'filipino', 'dinner', 30, 100, true, household_a);
    raise exception 'FAIL 2a: a meal was allowed to be public AND household-owned';
  exception when check_violation then null;
  end;

  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost,
      is_public, household_id
    ) values ('Orphan', 'filipino', 'dinner', 30, 100, false, null);
    raise exception 'FAIL 2b: a meal was allowed to be neither public nor owned';
  exception when check_violation then null;
  end;

  insert into meals (
    name, cuisine, category, cooking_time_minutes, estimated_cost, is_public
  ) values ('Chicken Adobo', 'filipino', 'dinner', 35, 180, true)
  returning id into meal_id;

  -- =========================================================================
  -- 3. Value constraints
  -- =========================================================================
  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost, is_public
    ) values ('Free Lunch', 'filipino', 'dinner', 30, -1, true);
    raise exception 'FAIL 3a: negative cost was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost, is_public
    ) values ('Instant', 'filipino', 'dinner', 0, 100, true);
    raise exception 'FAIL 3b: zero cooking time was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost, is_public
    ) values ('   ', 'filipino', 'dinner', 30, 100, true);
    raise exception 'FAIL 3c: a blank meal name was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into meals (
      name, cuisine, category, cooking_time_minutes, estimated_cost, is_public
    ) values ('Martian Stew', 'martian', 'dinner', 30, 100, true);
    raise exception 'FAIL 3d: an unknown cuisine was accepted';
  exception when check_violation then null;
  end;

  -- Ingredient names are normalised lowercase, so pantry matching cannot miss
  -- because of capitalisation.
  begin
    insert into ingredients (name, category, default_unit)
    values ('Chicken', 'protein', 'g');
    raise exception 'FAIL 3e: a non-lowercase ingredient name was accepted';
  exception when check_violation then null;
  end;

  insert into ingredients (name, category, default_unit, is_staple)
  values ('chicken', 'protein', 'g', false)
  returning id into ingredient_id;

  -- =========================================================================
  -- 4. Uniqueness
  -- =========================================================================
  begin
    insert into ingredients (name, category, default_unit)
    values ('chicken', 'protein', 'g');
    raise exception 'FAIL 4a: duplicate ingredient name was accepted';
  exception when unique_violation then null;
  end;

  insert into meal_ingredients (meal_id, ingredient_id, quantity, unit)
  values (meal_id, ingredient_id, 500, 'g');

  begin
    insert into meal_ingredients (meal_id, ingredient_id, quantity, unit)
    values (meal_id, ingredient_id, 200, 'g');
    raise exception 'FAIL 4b: the same ingredient was added to a meal twice';
  exception when unique_violation then null;
  end;

  begin
    insert into household_members (household_id, user_id)
    values (household_a, user_a);
    raise exception 'FAIL 4c: duplicate household membership was accepted';
  exception when unique_violation then null;
  end;

  -- =========================================================================
  -- 5. Referential integrity
  -- =========================================================================
  begin
    delete from ingredients where id = ingredient_id;
    raise exception 'FAIL 5a: an ingredient still used by a recipe was deleted';
  exception when foreign_key_violation then null;
  end;

  begin
    insert into meal_history (household_id, meal_id, decided_by, meal_type)
    values (gen_random_uuid(), meal_id, user_a, 'dinner');
    raise exception 'FAIL 5b: history was written against a nonexistent household';
  exception when foreign_key_violation then null;
  end;

  -- =========================================================================
  -- 6. Invite codes
  --
  -- Ambiguous glyphs are excluded because these get read aloud and typed.
  -- =========================================================================
  begin
    insert into household_invites (household_id, code, created_by)
    values (household_a, 'O0I1ABCD', user_a);
    raise exception 'FAIL 6a: an invite code with ambiguous glyphs was accepted';
  exception when check_violation then null;
  end;

  insert into household_invites (household_id, code, created_by)
  values (household_a, public.generate_invite_code(), user_a);

  if (select count(*) from household_invites
       where household_id = household_a
         and expires_at > now() + interval '6 days') <> 1 then
    raise exception 'FAIL 6b: invite expiry did not default to seven days';
  end if;

  -- =========================================================================
  -- 7. updated_at trigger
  --
  -- Comparing before/after timestamps does not work here: now() is the
  -- transaction timestamp, so it is identical for every statement inside this
  -- block no matter how long they take. pg_sleep does not help.
  --
  -- The behaviour that actually matters is that the client cannot write the
  -- column — the trigger always overwrites it — so that is what is asserted.
  -- =========================================================================
  for row_count in
    select 1 from unnest(array[
      'profiles','households','meals','user_preferences',
      'pantry_items','grocery_lists'
    ]) as t(name)
    where not exists (
      select 1 from pg_trigger tg
      join pg_class c on c.oid = tg.tgrelid
      where c.relname = t.name
        and tg.tgname = 'set_' || t.name || '_updated_at'
        and not tg.tgisinternal
    )
  loop
    raise exception 'FAIL 7a: an updated_at trigger is missing';
  end loop;

  update meals
     set description = 'Braised in soy and vinegar',
         updated_at  = timestamptz '2000-01-01 00:00:00+00'
   where id = meal_id;

  select updated_at into after_updated from meals where id = meal_id;

  if after_updated < now() - interval '1 minute' then
    raise exception
      'FAIL 7b: the client was able to write updated_at; the trigger did not override it';
  end if;

  -- =========================================================================
  -- 8. Cascade behaviour
  --
  -- Deleting an account must not leave household rows pointing at nothing.
  -- =========================================================================
  delete from auth.users where id = user_b;
  if (select count(*) from profiles where id = user_b) <> 0 then
    raise exception 'FAIL 8a: deleting the auth user left a profile behind';
  end if;

  raise notice 'ALL CORE TABLE TESTS PASSED';
end $$;

-- Nothing above is kept.
rollback;
