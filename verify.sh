#!/usr/bin/env bash
# Agent CI installation verifier
# Usage: bash <(gh api repos/youngrok-XCENA/relay/contents/verify.sh --jq '.content' | base64 -d)

set -euo pipefail

use_color=false
if [ -t 1 ] && command -v tput &>/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  use_color=true
fi

pass() { if $use_color; then printf '\033[32m  PASS\033[0m %s\n' "$1"; else printf '  PASS %s\n' "$1"; fi; }
fail() { if $use_color; then printf '\033[31m  FAIL\033[0m %s\n' "$1"; else printf '  FAIL %s\n' "$1"; fi; }

detect_git_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

parse_github_repo_from_remote() {
  local remote_url="$1" repo
  repo=$(printf '%s\n' "$remote_url" | sed -nE 's#^(git@github\.com:|ssh://git@github\.com/|https://github\.com/|http://github\.com/)([^[:space:]]+)$#\2#p')
  [ -n "$repo" ] || return 1
  repo="${repo%.git}"
  repo="${repo%/}"
  printf '%s\n' "$repo"
}

main() {
  echo "Agent CI 설치 검증"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local failures=0

  # Detect repo
  local repo_root repo
  repo_root=$(detect_git_root ".") || {
    fail "git repository 감지 실패"
    exit 1
  }

  local remote_url
  remote_url=$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)
  if [ -z "$remote_url" ]; then
    fail "origin remote 감지 실패"
    exit 1
  fi

  repo=$(parse_github_repo_from_remote "$remote_url") || {
    fail "GitHub repo 감지 실패"
    exit 1
  }

  echo "  대상: $repo"
  echo ""

  # 1. claude-caller.yml
  if [ -f "$repo_root/.github/workflows/claude-caller.yml" ]; then
    pass "claude-caller.yml 존재"
  else
    fail "claude-caller.yml 없음"
    failures=$((failures + 1))
  fi

  # 2. codex-caller.yml
  if [ -f "$repo_root/.github/workflows/codex-caller.yml" ]; then
    pass "codex-caller.yml 존재"
  else
    fail "codex-caller.yml 없음"
    failures=$((failures + 1))
  fi

  # 3. GH_PAT secret
  if command -v gh &>/dev/null; then
    if gh secret list -R "$repo" 2>/dev/null | grep -q '^GH_PAT'; then
      pass "GH_PAT secret 설정됨"
    else
      fail "GH_PAT secret 없음"
      failures=$((failures + 1))
    fi
  else
    fail "gh CLI 없음 (secret 확인 불가)"
    failures=$((failures + 1))
  fi

  # 4. Self-hosted runners
  if command -v gh &>/dev/null; then
    local runners
    runners=$(gh api "repos/$repo/actions/runners" --jq '[.runners[].labels[].name] | unique | join(",")' 2>/dev/null || true)

    local claude_ok=false codex_ok=false
    if printf '%s' "$runners" | grep -q 'claude-ci'; then
      claude_ok=true
    fi
    if printf '%s' "$runners" | grep -q 'codex-ci'; then
      codex_ok=true
    fi

    if $claude_ok && $codex_ok; then
      pass "self-hosted runners 등록됨 (claude-ci, codex-ci)"
    elif $claude_ok; then
      fail "codex-ci runner 없음"
      failures=$((failures + 1))
    elif $codex_ok; then
      fail "claude-ci runner 없음"
      failures=$((failures + 1))
    else
      fail "self-hosted runners 없음 (claude-ci, codex-ci)"
      failures=$((failures + 1))
    fi
  else
    fail "gh CLI 없음 (runner 확인 불가)"
    failures=$((failures + 1))
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$failures" -eq 0 ]; then
    pass "모든 검증 통과"
    exit 0
  else
    fail "${failures}개 항목 실패"
    exit 1
  fi
}

main "$@"
