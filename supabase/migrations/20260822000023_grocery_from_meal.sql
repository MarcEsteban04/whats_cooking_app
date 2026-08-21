-- Sprint 43 — accepting a meal fills in the shopping list.
--
--   Accepted meal → required ingredients → compare pantry → missing only → list
--
-- **Server-side, and this time it is not only about payload.** The client does not
-- *have* the accepted meal's ingredient list: the spin fetches `meals`-only
-- columns, so the result screen holds a meal with no recipe attached. Fetching one
-- to then write another table would be two round trips and a race; this is one
-- call that reads and writes in a single transaction.

-- ---------------------------------------------------------------------------
-- Put whatever the kitchen is short of onto the list.
-- ---------------------------------------------------------------------------
--
-- **Merges rather than duplicating.** `grocery_items` has no uniqueness to lean on
-- — it cannot, because free-text lines have no id to be unique on — so this
-- updates the existing line for an ingredient and inserts only the rest. Two
-- lines for chicken is a list you have to read twice in an aisle.
--
-- **Staples and optional ingredients are skipped**, matching `pantry_match()`.
-- Nobody wants "salt" on a shopping list every time they accept a meal, and a
-- garnish they were always going to leave out is not a reason to go to the shop.
--
-- **Quantities are not scaled to the household's servings**, and that is a
-- decision rather than an omission. Scaling a four-serving recipe to two people
-- turns "1 bulb garlic" into "0.5 bulb" and "3 pc egg" into "1.5 pc" — amounts
-- that cannot be bought and that make the whole list look approximate. Buying what
-- the recipe says leaves the surplus in the kitchen, which is the input to the
-- next spin's pantry match anyway.
--
-- Returns how many lines it touched, so the app can say so. A list that silently
-- grows is a list somebody has to re-read.
create or replace function public.add_missing_to_grocery(p_meal_id uuid)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_household uuid;
  v_list uuid;
  v_touched integer := 0;
  v_updated integer := 0;
  v_inserted integer := 0;
begin
  select p.active_household_id into v_household
  from public.profiles p
  where p.id = auth.uid();

  if v_household is null then
    return 0;
  end if;

  -- The household's active list, created if this is the first thing to go on it.
  -- `grocery_lists_one_active_idx` makes a duplicate impossible, so the insert is
  -- safe to attempt and the re-read covers losing a race with the client.
  select gl.id into v_list
  from public.grocery_lists gl
  where gl.household_id = v_household and gl.is_active
  limit 1;

  if v_list is null then
    insert into public.grocery_lists (household_id)
    values (v_household)
    on conflict do nothing
    returning id into v_list;

    if v_list is null then
      select gl.id into v_list
      from public.grocery_lists gl
      where gl.household_id = v_household and gl.is_active
      limit 1;
    end if;
  end if;

  if v_list is null then
    return 0;
  end if;

  -- What this meal needs that the kitchen does not have.
  create temporary table if not exists _wanted (
    ingredient_id uuid primary key,
    quantity numeric(10,2),
    unit text
  ) on commit drop;

  delete from _wanted;

  insert into _wanted (ingredient_id, quantity, unit)
  select mi.ingredient_id, mi.quantity, mi.unit
  from public.meal_ingredients mi
  join public.ingredients i on i.id = mi.ingredient_id
  where mi.meal_id = p_meal_id
    and mi.is_optional = false
    and i.is_staple = false
    and not exists (
      select 1
      from public.pantry_items pi
      where pi.household_id = v_household
        and pi.ingredient_id = mi.ingredient_id
    );

  -- Already on the list: add to what is there, and un-tick it. Something wanted
  -- again is something to buy again.
  with bumped as (
    update public.grocery_items gi
    set quantity = coalesce(gi.quantity, 0) + coalesce(w.quantity, 0),
        unit = coalesce(nullif(gi.unit, ''), w.unit),
        is_completed = false,
        completed_at = null,
        completed_by = null,
        added_from_meal_id = coalesce(gi.added_from_meal_id, p_meal_id)
    from _wanted w
    where gi.grocery_list_id = v_list
      and gi.ingredient_id = w.ingredient_id
    returning gi.ingredient_id
  )
  select count(*) into v_updated from bumped;

  -- Everything else is new.
  with added as (
    insert into public.grocery_items (
      grocery_list_id, ingredient_id, quantity, unit, added_from_meal_id
    )
    select v_list, w.ingredient_id, w.quantity, w.unit, p_meal_id
    from _wanted w
    where not exists (
      select 1
      from public.grocery_items gi
      where gi.grocery_list_id = v_list
        and gi.ingredient_id = w.ingredient_id
    )
    returning id
  )
  select count(*) into v_inserted from added;

  v_touched := v_updated + v_inserted;
  return v_touched;
end;
$$;

comment on function public.add_missing_to_grocery(uuid) is
  'Adds a meal''s missing non-staple, non-optional ingredients to the household''s active grocery list, merging with existing lines. Returns how many lines were touched. Sprint 43.';

grant execute on function public.add_missing_to_grocery(uuid) to authenticated;

-- The lookup the merge leans on: one list's lines by ingredient.
create index if not exists grocery_items_list_ingredient_idx
  on public.grocery_items (grocery_list_id, ingredient_id);
