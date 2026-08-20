-- ===========================================================================
-- What's Cooking? — schema verification
--
-- Run this in the Supabase SQL Editor after applying schema.sql.
-- Every row should read PASS. Anything else means the schema did not apply
-- cleanly, and you should not build against it.
-- ===========================================================================

with
tables_check as (
  select
    '1. tables' as check_name,
    count(*)    as found,
    17          as expected
  from information_schema.tables
  where table_schema = 'public'
    and table_name in (
      'profiles','households','household_members','household_invites',
      'meals','ingredients','meal_ingredients','user_preferences',
      'favorite_meals','disliked_meals','meal_history','pantry_items',
      'grocery_lists','grocery_items','meal_plans','vote_sessions','meal_votes'
    )
),
rls_check as (
  -- RLS is the security boundary. A table without it is wide open.
  select
    '2. RLS enabled on every table' as check_name,
    count(*) filter (where rowsecurity) as found,
    count(*) as expected
  from pg_tables
  where schemaname = 'public'
    and tablename in (
      'profiles','households','household_members','household_invites',
      'meals','ingredients','meal_ingredients','user_preferences',
      'favorite_meals','disliked_meals','meal_history','pantry_items',
      'grocery_lists','grocery_items','meal_plans','vote_sessions','meal_votes'
    )
),
policy_check as (
  select
    '3. policies present' as check_name,
    count(*)             as found,
    30                   as expected
  from pg_policies where schemaname = 'public'
),
function_check as (
  select
    '4. functions' as check_name,
    count(*)       as found,
    4              as expected
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'is_household_member','set_updated_at','handle_new_user',
      'generate_invite_code'
    )
),
trigger_check as (
  -- Without this trigger, signup leaves a user with no profile and no
  -- household, and every household-scoped write fails.
  select
    '5. signup provisioning trigger' as check_name,
    count(*) as found,
    1        as expected
  from pg_trigger
  where tgname = 'on_auth_user_created' and not tgisinternal
),
search_path_check as (
  -- A SECURITY DEFINER function without a fixed search_path is a
  -- privilege-escalation vector.
  select
    '6. SECURITY DEFINER functions pin search_path' as check_name,
    count(*) filter (
      where p.proconfig is not null
        and exists (
          select 1 from unnest(p.proconfig) c where c like 'search_path=%'
        )
    ) as found,
    count(*) as expected
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
),
updated_at_trigger_check as (
  -- One per table carrying updated_at. The column is maintained by trigger so
  -- clients never write it.
  select
    '8. updated_at triggers' as check_name,
    count(*) as found,
    6        as expected
  from pg_trigger tg
  join pg_class c on c.oid = tg.tgrelid
  where not tg.tgisinternal
    and tg.tgname like 'set_%_updated_at'
    and c.relname in (
      'profiles','households','meals','user_preferences',
      'pantry_items','grocery_lists'
    )
),
index_check as (
  select
    '7. key indexes' as check_name,
    count(*)         as found,
    7                as expected
  from pg_indexes
  where schemaname = 'public'
    and indexname in (
      'meal_history_recent_idx',
      'household_members_user_idx',
      'meals_name_trgm_idx',
      -- Added by migration 0014. It is a correctness constraint rather than a
      -- performance index: without it, re-running the catalogue seed duplicates
      -- every meal.
      'meals_public_name_uk',
      -- Added by migration 0015, alongside the generated `cost_per_serving`
      -- column. The Meals tab filters and sorts on it, so a database missing
      -- the column fails the budget filter and the cheapest sort outright.
      'meals_cost_per_serving_idx',
      -- Added by migration 0016. The Meals tab's default sort had no usable
      -- index before it — the trigram index on `name` answers `ilike` and
      -- cannot order — so a database missing this one still works and pages
      -- slowly, which is the failure mode worth catching before users find it.
      'meals_name_id_idx',
      'meals_own_created_at_idx'
    )
),
onboarding_column_check as (
  -- Added by migration 0011. Onboarding writes free-text dislikes here, so a
  -- missing column fails every per-step save with a column-not-found error
  -- rather than with anything a user could act on.
  select
    '8. onboarding dislike column' as check_name,
    count(*)                       as found,
    1                              as expected
  from information_schema.columns
  where table_schema = 'public'
    and table_name   = 'user_preferences'
    and column_name  = 'disliked_ingredient_names'
),
avatar_bucket_check as (
  -- Added by migration 0012. Without the bucket every avatar upload fails, and
  -- the failure surfaces only when a user first tries to set a photo.
  select
    '9. avatars bucket' as check_name,
    count(*)            as found,
    1                   as expected
  from storage.buckets
  where id = 'avatars'
),
account_deletion_check as (
  -- Added by migration 0013. Settings offers "Delete account"; a missing
  -- function turns that into an error at the worst possible moment.
  select
    '10. delete_own_account' as check_name,
    count(*)                 as found,
    1                        as expected
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'delete_own_account'
    and p.prosecdef
)
select
  check_name,
  found,
  expected,
  case when found >= expected then 'PASS' else 'FAIL' end as result
from (
  select * from tables_check
  union all select * from rls_check
  union all select * from policy_check
  union all select * from function_check
  union all select * from trigger_check
  union all select * from search_path_check
  union all select * from updated_at_trigger_check
  union all select * from index_check
  union all select * from onboarding_column_check
  union all select * from avatar_bucket_check
  union all select * from account_deletion_check
) checks
order by check_name;
