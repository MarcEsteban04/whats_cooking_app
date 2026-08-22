-- Deleting and rewriting catalogue meals, not only the ones you wrote.
--
-- Migration 0027 let a household add to the shared catalogue and deliberately
-- left update and delete alone, on the grounds that adding to a list is not the
-- same as rewriting it. That was the right *default* and the wrong answer for
-- this app: the sixty seeded rows were inserted by a migration and carry no
-- `created_by`, so
--
--   create policy "delete own meals" on meals for delete using (created_by = auth.uid());
--
-- made every catalogue meal permanently undeletable by anybody. A list you can
-- only add to fills up with food this household does not eat, and the sixty are
-- a starting point rather than a canon.
--
-- **There is nobody else to protect.** Same reasoning as 0027, and the same
-- limit: this is two people in one house. In an app with strangers in it, a
-- catalogue anybody may delete from is a catalogue that disappears.
--
-- What still holds, and is doing real work:
--
--   * **`meal_history.meal_id` is `on delete restrict`.** A meal that has been
--     eaten cannot be deleted, by anybody, and this migration does not touch
--     that. History is a record of what happened; a recipe going should not
--     rewrite the nights it was cooked. The app reports that refusal as its own
--     outcome rather than as a failure.
--   * `authenticated`, so nothing here is readable or writable while signed out.
--
-- Private meals are unchanged: still author-scoped, because a household's own
-- recipe belongs to whoever wrote it.
drop policy if exists "update own meals" on public.meals;
create policy "update own meals" on public.meals
  for update
  to authenticated
  using (
    created_by = auth.uid()
    -- A catalogue meal, which belongs to no household and so to everybody here.
    or (is_public and household_id is null)
  )
  with check (
    created_by = auth.uid()
    or (is_public and household_id is null)
  );

drop policy if exists "delete own meals" on public.meals;
create policy "delete own meals" on public.meals
  for delete
  to authenticated
  using (
    created_by = auth.uid()
    or (is_public and household_id is null)
  );

comment on policy "delete own meals" on public.meals is
  'A meal you wrote, or any catalogue meal. Sprint 53f: the seeded sixty carry no created_by and were undeletable by anybody, which made the catalogue append-only. meal_history''s on-delete-restrict still refuses a meal that has been eaten.';
