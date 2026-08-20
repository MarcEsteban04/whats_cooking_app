-- ---------------------------------------------------------------------------
-- 0017 · AI usage, for rate limiting and cost visibility
-- See docs/ARCHITECTURE.md §6.4. Sprint 59.
-- ---------------------------------------------------------------------------

-- Sprint 59 asks for rate limiting and usage tracking, and one table answers
-- both: a rate limit is a count of recent rows, and a bill is a sum of older
-- ones. Two tables would have to agree with each other.
--
-- Written only by the `ai-assistant` Edge Function under the service role, which
-- is why there is no insert policy for `authenticated` below. A client that could
-- write here could erase its own rate limit.
create table if not exists ai_usage (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,

  -- Which of the three providers actually answered. The point of recording it is
  -- the failover: if Groq is timing out every evening, this is the only place
  -- that would show it before the bill did.
  provider      text not null check (provider in ('groq', 'gemini', 'openai')),
  model         text not null,

  -- What the request was for, so a spike can be attributed to a feature rather
  -- than to "AI". Sprints 60-63 each add one.
  purpose       text not null check (
    purpose in ('assistant', 'recipe', 'fridge_scan', 'personalise')
  ),

  -- Null when the provider never answered. Kept as a row anyway: a failed
  -- request still costs latency and still counts against a rate limit, and a
  -- table that only records successes cannot explain a bad evening.
  prompt_tokens     integer check (prompt_tokens is null or prompt_tokens >= 0),
  completion_tokens integer check (
    completion_tokens is null or completion_tokens >= 0
  ),

  -- How long the whole call took, including providers that failed first.
  latency_ms    integer not null check (latency_ms >= 0),

  -- False when every provider failed. `error` carries the last reason, for us
  -- rather than for the user — the user got a written message from the app.
  succeeded     boolean not null default true,
  error         text,

  -- How many providers were tried. Anything above 1 is a failover that happened,
  -- which is the number worth watching.
  attempts      smallint not null default 1 check (attempts between 1 and 3),

  created_at    timestamptz not null default now()
);

-- The rate-limit query: this user's rows since a cut-off. Descending, because
-- every read of this table is about the recent end of it.
create index if not exists ai_usage_user_recent_idx
  on ai_usage (user_id, created_at desc);

alter table ai_usage enable row level security;

-- Read your own, and nothing else. Not household-wide: an AI conversation is
-- one person's, and the same reasoning that keeps dislikes private applies here
-- with more force (docs/DATABASE.md §4.9).
drop policy if exists "read own ai usage" on ai_usage;
create policy "read own ai usage" on ai_usage
  for select using (user_id = auth.uid());

-- Deliberately no insert, update or delete policy for `authenticated`. The Edge
-- Function writes with the service role, which bypasses RLS; a client that could
-- insert here could pad its own history, and one that could delete could reset
-- its rate limit whenever it hit the ceiling.
revoke insert, update, delete on ai_usage from authenticated;

comment on table ai_usage is
  'One row per AI request, written only by the ai-assistant Edge Function. Serves rate limiting (recent count) and cost attribution (token sums).';
