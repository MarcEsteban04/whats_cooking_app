-- Sprint 51 — the index review's one finding.
--
-- The pantry's add field autocompletes against `ingredients` with
-- `ilike 'term%'`, and the index that looks like it serves that query does not:
--
--   create index ingredients_name_idx on public.ingredients (name);
--
-- A plain btree cannot answer `ILIKE` at all. Postgres will use a btree for
-- `LIKE 'x%'` only when the index carries `text_pattern_ops` or the database runs
-- in the C collation, and neither applies here — and `ILIKE` is case-insensitive,
-- which rules the btree out regardless. So every keystroke in the ingredient
-- field is a sequential scan of the whole table.
--
-- `meals.name` already has exactly this index for exactly this reason
-- (`meals_name_trgm_idx`, migration 0008); the ingredient vocabulary was simply
-- missed. `pg_trgm` is enabled in migration 0001.
--
-- **Honest about the size of the win.** The seeded vocabulary is a few hundred
-- rows, so today's sequential scan costs a fraction of a millisecond and nobody
-- would feel it. This is worth doing anyway for two reasons: the table grows
-- every time somebody adds an ingredient the catalogue did not have — that is a
-- deliberate feature of the `authenticated add ingredients` policy, so it grows
-- with use — and the query sits on the interactive path, where the debounce is
-- covering for it. An index that is cheap now and correct later beats one added
-- after somebody notices the field feels slow.
--
-- The old btree is **kept**, not replaced: `.order('name')` in the same query is
-- a sort the btree does serve, and dropping it would trade one problem for
-- another.
create index if not exists ingredients_name_trgm_idx
  on public.ingredients using gin (name gin_trgm_ops);

comment on index public.ingredients_name_trgm_idx is
  'Serves the pantry autocomplete''s ilike prefix match, which the plain btree on name cannot. Sprint 51.';
