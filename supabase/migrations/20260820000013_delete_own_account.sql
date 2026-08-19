-- ---------------------------------------------------------------------------
-- 0013 · Account deletion
-- See docs/USER_FLOWS.md §17, docs/DATABASE.md §7
-- ---------------------------------------------------------------------------

-- Deleting a row from auth.users is privileged, and rightly so. The client
-- cannot be trusted with a key that could delete *anyone*, so the only key the
-- app ships is the publishable one, which cannot reach auth.users at all.
--
-- This function is the narrow exception: security definer, so it runs with the
-- owner's rights, but it takes no arguments and deletes only auth.uid(). There
-- is no parameter to tamper with, so there is no way to aim it at another
-- account. That property is the whole design - a delete_user(id uuid) variant
-- would be a privilege-escalation hole no matter how carefully it checked.
--
-- Everything else disappears by cascade: profiles.id references auth.users on
-- delete cascade, and every user-owned table cascades from profiles. Household
-- rows created by this user are removed with them; a partner's own rows are
-- not, which is what "the household retains its data" means in the flow.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'delete_own_account requires an authenticated session'
      using errcode = '28000';
  end if;

  delete from auth.users where id = uid;
end;
$$;

comment on function public.delete_own_account is
  'Deletes the calling user and everything cascading from them. Takes no arguments by design: there is no id to tamper with, so it can only ever delete the caller.';

-- Only a signed-in user may call it. anon has no business here, and revoking
-- from public first means a future grant has to be deliberate.
revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
