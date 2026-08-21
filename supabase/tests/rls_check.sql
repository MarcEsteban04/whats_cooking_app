-- Row Level Security verification (Sprint 51).
--
-- Paste into the Supabase SQL editor and run. It prints a table of checks and
-- raises an exception if any of them fail, so a green run is a green run rather
-- than a wall of output somebody has to read.
--
-- ## What this can and cannot prove
--
-- **It proves the two failures that actually happen.** A policy written
-- `using (true)`, and a table where `enable row level security` was forgotten —
-- either of which makes every other policy on the table decoration. Both are
-- silent: the app keeps working perfectly, because the app only ever asks for its
-- own rows.
--
-- **It cannot prove cross-household isolation with one household's data.** The
-- honest negative test for "household A cannot read household B" needs a second
-- real account, because `household_members.user_id` references `auth.users` and a
-- fabricated uuid cannot be inserted. So the closest available test is used
-- instead, and it is a strong one: impersonate an authenticated user who belongs
-- to **no** household and assert that every household-scoped table returns zero
-- rows and refuses every write. A policy loose enough to leak across households
-- will almost always leak to that user too.
--
-- To do the real thing, sign up a second account on a second device, note its
-- uuid, and set `second_user` below.
--
-- ## Safety
--
-- Read-only apart from the write attempts, and those are all expected to be
-- *refused* — each one runs inside its own savepoint and is rolled back whether it
-- fails or (alarmingly) succeeds. Nothing here can leave a row behind.

do $$
declare
  nobody      uuid := '00000000-0000-0000-0000-0000000000ff';
  failures    int  := 0;
  n           int;
  offender    text;

  -- Every table the app owns. Kept as a literal list rather than read from the
  -- catalogue on purpose: a new table that nobody added here shows up as a gap in
  -- the final count, which is the point.
  app_tables  text[] := array[
    'profiles', 'user_preferences',
    'households', 'household_members', 'household_invites',
    'meals', 'meal_ingredients', 'ingredients',
    'favorite_meals', 'disliked_meals', 'meal_history',
    'pantry_items',
    'grocery_lists', 'grocery_items',
    'restaurants', 'restaurant_history',
    'meal_plans', 'vote_sessions', 'meal_votes',
    'ai_usage', 'analytics_events'
  ];

  -- Household-scoped tables an unaffiliated user must see nothing in.
  scoped      text[] := array[
    'pantry_items', 'grocery_lists', 'grocery_items',
    'restaurants', 'restaurant_history', 'meal_history',
    'households', 'household_members', 'meal_plans'
  ];

  t           text;
begin
  raise notice '--- 1. RLS is enabled on every table ---';

  for t in select unnest(app_tables) loop
    select count(*) into n
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relname = t and c.relrowsecurity;

    if n = 0 then
      -- Distinguishes "table is missing" from "table has RLS off". The second is
      -- a hole; the first is a migration that has not been applied.
      select count(*) into n from pg_class c
      join pg_namespace ns on ns.oid = c.relnamespace
      where ns.nspname = 'public' and c.relname = t;

      if n = 0 then
        raise notice 'MISSING  %  (migration not applied?)', t;
      else
        raise notice 'FAIL     %  row level security is OFF', t;
      end if;
      failures := failures + 1;
    end if;
  end loop;

  raise notice '--- 2. every table has at least one policy ---';

  -- RLS enabled with no policies denies everything, which is safe but is almost
  -- certainly not what was intended — and it is how a feature breaks in
  -- production while passing every local test against a service-role key.
  for t in select unnest(app_tables) loop
    select count(*) into n from pg_policies
    where schemaname = 'public' and tablename = t;

    if n = 0 then
      raise notice 'FAIL     %  RLS on, zero policies (denies everything)', t;
      failures := failures + 1;
    end if;
  end loop;

  raise notice '--- 3. no policy is unconditionally true ---';

  -- `using (true)` on a private table is the loosest thing that still looks like
  -- a policy. `ingredients` is the one legitimate exception: the vocabulary is
  -- deliberately readable by every signed-in user, because nobody may be blocked
  -- from adding food the catalogue does not know.
  for offender in
    select format('%s.%s (%s)', tablename, policyname, cmd)
    from pg_policies
    where schemaname = 'public'
      and tablename <> 'ingredients'
      and (
        coalesce(qual, '') in ('true', '(true)')
        or coalesce(with_check, '') in ('true', '(true)')
      )
  loop
    raise notice 'FAIL     % is unconditionally true', offender;
    failures := failures + 1;
  end loop;

  raise notice '--- 4. an authenticated stranger sees nothing ---';

  -- The negative case, as far as one household's data allows. `set local` so the
  -- impersonation cannot outlive this block.
  set local role authenticated;
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', nobody, 'role', 'authenticated')::text,
    true
  );

  for t in select unnest(scoped) loop
    execute format('select count(*) from public.%I', t) into n;
    if n <> 0 then
      raise notice 'FAIL     % returned % row(s) to a stranger', t, n;
      failures := failures + 1;
    end if;
  end loop;

  raise notice '--- 5. a stranger sees the public catalogue and nothing private ---';

  -- Meals are the one table with a deliberate public half. The check is that the
  -- *private* half stays invisible: a household's own meals must never appear to
  -- somebody outside it, which is the whole point of `meals_visibility_idx`'s
  -- policy pair.
  select count(*) into n from public.meals where is_public = false;
  if n <> 0 then
    raise notice 'FAIL     meals leaked % private row(s) to a stranger', n;
    failures := failures + 1;
  end if;

  raise notice '--- 6. a stranger cannot write ---';

  begin
    -- Expected to be refused by the `create own meals` policy. Wrapped so the
    -- refusal is the pass condition and a success is the failure.
    insert into public.meals (name, cuisine, category, difficulty, is_public)
    values ('rls probe', 'filipino', 'dinner', 'easy', true);

    raise notice 'FAIL     a stranger inserted into meals';
    failures := failures + 1;
  exception
    when insufficient_privilege or check_violation or not_null_violation then
      null;  -- refused, which is the point
    when others then
      -- Any other error still means the write did not land. Reported so a
      -- surprising SQLSTATE is visible rather than silently counted as a pass.
      raise notice 'note     meals insert refused with %', sqlstate;
  end;

  begin
    insert into public.pantry_items (household_id, ingredient_id)
    values (nobody, nobody);

    raise notice 'FAIL     a stranger inserted into pantry_items';
    failures := failures + 1;
  exception
    when insufficient_privilege or foreign_key_violation then
      null;
    when others then
      raise notice 'note     pantry_items insert refused with %', sqlstate;
  end;

  reset role;
  perform set_config('request.jwt.claims', null, true);

  raise notice '--- 7. anon sees only the public catalogue ---';

  set local role anon;

  select count(*) into n from public.meals where is_public = false;
  if n <> 0 then
    raise notice 'FAIL     anon can read % private meal(s)', n;
    failures := failures + 1;
  end if;

  for t in select unnest(scoped) loop
    execute format('select count(*) from public.%I', t) into n;
    if n <> 0 then
      raise notice 'FAIL     anon read % row(s) from %', n, t;
      failures := failures + 1;
    end if;
  end loop;

  reset role;

  raise notice '--- 8. ai_usage and analytics_events are not readable back ---';

  -- Both are write-mostly: the client appends and never reads. A select policy on
  -- either would turn "what this household eats" into a queryable feed, and
  -- `ai_usage` additionally carries provider error text.
  select count(*) into n from pg_policies
  where schemaname = 'public'
    and tablename in ('ai_usage', 'analytics_events')
    and cmd in ('SELECT', 'ALL')
    and coalesce(qual, '') in ('true', '(true)');

  if n <> 0 then
    raise notice 'FAIL     % unconditional select policy/policies on the write-only tables', n;
    failures := failures + 1;
  end if;

  if failures > 0 then
    raise exception '% RLS check(s) failed — see the notices above', failures;
  end if;

  raise notice 'All RLS checks passed.';
end $$;
