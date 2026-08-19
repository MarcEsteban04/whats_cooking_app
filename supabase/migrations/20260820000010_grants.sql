-- ---------------------------------------------------------------------------
-- 0010 · Table privileges
--
-- RLS decides which *rows* a role may see. Grants decide whether the role may
-- touch the table at all. Both have to line up, and relying on Supabase's
-- default privileges leaves that implicit — so it is stated here.
--
-- This is defence in depth: if a future policy is written carelessly, the
-- grants still stop an anonymous key from reaching user data.
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;

-- Signed-in users may attempt anything; RLS constrains it to their own rows
-- and their household's.
grant select, insert, update, delete on all tables in schema public to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

-- Anonymous access is limited to the public meal catalogue.
--
-- This is deliberate, not an oversight: guest mode lets someone spin before
-- creating an account (docs/PRD.md US-A-01), which needs the catalogue
-- readable without a session. The meals select policy already allows it via
-- `is_public`; revoking everything else means that even a careless future
-- policy cannot expose user data to an unauthenticated key.
revoke all on all tables in schema public from anon;
grant select on meals to anon;
grant select on meal_ingredients to anon;
grant select on ingredients to anon;

alter default privileges in schema public
  revoke all on tables from anon;

-- Functions callable by both roles. is_household_member is SECURITY DEFINER,
-- so it returns false rather than erroring when auth.uid() is null.
grant execute on function public.is_household_member(uuid) to anon, authenticated;
grant execute on function public.generate_invite_code() to authenticated;
