-- ---------------------------------------------------------------------------
-- 0014 · A stable identity for catalogue meals
-- See docs/DATABASE.md §4.5 and §9 Q4
-- ---------------------------------------------------------------------------

-- The catalogue seed (supabase/seed/) has to be re-runnable: it is pasted into
-- the SQL Editor during setup, again when the catalogue grows, and again on any
-- fresh environment. Without a unique key on the public catalogue, a second run
-- would silently produce sixty duplicate meals, and the roulette would start
-- offering the same dish twice with two different ids.
--
-- `lower(name)` is that key, and it is a real catalogue invariant rather than a
-- convenience for the seed: two public meals with the same name are
-- indistinguishable to the person choosing between them. Distinguish them in
-- the name — "Chicken Adobo" and "Pork Adobo" — not in the id.
--
-- Partial, on `is_public`. Household-private custom meals (Sprint 26) are
-- deliberately excluded: two households may each name a meal "Mama's Adobo",
-- and neither can see the other's.
create unique index if not exists meals_public_name_uk
  on meals (lower(name))
  where is_public;
