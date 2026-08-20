// Request plumbing shared by every function: CORS, auth, and rate limiting.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

/**
 * Permissive on origin, restrictive on everything else.
 *
 * The caller is a mobile app, which sends no meaningful `Origin`, so restricting
 * it would buy nothing and break local testing from a browser. What actually
 * protects this function is the JWT check below — not a header the caller
 * chooses.
 */
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * An error the client is allowed to see.
 *
 * `code` is for the app to branch on; `message` is written for a person, because
 * it is what they will read. Provider names, HTTP statuses and prompt fragments
 * stay in the logs — docs/CODING_STANDARDS.md's rule that technical exception
 * text never reaches a user applies across the wire too.
 */
export function failure(
  code: string,
  message: string,
  status: number,
): Response {
  return json({ code, message }, status);
}

/**
 * The signed-in user, verified from the token rather than taken on trust.
 *
 * docs/ARCHITECTURE.md §6.4: "Never trust a client-supplied user ID — read it
 * from the verified token." The body of the request is not consulted for
 * identity, at all, for any reason.
 */
export async function authenticate(
  request: Request,
): Promise<{ userId: string; admin: SupabaseClient } | Response> {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return failure("unauthenticated", "Please sign in again.", 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !anonKey || !serviceKey) {
    console.error("[ai] Function environment is missing Supabase credentials.");
    return failure("misconfigured", "This feature is not available yet.", 503);
  }

  // Two clients on purpose. The caller's token is used *only* to establish who
  // they are; every subsequent read and write uses the service role, so a
  // rate-limit row cannot be hidden from us by a policy the caller controls.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data, error } = await asCaller.auth.getUser();
  if (error || !data.user) {
    return failure("unauthenticated", "Please sign in again.", 401);
  }

  return {
    userId: data.user.id,
    admin: createClient(url, serviceKey, {
      auth: { persistSession: false },
    }),
  };
}

/** How many AI requests one person may make per window. */
const RATE_LIMIT = 20;
const RATE_WINDOW_MINUTES = 60;

/**
 * Whether this user has room for another request.
 *
 * A count of recent `ai_usage` rows rather than a counter, because the rows have
 * to exist anyway for cost attribution and two sources of truth would disagree.
 * It counts *attempts*, not successes: a failed request still cost three
 * provider calls, and a limit that only counted successes could be spent
 * indefinitely by a client retrying a bad prompt.
 *
 * **Fails open.** If the count cannot be read, the request proceeds. A rate
 * limiter that takes the feature down when its own bookkeeping is unavailable
 * has turned a cost control into an outage.
 */
export async function withinRateLimit(
  admin: SupabaseClient,
  userId: string,
): Promise<{ allowed: boolean; retryAfterMinutes: number }> {
  const since = new Date(
    Date.now() - RATE_WINDOW_MINUTES * 60 * 1000,
  ).toISOString();

  const { count, error } = await admin
    .from("ai_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", since);

  if (error) {
    console.warn(`[ai] Rate-limit read failed, allowing: ${error.message}`);
    return { allowed: true, retryAfterMinutes: 0 };
  }

  return {
    allowed: (count ?? 0) < RATE_LIMIT,
    retryAfterMinutes: RATE_WINDOW_MINUTES,
  };
}

/**
 * Records what happened, whether or not it worked.
 *
 * Awaited rather than fired and forgotten: the row is the rate limit, so a
 * request that returns before its row lands is a request that did not count.
 * A failure to write is logged and swallowed — losing a usage row is not worth
 * failing a reply the user is already reading.
 */
export async function recordUsage(
  admin: SupabaseClient,
  row: {
    user_id: string;
    provider: string;
    model: string;
    purpose: string;
    prompt_tokens: number | null;
    completion_tokens: number | null;
    latency_ms: number;
    succeeded: boolean;
    error: string | null;
    attempts: number;
  },
): Promise<void> {
  const { error } = await admin.from("ai_usage").insert(row);
  if (error) {
    console.warn(`[ai] Usage write failed: ${error.message}`);
  }
}
