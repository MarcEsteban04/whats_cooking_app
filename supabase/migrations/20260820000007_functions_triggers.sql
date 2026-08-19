-- ---------------------------------------------------------------------------
-- 0007 · Functions and triggers
-- See docs/DATABASE.md §5
--
-- Every SECURITY DEFINER function sets search_path. Omitting it is a
-- privilege-escalation vector (docs/CODING_STANDARDS.md §11).
-- ---------------------------------------------------------------------------

-- --- Membership check -------------------------------------------------------
-- Household policies need to check membership, which queries
-- household_members, which evaluates the policy — infinite recursion.
-- SECURITY DEFINER bypasses RLS for the check itself and breaks the cycle
-- (docs/ARCHITECTURE.md §8.2).
create or replace function public.is_household_member(hid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from household_members
    where household_id = hid and user_id = auth.uid()
  );
$$;

-- --- updated_at -------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','households','meals','user_preferences',
    'pantry_items','grocery_lists'
  ] loop
    execute format('drop trigger if exists set_%1$s_updated_at on %1$s', t);
    execute format(
      'create trigger set_%1$s_updated_at before update on %1$s
       for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- --- New user provisioning --------------------------------------------------
-- Creates the profile, its preferences, a personal household, the owner
-- membership, and points active_household_id at it — atomically.
--
-- This is why signup cannot leave a half-provisioned account, and why every
-- household-scoped table can have a NOT NULL household_id: there is no such
-- thing as a user without a household (docs/ARCHITECTURE.md §6.2).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_household_id uuid;
  display text := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    split_part(coalesce(new.email, 'friend@example.com'), '@', 1)
  );
begin
  insert into profiles (id, display_name)
  values (new.id, display);

  insert into households (name, created_by, is_personal)
  values (display || '''s Kitchen', new.id, true)
  returning id into new_household_id;

  insert into household_members (household_id, user_id, role)
  values (new_household_id, new.id, 'owner');

  insert into user_preferences (user_id) values (new.id);

  update profiles
     set active_household_id = new_household_id
   where id = new.id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --- Invite code generation -------------------------------------------------
-- Excludes 0/O/1/I: these codes are read aloud and typed by hand.
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..8 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return result;
end;
$$;
