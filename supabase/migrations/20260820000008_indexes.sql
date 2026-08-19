-- ---------------------------------------------------------------------------
-- 0008 · Indexes
-- See docs/DATABASE.md §7. Each one is tied to a query it serves.
-- ---------------------------------------------------------------------------

-- Hit by every household RLS policy, in both directions.
create index if not exists household_members_user_idx      on household_members (user_id);
create index if not exists household_members_household_idx on household_members (household_id);

-- The recency query runs on every single spin and must never table-scan.
create index if not exists meal_history_recent_idx
  on meal_history (household_id, eaten_at desc);

-- Roulette filters.
create index if not exists meals_cuisine_idx      on meals (cuisine);
create index if not exists meals_category_idx     on meals (category);
create index if not exists meals_time_idx         on meals (cooking_time_minutes);
create index if not exists meals_cost_idx         on meals (estimated_cost);
create index if not exists meals_visibility_idx   on meals (is_public, household_id);

-- Array containment for dietary filters and mood tags.
create index if not exists meals_dietary_tags_idx on meals using gin (dietary_tags);
create index if not exists meals_tags_idx         on meals using gin (tags);

-- Meal search by name.
create index if not exists meals_name_trgm_idx    on meals using gin (name gin_trgm_ops);

-- Ingredient matching joins these across the catalogue. It is the heaviest
-- read in the app and the one most likely to regress; benchmarked in
-- Sprint 27.
create index if not exists meal_ingredients_meal_idx       on meal_ingredients (meal_id);
create index if not exists meal_ingredients_ingredient_idx on meal_ingredients (ingredient_id);

create index if not exists pantry_items_household_idx  on pantry_items (household_id);
create index if not exists grocery_items_list_idx      on grocery_items (grocery_list_id);
create index if not exists grocery_lists_household_idx on grocery_lists (household_id);

-- Scoring reads these on every spin.
create index if not exists favorite_meals_user_idx on favorite_meals (user_id);
create index if not exists disliked_meals_user_idx on disliked_meals (user_id);

create index if not exists meal_plans_household_date_idx on meal_plans (household_id, planned_date);
create index if not exists meal_votes_session_idx        on meal_votes (session_id);
create index if not exists household_invites_code_idx    on household_invites (code);
