#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_WORKFLOW="$REPO_ROOT/.github/workflows/codex.yml"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "missing expected content: $needle" >&2
    exit 1
  fi
}

WORKFLOW_CONTENT="$(cat "$CODEX_WORKFLOW")"

assert_contains "$WORKFLOW_CONTENT" "- name: Post PR fix comment"
assert_contains "$WORKFLOW_CONTENT" "if: steps.prfix_push.outputs.has_changes == 'true'"
assert_contains "$WORKFLOW_CONTENT" 'body: ${{ steps.prfix.outputs.result }}'
assert_contains "$WORKFLOW_CONTENT" 'target: ${{ steps.pr.outputs.number }}'
assert_contains "$WORKFLOW_CONTENT" "type: pr"

echo "ok"
