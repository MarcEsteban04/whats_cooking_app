-- Sprint 34 — analytics events.
--
-- docs/ARCHITECTURE.md §10 names one north-star metric, Time to Decision, and
-- risk 14 says why this table cannot wait: "Analytics from build one. Cannot be
-- measured retroactively." Every day without it is a day of dinners whose timing
-- is gone. It is deliberately the plainest possible shape — a name, a JSON blob
-- and a timestamp — because the alternative is a column per property and a
-- migration per event, and that is the friction that stops events being added.
--
-- No PII, no meal names. `properties` carries ids, counts, durations and flags;
-- the client enforces this in its event types and asserts it again before
-- writing (lib/core/analytics/).

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),

  -- Defaulted rather than sent. The client omits it, the insert policy checks the
  -- same expression, and so there is no way for the row's owner to disagree with
  -- the session that wrote it.
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,

  name text not null,
  properties jsonb not null default '{}'::jsonb,

  -- When it happened on the device, which is not when it arrived. Events are
  -- batched, so the two differ by up to the flush interval — and by an entire
  -- offline stretch when the connection has been away. Time to Decision is a
  -- difference between two of these, so the device's clock is the only one that
  -- can answer it.
  occurred_at timestamptz not null,

  -- When the row landed. Kept alongside rather than instead: the gap between the
  -- two is how you tell a slow network from a slow decision.
  created_at timestamptz not null default now(),

  constraint analytics_events_name_not_blank check (length(trim(name)) > 0),

  -- A blob, not a list. `properties` is addressed by key everywhere it is read,
  -- and a JSON array here would break every one of those reads silently.
  constraint analytics_events_properties_object check (jsonb_typeof(properties) = 'object')
);

comment on table public.analytics_events is
  'Product analytics (ARCHITECTURE §10). Append-only. No PII, no meal names — ids only.';

-- The query this table exists for: Time to Decision over a period, which reads
-- one event name in timestamp order.
create index if not exists analytics_events_name_occurred_idx
  on public.analytics_events (name, occurred_at desc);

-- And the per-household follow-up — "what did this user's sessions look like" —
-- which is how a bad number gets explained rather than just observed.
create index if not exists analytics_events_user_occurred_idx
  on public.analytics_events (user_id, occurred_at desc);

alter table public.analytics_events enable row level security;

-- Insert only, and only your own.
--
-- `with check` rather than a trigger: the default fills `user_id` in and this
-- refuses the row if anything else got in there, so a client cannot attribute an
-- event to somebody else even by sending the column explicitly.
drop policy if exists "users write their own events" on public.analytics_events;
create policy "users write their own events"
  on public.analytics_events
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Readable by its owner, and by nobody else.
--
-- Not for the app — no screen reads this table, and none should. It is here so
-- that "show me everything you hold about me" and "delete it" are answerable
-- without a service-role key, which is the difference between a privacy promise
-- and a privacy intention.
drop policy if exists "users read their own events" on public.analytics_events;
create policy "users read their own events"
  on public.analytics_events
  for select
  to authenticated
  using (user_id = auth.uid());

-- No update policy, and no delete policy for the owner either.
--
-- Append-only on purpose: an event that can be edited after the fact is not a
-- measurement. Erasure happens through the `on delete cascade` above when the
-- account goes, which is the only erasure the metric has to survive.
