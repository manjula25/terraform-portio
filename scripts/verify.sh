#!/usr/bin/env bash
# Runs the evidence ladder from docs/agents/project-policy.md and reports each
# rung's exit code, so verification-before-completion has one command to call.
#
#   ./scripts/verify.sh            # every stack
#   ./scripts/verify.sh organization
#   ./scripts/verify.sh projects/mayo-pilot
#
# Unavailable rungs are printed as SKIP with the reason. A skipped rung is not a
# passed rung; a completion claim must say which rungs actually ran.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
root="$PWD"
failed=0

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s (exit %s)\n' "$1" "$2"; failed=1; }
skip() { printf '  \033[33mSKIP\033[0m  %s — %s\n' "$1" "$2"; }

run() { # run <label> <command...>
  local label="$1"; shift
  if "$@" > /tmp/verify-out.$$ 2>&1; then
    pass "$label"
  else
    local code=$?
    fail "$label" "$code"
    sed 's/^/        /' /tmp/verify-out.$$
  fi
  rm -f /tmp/verify-out.$$
}

# No mapfile: macOS ships bash 3.2 and this must run on a developer laptop
# as well as in CI.
stacks=()
if [ "$#" -gt 0 ]; then
  stacks=("$@")
else
  while IFS= read -r line; do
    stacks+=("$line")
  done < <(find organization projects -name '*.tf' -exec dirname {} \; | sort -u)
fi
[ "${#stacks[@]}" -gt 0 ] || { echo "no stacks found"; exit 1; }

command -v terraform > /dev/null || { echo "terraform not on PATH"; exit 1; }
[ -n "${PORT_CLIENT_ID:-}" ] && [ -n "${PORT_CLIENT_SECRET:-}" ] \
  || echo "note: PORT_CLIENT_ID / PORT_CLIENT_SECRET unset — init and plan will not reach Port"

say "Rung 1 · formatting (repository-wide)"
run "terraform fmt -check -recursive" terraform fmt -check -recursive

for stack in "${stacks[@]}"; do
  say "Stack: $stack"
  cd "$root/$stack" || { fail "cd $stack" 1; continue; }

  run "terraform init"     terraform init -input=false
  run "terraform validate" terraform validate

  if terraform plan -input=false -no-color -lock-timeout=5m -out=tfplan > plan.txt 2>&1; then
    pass "terraform plan"
    # The guard plan.yml enforces in CI: a delete in the shared model takes
    # entities with it, because the provider is create-and-override.
    if [ "$stack" = "organization" ] && command -v jq > /dev/null; then
      if terraform show -json tfplan \
         | jq -e '.resource_changes[]?.change.actions | index("delete")' > /dev/null; then
        fail "no-destroy guard on shared model" 1
      else
        pass "no-destroy guard on shared model"
      fi
    elif [ "$stack" = "organization" ]; then
      skip "no-destroy guard" "jq not installed"
    fi
  else
    fail "terraform plan" "$?"
    sed 's/^/        /' plan.txt
  fi

  cd "$root" || exit 1
done

say "Rungs not available"
skip "policy (conftest/OPA)" "not installed — see project-policy.md evidence levels"
skip "lint (tflint)"         "not installed"
skip "runtime read-back"     "no non-production Port organization yet (Phase 0 gate)"
skip "unit tests"            "no test harness in this repository"

say "Result"
if [ "$failed" -eq 0 ]; then
  echo "  every available rung passed. Highest rung reached: plan-diff."
  echo "  Runtime evidence was NOT captured — say so in any completion claim."
else
  echo "  at least one rung failed. Not verified."
  exit 1
fi
