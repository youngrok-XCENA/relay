#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Running install.sh inside the ci repo itself should fail
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$REPO_ROOT/install.sh" "$TMP_DIR/install.sh"
chmod +x "$TMP_DIR/install.sh"

git -C "$TMP_DIR" init -q
git -C "$TMP_DIR" remote add origin git@github.com:youngrok-XCENA/relay.git

OUTPUT="$(cd "$TMP_DIR" && GH_PAT=fake_token bash install.sh 2>&1 || true)"

if [[ "$OUTPUT" != *"youngrok-XCENA/relay"* ]]; then
  echo "expected ci repo guard message" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"caller repo에서 실행"* ]]; then
  echo "expected guidance to run in caller repo" >&2
  exit 1
fi

echo "ok"
