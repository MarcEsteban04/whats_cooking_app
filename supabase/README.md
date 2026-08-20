# Supabase

## Applying the schema

1. Create a project at [supabase.com](https://supabase.com) (or reuse an existing one).
2. Open **SQL Editor → New query**.
3. Paste the whole of [`schema.sql`](schema.sql) and **Run**.
4. Paste [`verify.sql`](verify.sql) and **Run**. Every row must read `PASS`.

`schema.sql` is safe to re-run — everything is `create ... if not exists` or
`create or replace`.

## Seeding the meal catalogue

The schema gives you empty tables. Without the catalogue the roulette has
nothing to land on, so this is part of setting up, not an optional extra.

Paste each file in order and **Run**:

| File | What it adds |
| ---- | ------------ |
| [`seed/01_ingredients.sql`](seed/01_ingredients.sql) | 137 ingredients, ten of them marked as staples |
| [`seed/02_meals.sql`](seed/02_meals.sql) | 60 public meals across seven cuisines and all five categories |
| [`seed/03_meal_ingredients.sql`](seed/03_meal_ingredients.sql) | 310 links saying what each meal is made of |
| [`seed/04_verify_seed.sql`](seed/04_verify_seed.sql) | 24 checks. Every row must read `PASS` |

Order matters: 02 joins on the ingredient names from 01, and 03 on the meal
names from 02.

All three are safe to re-run. Meals are upserted on `lower(name)`, so meal ids
survive and the favourites and history that point at them survive with them.
Ingredient links are rebuilt from scratch each time, which means removing an
ingredient from a recipe here removes it from the database too.

**Household-private custom meals are never touched** by any of this. The seed
only ever writes rows where `is_public` is true.

`04_verify_seed.sql` is worth reading even when it passes. It checks the things
that make a catalogue *usable* rather than merely present: that no cuisine or
category is too thin to spin, that the quick and cheap filters land on
something, and — most importantly — that the dietary tags tell the truth.
Dietary tags are a hard filter, so a wrong one does not skew a score, it offers
someone food they will not eat.

`test/tooling/meal_seed_test.dart` asks the same questions of the files rather
than the database, and runs in CI. It is the cheaper place to find a misspelt
ingredient or a vegan meal with fish sauce in it.

## Connecting the app

**Project Settings → API**, then:

```bash
cp config/development.example.json config/development.json
```

Fill in:

| Field | Where it comes from |
| ----- | ------------------- |
| `SUPABASE_URL` | Project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key (older dashboards call this the **anon** key) |

`SUPABASE_ANON_KEY` is still accepted as a fallback, so a value copied from an
older dashboard works unchanged.

> **Never** put the `service_role` key here. It bypasses every Row Level
> Security policy. It belongs only in Edge Function secrets.

Then:

```bash
flutter run --dart-define-from-file=config/development.json
```

**The flag is not optional.** The credentials are compile-time defines, so a bare
`flutter run` starts with no backend at all: authentication falls back to an
in-memory stand-in, and an account created that way is gone on the next launch.
`.vscode/launch.json` is committed so that pressing F5 passes the flag for you,
and the app now shows a banner on the auth screens whenever it is running without
a real backend — the fallback stays, but it is no longer silent.

The app reports backend health on launch. Without credentials it logs a warning
and runs without a backend rather than crashing — a fresh clone still starts.

## Layout

```text
supabase/
├── migrations/   Source of truth, applied in filename order
├── schema.sql    All migrations concatenated, for pasting in one go
├── verify.sql    Post-apply checks — every row must read PASS
├── seed/         The meal catalogue, plus its own verification
└── tests/        Pasteable SQL that proves the schema enforces something
```

Edit the **migrations**, never `schema.sql`. Regenerate it with:

```bash
tool/build_schema.sh
```

Migrations are forward-only and are never edited once applied to staging. Apply
to development, then staging, then production, in that order.

## What the schema sets up

* 17 tables, matching the ERD in [../docs/DATABASE.md](../docs/DATABASE.md)
* Row Level Security enabled on **every** table, with 34 policies
* `handle_new_user` — provisions profile, preferences, a personal household and
  its owner membership atomically on signup, so no account can end up
  half-created
* `is_household_member` — `SECURITY DEFINER`, which is what breaks the RLS
  recursion that household policies would otherwise hit
* Indexes for the queries that run on every spin

## Auth settings to check in the dashboard

* **Authentication → Providers → Email**: enabled.
* **Authentication → Providers → Email → Confirm email**: decide deliberately.
  On (the Supabase default), sign-up returns a user and **no session** — the
  account exists but cannot be used until the emailed link is followed. The app
  handles that correctly: it shows "Check your email" and sends you back to sign
  in rather than into onboarding. Off is more convenient while developing, and
  means sign-up drops you straight into the app.
* **Authentication → URL Configuration**: add `whatscooking://reset-password`
  as a redirect URL, otherwise password reset deep links will not return to the
  app (Sprint 16).
* Google and Apple providers are configured in Sprint 18.

## Tests

Pasteable SQL that proves the schema behaves, not merely that it applied.
Each file runs inside a transaction and rolls back, so nothing is left behind.

| File | Covers | Sprint |
| ---- | ------ | ------ |
| [`tests/01_core_tables_test.sql`](tests/01_core_tables_test.sql) | Signup provisioning, constraints, uniqueness, referential integrity, `updated_at`, cascades | 12 |
| [`tests/02_rls_test.sql`](tests/02_rls_test.sql) | Row Level Security — cross-household denial, private vs shared data, anonymous access | 15 |

Run in the SQL Editor. Success ends with a `NOTICE` reading
`ALL CORE TABLE TESTS PASSED`; a failure raises immediately and names the check
that broke.

`verify.sql` answers "did the schema apply?". These answer "does it actually
enforce anything?" — a constraint that exists but does not fire is worse than
no constraint, because it is trusted.

### Applying migration 0010 to an existing database

If you already pasted `schema.sql` before migration 0010 existed, paste just
that file — [`migrations/20260820000010_grants.sql`](migrations/20260820000010_grants.sql)
— or re-paste the whole of `schema.sql`, which is safe to re-run.

It adds explicit table privileges. RLS decides which *rows* a role sees; grants
decide whether the role may touch the table at all. Relying on Supabase's
default privileges left that implicit, and the two need to line up.

The practical effect: anonymous callers keep read access to the public meal
catalogue — guest mode needs that before signup — and lose it everywhere else,
so a carelessly written future policy still cannot expose user data to an
unauthenticated key.
