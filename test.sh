#!/usr/bin/env bash
set -euo pipefail

# Run all unit tests in tests/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

passed=0
failed=0
failures=()

for test_file in "$TESTS_DIR"/test_*.sh; do
  [ -f "$test_file" ] || continue
  test_name="$(basename "$test_file")"

  if bash "$test_file" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m %s\n' "$test_name"
    passed=$((passed + 1))
  else
    printf '  \033[31m✗\033[0m %s\n' "$test_name"
    failed=$((failed + 1))
    failures+=("$test_name")
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  passed: $passed  failed: $failed"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "  실패 목록:"
  for f in "${failures[@]}"; do
    echo "    - $f"
  done
  exit 1
fi
