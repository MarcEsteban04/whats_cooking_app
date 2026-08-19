# Supabase

## Applying the schema

1. Create a project at [supabase.com](https://supabase.com) (or reuse an existing one).
2. Open **SQL Editor → New query**.
3. Paste the whole of [`schema.sql`](schema.sql) and **Run**.
4. Paste [`verify.sql`](verify.sql) and **Run**. Every row must read `PASS`.

`schema.sql` is safe to re-run — everything is `create ... if not exists` or
`create or replace`.

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

The app reports backend health on launch. Without credentials it logs a warning
and runs without a backend rather than crashing — a fresh clone still starts.

## Layout

```text
supabase/
├── migrations/   Source of truth, applied in filename order
├── schema.sql    All migrations concatenated, for pasting in one go
├── verify.sql    Post-apply checks — every row must read PASS
└── seed/         Catalogue seed data (Sprint 21)
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
