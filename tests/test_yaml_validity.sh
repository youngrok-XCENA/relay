#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/_yaml_helper.sh"

YAML_FILES=(
  ".github/workflows/claude.yml"
  ".github/workflows/codex.yml"
  ".github/workflows/claude-caller.yml"
  ".github/workflows/codex-caller.yml"
  ".github/actions/run-claude/action.yml"
  ".github/actions/run-codex/action.yml"
  ".github/actions/collect-pr-checks/action.yml"
  ".github/actions/post-comment/action.yml"
  ".github/actions/react-emoji/action.yml"
)

for f in "${YAML_FILES[@]}"; do
  filepath="$REPO_ROOT/$f"
  if [ ! -f "$filepath" ]; then
    echo "file not found: $f" >&2
    exit 1
  fi
  if ! yaml_parse "$filepath"; then
    echo "invalid YAML: $f" >&2
    exit 1
  fi
done

echo "ok"
