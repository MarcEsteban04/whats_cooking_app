-- ---------------------------------------------------------------------------
-- 0016 · Indexes for the meal feed's real query shapes
-- See docs/DATABASE.md §7. Sprint 27.
-- ---------------------------------------------------------------------------

-- 0008 indexed the columns the roulette *filters* on, which was the right guess
-- at the time. What the Meals tab turned out to do is sort and page, and those
-- want a different shape: every one of its four sorts ends in the primary key,
-- because a sort that is not a total order lets two rows swap places between the
-- request for page one and the request for page two — the reader sees one meal
-- twice and never sees another at all (`MealSort.tiebreaker`).
--
-- A single-column index cannot serve `order by x, id`: Postgres can walk it for
-- `x` and then has to sort the whole result to break the ties. With the id in
-- the index the ordering is already there, so `limit`/`offset` reads the rows it
-- needs and stops. That is the difference between a sort of the matching set and
-- a scan of one page of it, and it grows with the catalogue rather than with the
-- page.
--
-- These do not replace the 0008 indexes. Those still serve the roulette's
-- filter-only queries, where there is no ordering to satisfy.

-- `MealSort.alphabetical`, the default — so the first screen anyone sees is the
-- one query that had no usable index at all. `meals_name_trgm_idx` is a GIN
-- trigram index: it answers `ilike '%adobo%'` and is no use for `order by name`.
create index if not exists meals_name_id_idx
  on meals (name, id);

-- `MealSort.quickest`.
create index if not exists meals_time_id_idx
  on meals (cooking_time_minutes, id);

-- `MealSort.cheapest`, on the generated column from 0015.
create index if not exists meals_cost_per_serving_id_idx
  on meals (cost_per_serving, id);

-- `MealSort.newest`. Descending in the index, matching the query: a btree can be
-- read backwards, but stating the direction keeps the plan the obvious one and
-- costs nothing.
create index if not exists meals_created_at_id_idx
  on meals (created_at desc, id);

-- `MealRepository.mine` — the household's own recipes, newest first.
--
-- Partial, and that is the point. `is_public = false` is a few rows in a
-- catalogue that is overwhelmingly public, so the index holds only what the
-- query wants and stays small enough to be worth reading. It also serves the
-- `read visible meals` policy's non-public half.
create index if not exists meals_own_created_at_idx
  on meals (created_at desc, id)
  where not is_public;

comment on index meals_name_id_idx is
  'Serves the Meals tab default sort (name, id). The trigram index on name cannot order.';
comment on index meals_own_created_at_idx is
  'Partial index for MealRepository.mine: the household''s own meals, newest first.';
