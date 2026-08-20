#!/usr/bin/env bash
# Asks the deployed `ai-assistant` function a question, as you.
#
# The function refuses anything that is not a signed-in user's token — which is
# correct, and it means there is no way to try the assistant from a terminal
# without one. This gets one the same way the app does: email and password
# against Supabase Auth.
#
# It exists because Sprint 59 shipped the AI infrastructure with no screen in
# front of it (the assistant is Sprint 60), and infrastructure nobody can try is
# infrastructure nobody trusts.
#
# Usage, from the repository root:
#   bash supabase/tool/ask_ai.sh
#   bash supabase/tool/ask_ai.sh "We have chicken and 200 pesos. What now?"
#
# Nothing is echoed: the password is read silently and the token never reaches
# the terminal or the shell history.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
env_file="$root/.env.local"

if [[ ! -f "$env_file" ]]; then
  echo "No .env.local at $env_file — see supabase/README.md." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

# Either spelling, matching how the app reads it (AppEnv.supabaseKey).
anon="${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_PUBLISHABE_KEY:-${SUPABASE_ANON_PUBLIC:-${SUPABASE_ANON_KEY:-}}}}"

if [[ -z "${SUPABASE_URL:-}" || -z "$anon" ]]; then
  echo "SUPABASE_URL or the anon key is missing from .env.local." >&2
  exit 1
fi

question="${1:-What should we eat tonight? We have about 200 pesos a head and 30 minutes.}"

read -r -p "Email: " email
# Silent, and no trailing newline of its own — hence the echo after.
read -r -s -p "Password: " password
echo

echo "Signing in…"
auth_response="$(
  curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $anon" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"email":%s,"password":%s}' \
          "$(printf '%s' "$email" | sed 's/"/\\"/g; s/^/"/; s/$/"/')" \
          "$(printf '%s' "$password" | sed 's/"/\\"/g; s/^/"/; s/$/"/')")"
)"
unset password

# `jq` is not a dependency of this repo, so this is deliberately crude — and it
# never prints what it extracts.
token="$(printf '%s' "$auth_response" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"

if [[ -z "$token" ]]; then
  echo "Sign-in failed. Supabase said:" >&2
  # Safe to show: a failed auth response carries an error code, not a token.
  printf '%s\n' "$auth_response" >&2
  exit 1
fi

echo "Asking the assistant…"
echo
curl -s -X POST "$SUPABASE_URL/functions/v1/ai-assistant" \
  -H "Authorization: Bearer $token" \
  -H "apikey: $anon" \
  -H "Content-Type: application/json" \
  -d "$(printf '{"purpose":"assistant","messages":[{"role":"user","content":%s}]}' \
        "$(printf '%s' "$question" | sed 's/"/\\"/g; s/^/"/; s/$/"/')")"
echo
echo
echo "The \"provider\" field is which of the three answered. Then:"
echo "  select provider, attempts, latency_ms, succeeded, error"
echo "  from ai_usage order by created_at desc limit 5;"
