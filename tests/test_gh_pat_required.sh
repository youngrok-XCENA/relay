#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Running install.sh without GH_PAT should fail with guidance
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$REPO_ROOT/install.sh" "$TMP_DIR/install.sh"
chmod +x "$TMP_DIR/install.sh"

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" remote add origin git@github.com:youngrok-XCENA/example.git

OUTPUT="$(cd "$TMP_DIR" && unset GH_PAT && bash install.sh 2>&1 || true)"

if [[ "$OUTPUT" != *"GH_PAT"* ]]; then
  echo "expected GH_PAT guidance in error output" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"github.com/settings/tokens"* ]]; then
  echo "expected token creation URL in error output" >&2
  exit 1
fi

echo "ok"
