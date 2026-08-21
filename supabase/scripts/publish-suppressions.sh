#!/bin/sh
# Publish the kill-switch document to Storage (`AD-5`, `c2` blocker B7).
#
# `publish-suppressions` is `verify_jwt = true` and reads the `role` claim off the bearer, so the
# service role is the only caller that can do anything with it. That key bypasses RLS entirely and
# never enters the app — this script is the operator side, run by a person from a shell.
#
#   cp .env.example .env.local     # then paste the key into SUPABASE_SERVICE_ROLE_KEY
#   sh supabase/scripts/publish-suppressions.sh
#
# The key is read from the environment and never echoed. Pass --local to drive `supabase start`
# instead of the deployed project, using the well-known development key.
set -eu

ENV_FILE="${ENV_FILE:-.env.local}"

if [ "${1:-}" = "--local" ]; then
  URL="http://127.0.0.1:54321"
  # The development service role, identical on every machine. Public by construction.
  KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
else
  if [ ! -f "$ENV_FILE" ]; then
    echo "No $ENV_FILE. Copy .env.example to it and fill in SUPABASE_SERVICE_ROLE_KEY." >&2
    exit 2
  fi
  # shellcheck disable=SC1090
  . "./$ENV_FILE"
  URL="${SUPABASE_URL:-}"
  KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
  if [ -z "$URL" ] || [ -z "$KEY" ]; then
    echo "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is empty in $ENV_FILE." >&2
    exit 2
  fi
fi

status=$(curl -sS -o /tmp/publish-suppressions.out -w "%{http_code}" \
  -X POST "$URL/functions/v1/publish-suppressions" \
  -H "Authorization: Bearer $KEY")

echo "publish-suppressions -> $status"
cat /tmp/publish-suppressions.out
echo
rm -f /tmp/publish-suppressions.out

if [ "$status" != "200" ]; then
  # A 403 here is the function refusing the bearer, not a network problem: it reads the `role`
  # claim rather than comparing strings, so a publishable key or a user token lands here.
  exit 1
fi

echo
echo "Published document, as the app will read it:"
curl -sS "$URL/storage/v1/object/public/content/suppressions.json"
echo
