-- ---------------------------------------------------------------------------
-- 0011 · Free-text dislikes captured during onboarding
-- See docs/DATABASE.md §4.8
-- ---------------------------------------------------------------------------

-- user_preferences.disliked_ingredients holds ingredient ids, which is the
-- right long-term shape — the recommendation engine filters on ids, not on
-- strings a user typed. But onboarding runs before the ingredient catalogue
-- exists for that user's vocabulary: someone types "bagoong" or "cilantro" on
-- their first day and there may be no matching row, or no catalogue at all.
--
-- Dropping that input would be the wrong trade. Onboarding's stated rule is
-- that an abandoned run still leaves the app smarter than a blank one
-- (docs/USER_FLOWS.md §5), and a disliked food is the single most valuable
-- thing a user can tell us: it is a hard exclusion, not a preference weight.
--
-- So names are stored alongside ids rather than instead of them. When the
-- catalogue lands, a reconciliation pass resolves what it can into
-- disliked_ingredients and leaves the rest here as an unmatched record.
alter table user_preferences
  add column if not exists disliked_ingredient_names text[] not null default '{}';

comment on column user_preferences.disliked_ingredient_names is
  'Free-text foods the user said they avoid, as typed during onboarding. Resolved into disliked_ingredients once the ingredient catalogue can match them; unmatched entries stay here rather than being discarded.';

-- Guards the two ways this column degrades: an unbounded list, and blank
-- entries from a stray comma. Both are cheap to prevent and annoying to clean
-- up later.
do $$ begin
  alter table user_preferences
    add constraint user_preferences_disliked_names_sane check (
      array_length(disliked_ingredient_names, 1) is null
      or (
        array_length(disliked_ingredient_names, 1) <= 50
        and array_position(disliked_ingredient_names, '') is null
        and array_position(disliked_ingredient_names, null) is null
      )
    );
exception when duplicate_object then null; end $$;
