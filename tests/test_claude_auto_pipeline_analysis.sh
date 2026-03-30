#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_WORKFLOW="$REPO_ROOT/.github/workflows/claude.yml"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "missing expected content: $needle" >&2
    exit 1
  fi
}

WORKFLOW_CONTENT="$(cat "$CLAUDE_WORKFLOW")"

assert_contains "$WORKFLOW_CONTENT" "AUTO-PIPELINE (analysis → fix → PR → review → pr-fix → PR checks)"
assert_contains "$WORKFLOW_CONTENT" "- name: Analyze issue"
assert_contains "$WORKFLOW_CONTENT" "### Claude 이슈 분석 (Auto Pipeline)"
assert_contains "$WORKFLOW_CONTENT" 'ANALYSIS_RESULT: ${{ steps.analysis.outputs.result }}'
assert_contains "$WORKFLOW_CONTENT" "## Issue Analysis"
assert_contains "$WORKFLOW_CONTENT" "| 1. 이슈 분석 |"

echo "ok"
