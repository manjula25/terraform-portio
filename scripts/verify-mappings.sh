#!/usr/bin/env bash
####################################################################
# Pre-flight check on the jq expressions inside integration mappings.
#
# WHAT THIS IS NOT
#
# This is NOT evidence at the sanctioned seam. docs/agents/project-
# policy.md §Evidence levels is explicit: the public seam for a
# Terraform change is the Port API's representation of the object,
# "never the .tf source text", and a file-content assertion does not
# satisfy the RED requirement. This script reads the source text. It
# therefore sits BELOW the evidence ladder and proves nothing about
# what Port stores. Do not cite it as E-PLAN, and do not let it stand
# in for a plan-diff assertion.
#
# WHY IT EXISTS ANYWAY
#
# A mapping's jq expressions are the one part of this repository that
# no available rung can check:
#
#   - terraform fmt/validate see an opaque string inside jsonencode.
#     A jq expression that aborts at runtime is valid HCL.
#   - terraform plan shows the same string verbatim. The plan is
#     derived from the provider's view of the mapping config, and the
#     provider does not evaluate jq either.
#   - Only a live resync evaluates these expressions, and runtime
#     read-back is unavailable (no non-production organization, G-6).
#
# So a broken transform is invisible from `git diff` all the way to a
# production sync. Two real defects were found this way on 20 Aug 2026:
# a stage expression that aborted instead of returning "unknown", and
# a language expression producing "c#" for a closed enum that only
# permits "csharp". Both would have surfaced as failed-transform
# counters against FR-008's required zero, looking like data problems
# rather than mapping bugs.
#
# Requires jq. Exits non-zero on any failure.
####################################################################

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if ! command -v jq > /dev/null 2>&1; then
  echo "verify-mappings: jq is not installed — cannot check mapping expressions." >&2
  exit 1
fi

failed=0
checks=0

# Pull an HCL string literal out of a .tf file by its attribute name and
# unescape it back into the jq expression Ocean will actually evaluate.
# Deliberately narrow: single-line literals of the form `name = "..."`.
extract() {
  local file="$1" attr="$2" line literal
  line="$(grep -E "^[[:space:]]*${attr}[[:space:]]*=[[:space:]]*\"" "$file" | head -n 1)"
  if [ -z "$line" ]; then
    echo "verify-mappings: could not find '${attr}' in ${file}" >&2
    return 1
  fi
  literal="${line#*= }"
  literal="${literal#\"}"
  literal="${literal%\"}"
  # HCL -> raw: \" becomes ", \\ becomes \.
  printf '%s' "$literal" | sed 's/\\"/"/g; s/\\\\/\\/g'
}

# assert <label> <jq expression> <input json> <expected output>
assert() {
  local label="$1" expr="$2" input="$3" want="$4" got status
  checks=$((checks + 1))
  got="$(printf '%s' "$input" | jq -r "$expr" 2>&1)"
  status=$?
  if [ "$status" -eq 0 ] && [ "$got" = "$want" ]; then
    printf '  PASS  %-24s %-42s -> %s\n' "$label" "$input" "$got"
  else
    printf '  FAIL  %-24s %-42s -> %s (want %s)\n' "$label" "$input" "$got" "$want"
    failed=$((failed + 1))
  fi
}

GCP_TF="projects/mayo-pilot/integration-gcp.tf"
GH_TF="projects/mayo-pilot/github-integration.tf"

####################################################################
# environment.stage, from the GCP mapping (FR-013)
#
# The blueprint enum is dev|test|stage|prod. "unknown" is deliberately
# outside it: a name that does not encode a stage must fail loudly at
# validation, which is visible, rather than abort the transform or be
# silently guessed (M-2).
####################################################################
if [ -f "$GCP_TF" ]; then
  echo "environment.stage — $GCP_TF"
  if STAGE="$(extract "$GCP_TF" gcp_stage_jq)"; then
    assert stage "$STAGE" '{"display_name":"iris-d-app"}' dev
    assert stage "$STAGE" '{"display_name":"iris-t-app"}' test
    assert stage "$STAGE" '{"display_name":"iris-s-app"}' stage
    assert stage "$STAGE" '{"display_name":"iris-p-app"}' prod
    assert stage "$STAGE" '{"display_name":"IRIS-D-App"}' dev
    # The regression. These four aborted before 20 Aug 2026.
    assert stage "$STAGE" '{"display_name":"iris-prod"}' unknown
    assert stage "$STAGE" '{"display_name":"iris-x-app"}' unknown
    assert stage "$STAGE" '{"display_name":"iris"}' unknown
    assert stage "$STAGE" '{}' unknown
  else
    failed=$((failed + 1))
  fi
  echo
fi

####################################################################
# service.language, from the GitHub mapping
#
# Enum: typescript|javascript|python|php|go|java|csharp|other. Every
# GitHub language name must land inside it, or FR-008's "failed count
# is zero" is unreachable.
####################################################################
if [ -f "$GH_TF" ]; then
  echo "service.language — $GH_TF"
  if LANG_EXPR="$(extract "$GH_TF" language)"; then
    assert language "$LANG_EXPR" '{"language":"TypeScript"}' typescript
    assert language "$LANG_EXPR" '{"language":"JavaScript"}' javascript
    assert language "$LANG_EXPR" '{"language":"Python"}' python
    assert language "$LANG_EXPR" '{"language":"PHP"}' php
    assert language "$LANG_EXPR" '{"language":"Go"}' go
    assert language "$LANG_EXPR" '{"language":"Java"}' java
    # The regression: "c#" is not a permitted enum value, "csharp" is.
    assert language "$LANG_EXPR" '{"language":"C#"}' csharp
    # Anything outside the enum must degrade to `other`, never leak through.
    assert language "$LANG_EXPR" '{"language":"C++"}' other
    assert language "$LANG_EXPR" '{"language":"Rust"}' other
    assert language "$LANG_EXPR" '{"language":"Kotlin"}' other
    assert language "$LANG_EXPR" '{"language":null}' other
    assert language "$LANG_EXPR" '{}' other
  else
    failed=$((failed + 1))
  fi
  echo

  ####################################################################
  # pull_request.status (FR-015)
  #
  # Enum: open|merged|closed. The provider reports open|closed only;
  # `merged` is derived from a merge timestamp, and mapping .state
  # straight through would render every merged pull request "closed" —
  # wrong on the one transition the phase exit test is about.
  ####################################################################
  echo "pull_request.status — $GH_TF"
  if STATUS="$(extract "$GH_TF" status)"; then
    assert status "$STATUS" '{"state":"open","merged_at":null}' open
    assert status "$STATUS" '{"state":"closed","merged_at":"2026-08-19T00:00:00Z"}' merged
    assert status "$STATUS" '{"state":"closed","merged_at":null}' closed
    assert status "$STATUS" '{"state":"open"}' open
  else
    failed=$((failed + 1))
  fi
  echo
fi

echo "Result"
if [ "$failed" -eq 0 ]; then
  echo "  ${checks} mapping-expression checks passed."
  echo "  This is a pre-flight check, NOT plan-rung evidence — see the header."
else
  echo "  ${failed} of ${checks} mapping-expression checks FAILED."
  exit 1
fi
