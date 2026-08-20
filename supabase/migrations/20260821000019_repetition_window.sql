-- ---------------------------------------------------------------------------
-- 0019 · A configurable repetition window
-- See docs/DATABASE.md §4.8. Sprint 32.
-- ---------------------------------------------------------------------------

-- How many days a meal is out of the running for after being eaten.
--
-- Sprint 32 asks for a "configurable repetition window", and configurable has to
-- mean by the person it affects. Households differ more here than anywhere else
-- in these preferences: one cooks a rotation of six things and wants three days,
-- another never repeats inside a month, and a single person eating alone may not
-- care at all.
--
-- Nullable, and null means the default rather than zero — the same distinction
-- `default_budget` makes, and for the same reason: "never answered" and "answered
-- with none" are different facts and the engine treats them differently.
--
-- Bounded at 60 because beyond that a sixty-meal catalogue cannot fill the
-- window, and an engine with nothing left to offer is a worse outcome than a
-- repeat. The floor is 0, which is a legitimate answer: it means "we do not mind
-- eating the same thing twice", and somebody cooking for one might well say so.
alter table user_preferences
  add column if not exists repetition_window_days smallint
  check (
    repetition_window_days is null
    or (repetition_window_days >= 0 and repetition_window_days <= 60)
  );

comment on column user_preferences.repetition_window_days is
  'Days a meal is excluded from the roulette after being eaten. Null means the app default; 0 means the household does not mind repeats.';
