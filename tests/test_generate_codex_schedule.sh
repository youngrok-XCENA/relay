#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    echo "missing expected content: $2" >&2
    exit 1
  fi
}

assert_not_contains() {
  if [[ "$1" == *"$2"* ]]; then
    echo "unexpected content: $2" >&2
    exit 1
  fi
}

# Source install.sh functions (everything before main)
TMP_INSTALL="$(mktemp)"
trap 'rm -f "$TMP_INSTALL"' EXIT

sed '/^main "\$@"$/d' "$INSTALL_SH" | sed '/^main() {$/,/^}$/d' > "$TMP_INSTALL"

# shellcheck disable=SC1090
source "$TMP_INSTALL"

WORKFLOW_CONTENT="$(generate_relay_caller codex "Example project" "YAML/Shell conventions" "*.yml *.yaml *.sh" "" "" "main")"

# schedule/workflow_dispatch는 caller에 포함하지 않음 (사용자가 필요 시 직접 설정)
assert_not_contains "$WORKFLOW_CONTENT" "schedule:"
assert_not_contains "$WORKFLOW_CONTENT" "workflow_dispatch:"
assert_not_contains "$WORKFLOW_CONTENT" "scheduled_context:"
assert_not_contains "$WORKFLOW_CONTENT" "scheduled-issue:"

# 기본 이벤트 트리거는 존재해야 함
assert_contains "$WORKFLOW_CONTENT" "github.event_name == 'issue_comment' &&"

echo "ok"
