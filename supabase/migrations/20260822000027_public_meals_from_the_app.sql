-- Adding a meal to the shared catalogue, not just to one household.
--
-- The original policy refused it outright:
--
--   create policy "create own meals" on meals
--     for insert with check (
--       created_by = auth.uid() and not is_public and is_household_member(household_id)
--     );
--
-- `and not is_public` was the whole point of it. In an app with strangers in it
-- that is the right call — a catalogue anybody can write to is a catalogue
-- nobody's filters can be trusted against, and one household's "Tita Baby
-- adobo" is not something to put in front of everyone else.
--
-- **There is nobody else.** The rescope at Sprint 37 made this two people in one
-- house on one phone, and the distinction the policy protects — my meals versus
-- everybody's meals — no longer describes anything. What it still produces is a
-- real annoyance: every meal added by hand is filed as private, "Yours", behind
-- its own filter, when what somebody typing "sinigang" wants is for sinigang to
-- be in the list.
--
-- So a public insert is now allowed, with the two conditions that still mean
-- something:
--
--   * `created_by = auth.uid()` — a row still records who wrote it, and still
--     cannot be attributed to somebody else even by sending the column.
--   * `household_id is null` for a public meal. A catalogue row belongs to no
--     household, which is what the read policy already assumes; a public row
--     carrying a household id would be a meal that is both shared and owned, and
--     the delete policy below would let one household remove it from everyone.
--
-- Private meals are untouched: the app still offers both, and the household
-- branch of this policy is the same rule it always was.
drop policy if exists "create own meals" on public.meals;
create policy "create own meals" on public.meals
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and (
      -- One household's own meal, exactly as before.
      (not is_public and public.is_household_member(household_id))
      -- Or a catalogue meal, which belongs to no household.
      or (is_public and household_id is null)
    )
  );

-- Update and delete are deliberately **not** widened.
--
-- They already read `created_by = auth.uid()`, which means somebody can edit and
-- delete the catalogue meals they added and nobody else's — including none of the
-- sixty the seed shipped, because those were inserted by the migration and have
-- no `created_by`. That is the right shape: this change is about being able to
-- *add* to the list, not about being able to rewrite it.

comment on policy "create own meals" on public.meals is
  'A household meal (private, household-scoped) or a catalogue meal (public, no household). Both record their author. Widened from private-only in Sprint 53c — see the migration for why the original restriction stopped describing this app.';
