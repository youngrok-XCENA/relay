#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

assert_eq() {
  if [[ "$1" != "$2" ]]; then
    echo "expected '$2' but got '$1'" >&2
    exit 1
  fi
}

# Source install.sh functions (everything before main)
TMP_INSTALL="$(mktemp)"
trap 'rm -f "$TMP_INSTALL"' EXIT

sed '/^main "\$@"$/d' "$INSTALL_SH" | sed '/^main() {$/,/^}$/d' > "$TMP_INSTALL"

# shellcheck disable=SC1090
source "$TMP_INSTALL"

assert_eq "$(caller_filename_for_workflow claude)" "claude-caller.yml"
assert_eq "$(caller_filename_for_workflow codex)" "codex-caller.yml"
assert_eq "$(caller_filename_for_workflow something-else)" "something-else-caller.yml"

echo "ok"
