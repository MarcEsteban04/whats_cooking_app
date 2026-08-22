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
bash supabase/tool/build_schema.sh
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

---

## Edge Functions

### `ai-assistant` — the AI proxy

The one thing this function exists for is that **the Flutter app must never hold
an AI provider key**. Everything else it does follows from being the only place
that can be trusted with one:

* verifies the caller's JWT and reads the user id *from the token*, never from
  the body;
* rate limits each user (20 requests an hour) by counting rows in `ai_usage`;
* tries **three providers in order** — Groq, then Gemini, then OpenAI — giving
  each one 12 seconds before falling over to the next;
* writes one `ai_usage` row per request, successful or not, which is both the
  rate limit and the cost record;
* returns a message written for a person, never a provider's error text.

Groq is first because it is by a distance the fastest, and this sits in front of
somebody deciding what to have for dinner. Gemini is second on cost. OpenAI is
last because it is the most likely to be up when the other two are not, which is
what you want from a last resort rather than a first choice.

Migration 0017 creates `ai_usage`. Apply it before deploying.

### AI keys

The three keys live in the function's environment and nowhere else. They are
**not** app config: `AppEnv.assertNoProviderKey()` throws on the first frame if
one is ever compiled into the client, because the mistake is easy — the keys sit
in the same `.env.local` as the Supabase ones — and nothing downstream would
notice. The assistant would work, and the build would ship with three billable
credentials in it.

One command, from the repository root:

```bash
bash supabase/tool/deploy_functions.sh
```

It reads `.env.local`, works the project ref out of `SUPABASE_URL`, sets the
secrets and deploys. The keys reach the CLI through a temporary owner-only file
rather than the command line, because arguments are visible in the process list
to anything else running on the machine. It prints the *names* it is setting and
never a value.

It needs one thing that is not a project key: a **personal access token**, from
<https://supabase.com/dashboard/account/tokens>, added to `.env.local` as
`SUPABASE_ACCESS_TOKEN`. The four `SUPABASE_*` values already there authenticate
a *client* to a *project*; deploying a function authenticates *you* to the
account that owns it, which is a different thing and deliberately not something a
project key can do. `npx supabase@latest login` caches an equivalent token if you
would rather not keep one in the file.

By hand, if you prefer — the ref is the subdomain of your `SUPABASE_URL`:

```bash
npx supabase@latest secrets set --project-ref YOUR_REF \
  GROQ_AI_API_KEY=... GEMINI_AI_API_KEY=... OPENAI_API_KEY=...

npx supabase@latest functions deploy ai-assistant --project-ref YOUR_REF
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
into functions automatically — do not set them by hand.

At least one key is enough. Providers with no key are skipped silently rather
than counted as failures, so running on one key is a supported state and does not
look like an outage in `ai_usage`.

Model identifiers get retired on a schedule nobody announces, so each is
overridable without touching the code:

| Variable | Default |
| -------- | ------- |
| `GROQ_MODEL` | `llama-3.3-70b-versatile` |
| `GEMINI_MODEL` | `gemini-2.0-flash` |
| `OPENAI_MODEL` | `gpt-4o-mini` |

#### Vision (Sprint 49)

Reading a fridge photo needs a model that can see, and `GROQ_MODEL`'s default
cannot — so vision gets its own variable per provider rather than reusing the
text one. That also means vision can be turned off per provider by setting the
variable to an empty string: a provider with no vision model is **skipped** for
image requests instead of being sent a picture it will reject with a 400, which
does not fail over.

| Variable | Default |
| -------- | ------- |
| `GROQ_VISION_MODEL` | `meta-llama/llama-4-scout-17b-16e-instruct` |
| `GEMINI_VISION_MODEL` | `gemini-2.0-flash` |
| `OPENAI_VISION_MODEL` | `gpt-4o-mini` |

**A PDF narrows it further** (Sprint 53). Of the three, only Gemini takes a
document inline through the same `inline_data` part an image uses; OpenAI wants
its Files API and Groq takes none. So a non-image attachment is offered to Gemini
alone — a provider that cannot read it answers `400`, and a `400` deliberately
does not fail over, so guessing wrong would end the request rather than move it
along. **Without a Gemini key, importing a grocery list from a PDF fails and
photos and `.txt` still work.**

### The order, and the one switch worth knowing

| Request | Order |
| ------- | ----- |
| Text | Groq → Gemini → OpenAI |
| Image | Gemini → Groq → OpenAI |
| PDF | Gemini only |

**Groq and Gemini are the two that work; OpenAI is the paid backup** and is last
in every ordering. It answers when the other two are rate-limited or down, which
is what a last resort is for.

The chain fails over on **errors, not on bad answers**, and that matters in one
place: Groq's vision model is genuinely weak at OCR — it read six lines off a
twenty-seven line shopping list, succeeded, and nothing failed over. So with
Gemini unavailable, a photo import can come back short rather than reaching
OpenAI.

The switch for that is `GROQ_VISION_MODEL=""`. An empty value skips Groq for
anything carrying a file, making image requests Gemini → OpenAI, while leaving
Groq first for every text request. Reach for it if short imports come back.

The photo is forwarded and never stored — no bucket, no row, no log line. The
function caps it at 1.5 MB of base64 (`413 image_too_large`); the app downscales
to 1280 px before sending, so that ceiling is a guard against a bad client rather
than a limit anybody meets.

### Checking it works

Deployed functions need a real user token, so the quickest check is from a signed
in session. Grab the access token from the app's logs in a verbose build, then:

```bash
curl -i -X POST \
  "$SUPABASE_URL/functions/v1/ai-assistant" \
  -H "Authorization: Bearer $USER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"purpose":"assistant","messages":[{"role":"user","content":"We have chicken and eggs and about 200 pesos. What should we cook?"}]}'
```

A healthy reply names the provider that answered:

```json
{ "text": "...", "provider": "groq", "model": "llama-3.3-70b-versatile" }
```

To see the failover working, unset the first key and call it again — `provider`
should come back as `gemini`. `select provider, attempts, latency_ms, succeeded
from ai_usage order by created_at desc limit 10;` shows what actually happened,
including the attempts that failed.

Expected failures, and what they mean:

| Code | Status | Meaning |
| ---- | -----: | ------- |
| `unauthenticated` | 401 | No token, or an expired one |
| `rate_limited` | 429 | 20 requests inside the hour |
| `misconfigured` | 503 | No provider key set on the function |
| `unavailable` | 503 | Every configured provider failed |
