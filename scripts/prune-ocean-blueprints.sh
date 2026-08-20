#!/usr/bin/env bash
# Deletes Ocean default-resource blueprints so FR-005 can pass.
#
# FR-005: "the organization's blueprint list contains no integration-created
# type ... and every blueprint present is declared in modules/."
#
# WHY A SCRIPT AND NOT TERRAFORM: nothing in this repository declares these
# blueprints, so `terraform destroy` cannot reach them. Ocean created them at
# integration install time. Removing them is a deliberate one-off tenant
# repair, not configuration — which is also why it lives in scripts/ and is
# not wired into verify.sh.
#
# SAFETY, in the order the checks run:
#   1. Three-way classification. Port SYSTEM blueprints (leading underscore:
#      _team, _user, _scorecard, ...) are never candidates. OUR blueprints,
#      declared in modules/core-blueprints/, are never candidates. The rest are.
#   2. OURS is derived from `terraform state list` plus the identifiers in
#      modules/core-blueprints/main.tf — never a hardcoded list, so this cannot
#      drift away from what the repository actually owns. If that derivation
#      yields nothing, the script refuses to run rather than treating
#      everything as deletable.
#   3. Deleting a blueprint DELETES ITS ENTITIES. Counted per blueprint and
#      totalled before anything is touched.
#   4. Dry run is the default. Deletion requires --apply.
#
# Usage:
#   ./scripts/prune-ocean-blueprints.sh            # dry run, changes nothing
#   ./scripts/prune-ocean-blueprints.sh --apply    # actually delete
#
# Requires PORT_CLIENT_ID / PORT_CLIENT_SECRET in the environment.

set -uo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

BASE="${PORT_BASE_URL:-https://api.port.io}"
: "${PORT_CLIENT_ID:?set PORT_CLIENT_ID}"
: "${PORT_CLIENT_SECRET:?set PORT_CLIENT_SECRET}"

cd "$(dirname "$0")/.." || exit 1
command -v jq > /dev/null || { echo "jq required"; exit 1; }

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
keep() { printf '  \033[36mKEEP\033[0m   %-28s %s\n' "$1" "$2"; }
del()  { printf '  \033[31mDELETE\033[0m %-28s %s\n' "$1" "$2"; }
ok()   { printf '  \033[32mok\033[0m     %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m   %-28s %s\n' "$1" "$2"; }

TOKEN="$(curl -s --max-time 30 -X POST "$BASE/v1/auth/access_token" \
  -H 'Content-Type: application/json' \
  -d "{\"clientId\":\"$PORT_CLIENT_ID\",\"clientSecret\":\"$PORT_CLIENT_SECRET\"}" \
  | jq -r '.accessToken // empty' | tr -d '\n\r')"
[ -n "$TOKEN" ] || { echo "auth failed against $BASE"; exit 1; }
AUTH=(-H "Authorization: Bearer $TOKEN")

# --- what this repository owns, derived rather than hardcoded ----------------
# terraform state list gives resource NAMES (module.core_blueprints.
# port_blueprint.pull_request); the Port identifier is what the resource
# declares. Map one to the other through modules/core-blueprints/main.tf.
STATE_NAMES="$(
  for stack in organization projects/mayo-pilot; do
    ( cd "$stack" 2>/dev/null && terraform state list 2>/dev/null ) \
      | sed -n 's/.*port_blueprint\.\([A-Za-z0-9_]*\)$/\1/p'
  done | sort -u
)"

OURS="$(
  for n in $STATE_NAMES; do
    awk -v want="$n" '
      $1=="resource" && $2=="\"port_blueprint\"" {
        name=$3; gsub(/"/,"",name); inblock=(name==want); next
      }
      inblock && /identifier[[:space:]]*=/ {
        line=$0
        sub(/.*identifier[[:space:]]*=[[:space:]]*"/,"",line)
        sub(/".*/,"",line)
        print line; inblock=0
      }
    ' modules/core-blueprints/main.tf
  done | sort -u
)"

if [ -z "$(printf '%s' "$OURS" | tr -d '[:space:]')" ]; then
  echo "could not determine which blueprints this repository owns — refusing to run"
  echo "(is terraform initialised in organization/ and projects/mayo-pilot/?)"
  exit 1
fi

say "Declared in this repository ($(printf '%s\n' $OURS | wc -w | tr -d ' '))"
printf '  %s\n' "$(printf '%s ' $OURS)"

ALL="$(curl -s --max-time 30 "$BASE/v1/blueprints" "${AUTH[@]}" \
  | jq -r '.blueprints[].identifier' | sort)"
[ -n "$ALL" ] || { echo "could not list blueprints"; exit 1; }

say "Classification"
CANDIDATES=""
SYS=0
for b in $ALL; do
  case "$b" in
    _*) SYS=$(( SYS + 1 )); continue ;;
  esac
  if printf '%s\n' $OURS | grep -qx "$b"; then
    keep "$b" "declared in modules/"
  else
    CANDIDATES="$CANDIDATES $b"
  fi
done
printf '  %-35s %s\n' "(Port system blueprints skipped)" "$SYS"

N_CAND="$(printf '%s\n' $CANDIDATES | wc -w | tr -d ' ')"
if [ "$N_CAND" -eq 0 ]; then
  say "Nothing to do — FR-005 already satisfied"
  exit 0
fi

say "To delete ($N_CAND), with the entities that go with them"
TOTAL_ENT=0
for b in $CANDIDATES; do
  n="$(curl -s --max-time 20 "$BASE/v1/blueprints/$b/entities" "${AUTH[@]}" \
       | jq -r '[.entities[]?] | length')"
  n="${n:-0}"
  TOTAL_ENT=$(( TOTAL_ENT + n ))
  del "$b" "$n entities"
done
printf '\n  %s entities will be deleted in total. This is not reversible.\n' "$TOTAL_ENT"

if [ "$APPLY" -eq 0 ]; then
  say "Dry run"
  echo "  Nothing was changed. Re-run with --apply to delete."
  exit 0
fi

# --- deletion, leaves first --------------------------------------------------
# These blueprints relate to one another, and Port refuses to delete a target
# another blueprint still points at. Instead of topologically sorting, retry in
# passes: each pass deletes whatever has become a leaf. Terminates when a pass
# makes no progress.
say "Deleting — repeated passes, leaves first"
remaining="$CANDIDATES"
pass=1
while [ -n "$(printf '%s' "$remaining" | tr -d '[:space:]')" ]; do
  printf '\n  pass %s\n' "$pass"
  progressed=0
  still=""
  for b in $remaining; do
    body="$(mktemp)"
    code="$(curl -s -o "$body" -w '%{http_code}' --max-time 30 \
            -X DELETE "$BASE/v1/blueprints/$b" "${AUTH[@]}")"
    case "$code" in
      200|202|204|404) ok "$b"; progressed=1 ;;
      *)  still="$still $b"
          bad "$b" "$(jq -r '.message // .error // empty' "$body" 2>/dev/null || echo "http $code")" ;;
    esac
    rm -f "$body"
  done
  remaining="$still"
  [ "$progressed" -eq 1 ] || break
  pass=$(( pass + 1 ))
done

if [ -n "$(printf '%s' "$remaining" | tr -d '[:space:]')" ]; then
  say "Could not delete"
  printf '  %s\n' "$(printf '%s ' $remaining)"
  echo "  Usually a dependency Port will not drop on its own. Inspect in the UI."
fi

# --- verify FR-005 ----------------------------------------------------------
say "FR-005 — every non-system blueprint is declared in modules/"
LEFT="$(curl -s --max-time 30 "$BASE/v1/blueprints" "${AUTH[@]}" \
  | jq -r '.blueprints[].identifier' | grep -v '^_' | sort)"
extra=""
for b in $LEFT; do
  printf '%s\n' $OURS | grep -qx "$b" || extra="$extra $b"
done
if [ -z "$(printf '%s' "$extra" | tr -d '[:space:]')" ]; then
  printf '  \033[32mPASS\033[0m  only declared blueprints remain\n'
  exit 0
fi
printf '  \033[31mFAIL\033[0m  undeclared blueprints still present:%s\n' "$extra"
exit 1
