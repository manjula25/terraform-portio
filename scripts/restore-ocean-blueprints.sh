#!/usr/bin/env bash
# Recreates the Ocean default blueprints deleted by prune-ocean-blueprints.sh,
# from the backup that prune took first.
#
# THIS REVERSES FR-005. Restoring these blueprints puts undeclared types back
# in the catalog, which is exactly what FR-005 forbids. Run it only as a
# deliberate rollback, and record why.
#
# WHAT IT CANNOT RESTORE: the 33 entities. Those were catalog data written by
# the integration, not configuration. `evidence/fr-005-pre-prune-entities.json`
# records their identifiers for audit, but the way to get entities back is a
# sync, not this script.
#
# Two passes, and the order matters:
#   1. Create every blueprint with its own schema ONLY — no relations, and no
#      mirrorProperties or aggregationProperties either. All three depend on
#      other blueprints: a relation names a target, and mirror/aggregation
#      properties resolve THROUGH a relation ("service.$title",
#      "workflow.result"). Half these blueprints target each other, so anything
#      relation-shaped fails on whichever is created first.
#   2. PATCH relations, then mirror and aggregation properties, once every
#      target exists. Relations must land before the properties that traverse
#      them, so pass 2 does relations first and properties second.
#
# Usage:
#   ./scripts/restore-ocean-blueprints.sh            # dry run
#   ./scripts/restore-ocean-blueprints.sh --apply    # recreate

set -uo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

BASE="${PORT_BASE_URL:-https://api.port.io}"
: "${PORT_CLIENT_ID:?set PORT_CLIENT_ID}"
: "${PORT_CLIENT_SECRET:?set PORT_CLIENT_SECRET}"

cd "$(dirname "$0")/.." || exit 1
BACKUP="docs/work/PHASE2/evidence/fr-005-pre-prune-backup.json"
[ -f "$BACKUP" ] || { echo "backup not found: $BACKUP"; exit 1; }
command -v jq > /dev/null || { echo "jq required"; exit 1; }

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m     %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m   %-28s %s\n' "$1" "$2"; }
note() { printf '  %s\n' "$1"; }

TOKEN="$(curl -s --max-time 30 -X POST "$BASE/v1/auth/access_token" \
  -H 'Content-Type: application/json' \
  -d "{\"clientId\":\"$PORT_CLIENT_ID\",\"clientSecret\":\"$PORT_CLIENT_SECRET\"}" \
  | jq -r '.accessToken // empty' | tr -d '\n\r')"
[ -n "$TOKEN" ] || { echo "auth failed against $BASE"; exit 1; }
AUTH=(-H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json')

# The ten this repository declares. Never restored — they already exist and are
# Terraform's to own; POSTing over them would be a second writer.
OURS='["agent","ai_usage","environment","ingestion_source","mcp_server","project","pull_request","repository","service","skill"]'

CANDS="$(jq -r --argjson ours "$OURS" '
  [.blueprints[]
   | select((.identifier | startswith("_")) | not)
   | select(.identifier as $i | $ours | index($i) | not)
   | .identifier] | sort | .[]' "$BACKUP")"

N="$(printf '%s\n' $CANDS | wc -w | tr -d ' ')"
say "To recreate from $BACKUP ($N)"
printf '  %s\n' "$(printf '%s ' $CANDS)"

say "This reverses FR-005"
note "Those $N blueprints are not declared in modules/. Putting them back means"
note "the catalog again contains integration-created types, which FR-005 forbids."
note "The 33 deleted entities are NOT restored by this — only a sync creates entities."

if [ "$APPLY" -eq 0 ]; then
  say "Dry run"
  note "Nothing was changed. Re-run with --apply to recreate."
  exit 0
fi

# --- pass 1: schema only -----------------------------------------------------
# calculationProperties are kept: they are self-contained jq over the
# blueprint's own properties. mirror/aggregation/relations are all deferred.
say "Pass 1 — creating blueprints, schema only"
for b in $CANDS; do
  body="$(jq -c --arg id "$b" '
    .blueprints[] | select(.identifier == $id)
    | { identifier, title, icon, schema, calculationProperties }
    | with_entries(select(.value != null))
    | .relations = {}
    | .mirrorProperties = {}
    | .aggregationProperties = {}' "$BACKUP")"
  [ -n "$body" ] || { bad "$b" "not in backup"; continue; }

  out="$(mktemp)"
  code="$(curl -s -o "$out" -w '%{http_code}' --max-time 30 \
          -X POST "$BASE/v1/blueprints" "${AUTH[@]}" -d "$body")"
  case "$code" in
    200|201|409) ok "$b" ;;
    *) bad "$b" "$(jq -r '.message // .error // empty' "$out" 2>/dev/null || echo "http $code")" ;;
  esac
  rm -f "$out"
done

# --- pass 2a: relations ------------------------------------------------------
say "Pass 2a — attaching relations now that every target exists"
for b in $CANDS; do
  rels="$(jq -c --arg id "$b" '
    .blueprints[] | select(.identifier == $id) | .relations // {}' "$BACKUP")"
  [ -n "$rels" ] && [ "$rels" != "{}" ] || continue

  out="$(mktemp)"
  code="$(curl -s -o "$out" -w '%{http_code}' --max-time 30 \
          -X PATCH "$BASE/v1/blueprints/$b" "${AUTH[@]}" \
          -d "{\"relations\":$rels}")"
  case "$code" in
    200|201) ok "$b — $(printf '%s' "$rels" | jq -r 'keys|length') relations" ;;
    *) bad "$b" "$(jq -r '.message // .error // empty' "$out" 2>/dev/null || echo "http $code")" ;;
  esac
  rm -f "$out"
done

# --- pass 2b: mirror and aggregation properties ------------------------------
# These traverse relations, so they can only be set after pass 2a.
say "Pass 2b — mirror and aggregation properties"
for b in $CANDS; do
  props="$(jq -c --arg id "$b" '
    .blueprints[] | select(.identifier == $id)
    | { mirrorProperties: (.mirrorProperties // {}),
        aggregationProperties: (.aggregationProperties // {}) }
    | with_entries(select(.value != {}))' "$BACKUP")"
  [ -n "$props" ] && [ "$props" != "{}" ] || continue

  out="$(mktemp)"
  code="$(curl -s -o "$out" -w '%{http_code}' --max-time 30 \
          -X PATCH "$BASE/v1/blueprints/$b" "${AUTH[@]}" -d "$props")"
  case "$code" in
    200|201) ok "$b — $(printf '%s' "$props" | jq -r '[.[]|keys|length]|add') properties" ;;
    *) bad "$b" "$(jq -r '.message // .error // empty' "$out" 2>/dev/null || echo "http $code")" ;;
  esac
  rm -f "$out"
done

# --- verify ------------------------------------------------------------------
say "Result"
LEFT="$(curl -s --max-time 30 "$BASE/v1/blueprints" "${AUTH[@]}" \
  | jq -r '[.blueprints[].identifier] | length')"
note "blueprints in tenant: $LEFT"
missing=""
for b in $CANDS; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$BASE/v1/blueprints/$b" "${AUTH[@]}")"
  [ "$code" = "200" ] || missing="$missing $b"
done
if [ -z "$(printf '%s' "$missing" | tr -d '[:space:]')" ]; then
  printf '  \033[32mall %s recreated\033[0m\n' "$N"
else
  printf '  \033[31mnot recreated:\033[0m%s\n' "$missing"
  exit 1
fi
printf '\n  \033[33mFR-005 now FAILS again, by design. Record why in the work notes.\033[0m\n'
