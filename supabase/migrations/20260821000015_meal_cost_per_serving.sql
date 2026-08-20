-- ---------------------------------------------------------------------------
-- 0015 · Cost per serving, as a column
-- See docs/DATABASE.md §4.5
-- ---------------------------------------------------------------------------

-- `estimated_cost` is for the servings the recipe states, so two meals at 300
-- pesos are not the same price if one feeds two people and the other feeds five.
-- Every place the app asks about budget asks per head: the onboarding question,
-- the profile setting, the discovery filter (Sprint 22) and the roulette's
-- budget constraint (Sprint 30).
--
-- A generated column rather than arithmetic at the call site. PostgREST can
-- filter and order on a column but not on an expression, so without this the
-- budget filter would have to fetch every candidate and divide in Dart — which
-- breaks pagination, because the server would no longer know how many rows
-- match.
--
-- Stored rather than virtual, so it can be indexed. `servings` is
-- check-constrained greater than zero, so there is no division by zero to guard.
alter table meals
  add column if not exists cost_per_serving numeric(10,2)
  generated always as (estimated_cost / servings) stored;

create index if not exists meals_cost_per_serving_idx
  on meals (cost_per_serving);
