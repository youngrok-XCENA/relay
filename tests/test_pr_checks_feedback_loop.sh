#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTION_FILE="$REPO_ROOT/.github/actions/collect-pr-checks/collect.sh"
CODEX_WORKFLOW="$REPO_ROOT/.github/workflows/codex.yml"
CLAUDE_WORKFLOW="$REPO_ROOT/.github/workflows/claude.yml"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "missing expected content: $needle" >&2
    exit 1
  fi
}

ACTION_CONTENT="$(cat "$ACTION_FILE")"
CODEX_CONTENT="$(cat "$CODEX_WORKFLOW")"
CLAUDE_CONTENT="$(cat "$CLAUDE_WORKFLOW")"

assert_contains "$ACTION_CONTENT" 'repos/${REPOSITORY}/pulls/${PR_NUMBER}'
assert_contains "$ACTION_CONTENT" 'repos/${REPOSITORY}/actions/jobs/${job_id}/logs'
assert_contains "$ACTION_CONTENT" 'write_outputs "$HEAD_SHA" "failed" "true"'
assert_contains "$ACTION_CONTENT" 'write_outputs "$HEAD_SHA" "passed" "false"'

assert_contains "$CODEX_CONTENT" "- name: Wait for PR checks"
assert_contains "$CODEX_CONTENT" "max_check_fix_attempts:"
assert_contains "$CODEX_CONTENT" "- name: Normalize checks fix attempts"
assert_contains "$CODEX_CONTENT" 'if [ "$attempts" -gt 3 ]; then'
assert_contains "$CODEX_CONTENT" "youngrok-XCENA/relay/.github/actions/collect-pr-checks@main"
assert_contains "$CODEX_CONTENT" "- name: Run Codex checks fix attempt 2"
assert_contains "$CODEX_CONTENT" "- name: Run Codex checks fix attempt 3"
assert_contains "$CODEX_CONTENT" "- name: Wait for PR checks after checks fix attempt 3"
assert_contains "$CODEX_CONTENT" "| 6. PR checks 확인 |"
assert_contains "$CODEX_CONTENT" "| 7. checks 실패 반영 |"
assert_contains "$CODEX_CONTENT" "The check output above is the source of truth"
assert_contains "$CODEX_CONTENT" 'max_check_fix_attempts=0'

assert_contains "$CLAUDE_CONTENT" "- name: Wait for PR checks"
assert_contains "$CLAUDE_CONTENT" "max_check_fix_attempts:"
assert_contains "$CLAUDE_CONTENT" "- name: Normalize checks fix attempts"
assert_contains "$CLAUDE_CONTENT" "- name: Run Claude checks fix attempt 2"
assert_contains "$CLAUDE_CONTENT" "- name: Run Claude checks fix attempt 3"
assert_contains "$CLAUDE_CONTENT" "- name: Wait for PR checks after checks fix attempt 3"
assert_contains "$CLAUDE_CONTENT" "| 6. PR checks 확인 |"
assert_contains "$CLAUDE_CONTENT" "| 7. checks 실패 반영 |"
assert_contains "$CLAUDE_CONTENT" '### checks 반영 결과'
assert_contains "$CLAUDE_CONTENT" 'max_check_fix_attempts=0'

echo "ok"
