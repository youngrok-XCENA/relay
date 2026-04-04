#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

# Source install.sh functions (everything before main)
TMP_INSTALL="$(mktemp)"
trap 'rm -f "$TMP_INSTALL"' EXIT

sed '/^main "\$@"$/d' "$INSTALL_SH" | sed '/^main() {$/,/^}$/d' > "$TMP_INSTALL"

# shellcheck disable=SC1090
source "$TMP_INSTALL"

# ── Mock gh to capture subcommands (temp file for pipe subshell) ──
GH_CALL_LOG="$(mktemp)"
trap 'rm -f "$TMP_INSTALL" "$GH_CALL_LOG"' EXIT

gh() {
  echo "gh $*" >> "$GH_CALL_LOG"
  if [[ "$1" == "secret" && "$2" == "list" ]]; then
    echo "GH_PAT	2026-01-01"
    return 0
  fi
  return 0
}
export -f gh

GH_PAT="ghp_test_token_123"

# ── Run install_secret ──
: > "$GH_CALL_LOG"
install_secret "owner/repo" >/dev/null 2>&1

GH_CALLS="$(cat "$GH_CALL_LOG")"

# ── Verify: should call "gh secret remove", not "gh secret delete" ──
if [[ "$GH_CALLS" == *"secret delete"* ]]; then
  echo "FAIL: used 'gh secret delete' (does not exist), should be 'gh secret remove'" >&2
  exit 1
fi

if [[ "$GH_CALLS" != *"secret remove"* ]]; then
  echo "FAIL: expected 'gh secret remove' call" >&2
  echo "actual calls: $GH_CALLS" >&2
  exit 1
fi

if [[ "$GH_CALLS" != *"secret set GH_PAT"* ]]; then
  echo "FAIL: expected 'gh secret set GH_PAT' call" >&2
  echo "actual calls: $GH_CALLS" >&2
  exit 1
fi

echo "ok"
