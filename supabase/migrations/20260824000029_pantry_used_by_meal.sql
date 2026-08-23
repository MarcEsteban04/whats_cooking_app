-- Sprint 54 — what cooking a meal takes out of the kitchen.
--
-- The mirror of `add_missing_to_grocery` (migration 0023), and the missing half
-- of the same loop:
--
--   accepted meal → required ingredients → compare pantry → missing → the list
--   accepted meal → required ingredients → compare pantry → present → the kitchen
--
-- **The pantry only ever grew.** Accepting a meal has never touched it, so a
-- household adds chicken, cooks it, and the app still believes the chicken is
-- there. That was survivable while the pantry was only a *bonus* in the scorer —
-- twenty points, a nudge. Sprint 54 made it a **filter**, and a filter is only as
-- good as the data is fresh: "All in" fills up with meals that cannot actually be
-- cooked, and every fridge scan is undone by the next dinner.
--
-- **This function reads and decides nothing.** It returns the overlap and lets the
-- app ask. Deducting silently would be the worst version of this feature: the
-- recipe says 500 g of chicken and somebody used 300, or used the last of the soy
-- sauce the recipe never mentioned, and only they know which. An app that quietly
-- rewrites the kitchen after every meal is an app whose kitchen nobody trusts —
-- and the whole point is a pantry accurate enough to filter on.
--
-- Same exclusions as the grocery half, for the same reasons:
--
--   * **Staples are skipped.** Salt and oil are assumed always in
--     (docs/USER_FLOWS.md §12); deducting them would empty the shelf that exists
--     precisely so nobody has to track it.
--   * **Optional ingredients are skipped.** A garnish somebody was always going to
--     leave out is not a reason to change the kitchen.
--
-- **Quantities are not scaled to the household's servings**, matching 0023: a
-- four-serving recipe scaled to two turns "3 pc egg" into "1.5 pc", and a pantry
-- holding one and a half eggs is worse than one holding three.
create or replace function public.pantry_used_by_meal(p_meal_id uuid)
returns table (
  pantry_item_id   uuid,
  ingredient_name  text,
  have_quantity    numeric,
  have_unit        text,
  needs_quantity   numeric,
  needs_unit       text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_household uuid;
begin
  select p.active_household_id into v_household
  from public.profiles p
  where p.id = auth.uid();

  if v_household is null then
    return;
  end if;

  return query
  select
    pi.id,
    i.name,
    pi.quantity,
    pi.unit,
    mi.quantity,
    mi.unit
  from public.meal_ingredients mi
  join public.ingredients i on i.id = mi.ingredient_id
  -- An inner join, so only what the kitchen actually holds comes back. What it
  -- does *not* hold is the other function's business.
  join public.pantry_items pi
    on pi.ingredient_id = mi.ingredient_id
   and pi.household_id = v_household
  where mi.meal_id = p_meal_id
    and not coalesce(mi.is_optional, false)
    and not coalesce(i.is_staple, false)
  order by i.name;
end;
$$;

comment on function public.pantry_used_by_meal(uuid) is
  'What cooking this meal would take out of the kitchen: the overlap between its ingredients and the pantry, with both amounts. Reads only — the app confirms before anything changes. Staples and optional ingredients are skipped, as in add_missing_to_grocery. Sprint 54.';

revoke all on function public.pantry_used_by_meal(uuid) from public;
grant execute on function public.pantry_used_by_meal(uuid) to authenticated;
