#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERIFY_SH="$REPO_ROOT/verify.sh"

# verify.sh should detect missing workflow files
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$VERIFY_SH" "$TMP_DIR/verify.sh"
chmod +x "$TMP_DIR/verify.sh"

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" remote add origin git@github.com:youngrok-XCENA/example.git

# Without workflow files, verify should report FAIL
OUTPUT="$(cd "$TMP_DIR" && bash verify.sh 2>&1 || true)"

if [[ "$OUTPUT" != *"FAIL"* ]]; then
  echo "expected FAIL for missing workflow files" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"claude-caller.yml"* ]]; then
  echo "expected claude-caller.yml check in output" >&2
  exit 1
fi

# With workflow files present, those checks should PASS
mkdir -p "$TMP_DIR/.github/workflows"
touch "$TMP_DIR/.github/workflows/claude-caller.yml"
touch "$TMP_DIR/.github/workflows/codex-caller.yml"

OUTPUT2="$(cd "$TMP_DIR" && bash verify.sh 2>&1 || true)"

if [[ "$OUTPUT2" != *"PASS"*"claude-caller.yml"* ]]; then
  echo "expected PASS for claude-caller.yml" >&2
  exit 1
fi

if [[ "$OUTPUT2" != *"PASS"*"codex-caller.yml"* ]]; then
  echo "expected PASS for codex-caller.yml" >&2
  exit 1
fi

echo "ok"
