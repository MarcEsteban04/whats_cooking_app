#!/usr/bin/env bash
# Pushes the Edge Functions and their secrets to the linked Supabase project.
#
# Reads .env.local — which is git-ignored and already holds every credential
# this needs. Nothing here prints a secret: the keys go to the CLI through a
# temporary env file rather than the command line, because arguments are visible
# in the process list to anything else running on the machine.
#
# Usage, from the repository root:
#   bash supabase/tool/deploy_functions.sh
#
# Requires SUPABASE_ACCESS_TOKEN in .env.local — a personal access token from
# https://supabase.com/dashboard/account/tokens. It is *not* any of the project
# keys: those authenticate a client to a project, and this authenticates you to
# the account that owns it. Alternatively run `npx supabase@latest login` once
# and the CLI caches its own.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
env_file="$root/.env.local"
cli=(npx --yes supabase@latest)

if [[ ! -f "$env_file" ]]; then
  echo "No .env.local at $env_file — see supabase/README.md." >&2
  exit 1
fi

# Sourced rather than parsed line by line so quoting works the way anyone
# editing the file would expect.
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL is not set in .env.local." >&2
  exit 1
fi

# The project ref is the subdomain: https://<ref>.supabase.co
ref="${SUPABASE_URL#*://}"
ref="${ref%%.*}"

if [[ -z "$ref" ]]; then
  echo "Could not read a project ref out of SUPABASE_URL." >&2
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]] && [[ ! -f "$HOME/.supabase/access-token" ]]; then
  cat >&2 <<'MISSING'
No Supabase access token.

Either add one line to .env.local:

    SUPABASE_ACCESS_TOKEN=sbp_...

from https://supabase.com/dashboard/account/tokens — or run
`npx supabase@latest login` once and the CLI will keep its own.

This is an account-level token, not a project key. None of the four
SUPABASE_* values already in .env.local can deploy a function.
MISSING
  exit 1
fi

# --- Secrets -----------------------------------------------------------------
#
# Written to a temporary file with owner-only permissions and passed by path.
# Only the AI keys go across: names beginning with SUPABASE_ are reserved by the
# platform and injected into every function automatically, so sending them would
# be rejected — and sending the service-role key by hand would be a mistake
# waiting to be made.
secrets_file="$(mktemp)"
chmod 600 "$secrets_file"
trap 'rm -f "$secrets_file"' EXIT

written=0
for name in GROQ_AI_API_KEY GEMINI_AI_API_KEY OPENAI_API_KEY \
            GROQ_MODEL GEMINI_MODEL OPENAI_MODEL; do
  value="${!name:-}"
  if [[ -n "$value" ]]; then
    printf '%s=%s\n' "$name" "$value" >> "$secrets_file"
    # The name, never the value.
    echo "  will set $name"
    written=$((written + 1))
  fi
done

if (( written == 0 )); then
  echo "No AI keys found in .env.local — nothing to set." >&2
  exit 1
fi

echo "Setting $written secret(s) on project $ref…"
"${cli[@]}" secrets set --project-ref "$ref" --env-file "$secrets_file"

# --- Functions ---------------------------------------------------------------
#
# `_shared/` is picked up automatically: the CLI follows the relative imports out
# of each function's entry point.
for function in ai-assistant; do
  echo "Deploying $function…"
  "${cli[@]}" functions deploy "$function" --project-ref "$ref"
done

echo
echo "Done. Check it with the curl in supabase/README.md, then:"
echo "  select provider, attempts, latency_ms, succeeded from ai_usage"
echo "  order by created_at desc limit 10;"
