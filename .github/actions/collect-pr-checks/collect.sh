#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${REPOSITORY:?}"
PR_NUMBER="${PR_NUMBER:?}"
MAX_WAIT_MINUTES="${MAX_WAIT_MINUTES:-10}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-15}"
NO_CHECK_GRACE_SECONDS="${NO_CHECK_GRACE_SECONDS:-60}"
MAX_SUMMARY_CHARS="${MAX_SUMMARY_CHARS:-12000}"

trim_output() {
  local text="$1"
  if [ "${#text}" -gt "$MAX_SUMMARY_CHARS" ]; then
    printf "%s\n\n...(truncated)" "${text:0:MAX_SUMMARY_CHARS}"
  else
    printf "%s" "$text"
  fi
}

write_outputs() {
  local head_sha="$1"
  local status="$2"
  local has_failures="$3"
  local total_checks="$4"
  local summary="$5"

  summary="$(trim_output "$summary")"

  {
    echo "head_sha=${head_sha}"
    echo "status=${status}"
    echo "has_failures=${has_failures}"
    echo "total_checks=${total_checks}"
    echo "summary<<GHEOF"
    echo "$summary"
    echo "GHEOF"
  } >> "$GITHUB_OUTPUT"
}

fetch_job_log_excerpt() {
  local job_id="$1"
  local log_file text_file excerpt

  log_file="$(mktemp)"
  text_file="$(mktemp)"

  if ! gh api "repos/${REPOSITORY}/actions/jobs/${job_id}/logs" >"$log_file" 2>/dev/null; then
    rm -f "$log_file" "$text_file"
    return 0
  fi

  if gzip -t "$log_file" >/dev/null 2>&1; then
    gzip -dc "$log_file" >"$text_file" 2>/dev/null || cp "$log_file" "$text_file"
  else
    cp "$log_file" "$text_file"
  fi

  sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g' "$text_file" > "${text_file}.clean"

  excerpt="$(grep -n -i -E -C 2 'error:|exception|traceback|assert|undefined reference|no such file|formatting diff|code should be clang-formatted' "${text_file}.clean" | head -n 40 || true)"
  if [ -z "$excerpt" ]; then
    excerpt="$(grep -n -i -E -C 2 '(^|[^[:alpha:]])(failed|failure)([^[:alpha:]]|$)' "${text_file}.clean" | head -n 40 || true)"
  fi
  if [ -z "$excerpt" ]; then
    excerpt="$(tail -n 80 "${text_file}.clean" || true)"
  fi

  rm -f "$log_file" "$text_file" "${text_file}.clean"
  printf "%s" "$excerpt" | head -c 4000
}

fetch_actions_failure_excerpt() {
  local url="$1"
  local run_id="" job_id="" jobs_json excerpt=""

  if [[ "$url" =~ /actions/runs/([0-9]+)/job/([0-9]+) ]]; then
    run_id="${BASH_REMATCH[1]}"
    job_id="${BASH_REMATCH[2]}"
  elif [[ "$url" =~ /actions/runs/([0-9]+) ]]; then
    run_id="${BASH_REMATCH[1]}"
  fi

  if [ -n "$job_id" ]; then
    fetch_job_log_excerpt "$job_id"
    return 0
  fi

  if [ -z "$run_id" ]; then
    return 0
  fi

  jobs_json="$(gh api "repos/${REPOSITORY}/actions/runs/${run_id}/jobs?per_page=100" 2>/dev/null || true)"
  if [ -z "$jobs_json" ]; then
    return 0
  fi

  while IFS= read -r failed_job_id; do
    if [ -z "$failed_job_id" ]; then
      continue
    fi

    excerpt="$(fetch_job_log_excerpt "$failed_job_id")"
    if [ -n "$excerpt" ]; then
      printf "%s" "$excerpt"
      return 0
    fi
  done < <(printf "%s" "$jobs_json" | jq -r '.jobs[]? | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "cancelled") | .id')
}

append_failure_block() {
  local summary="$1"
  local name="$2"
  local conclusion="$3"
  local app="$4"
  local url="$5"
  local description="$6"
  local excerpt="$7"

  summary="${summary}

- ${name} [${conclusion}]"

  if [ -n "$app" ]; then
    summary="${summary}
  App: ${app}"
  fi

  if [ -n "$url" ]; then
    summary="${summary}
  URL: ${url}"
  fi

  if [ -n "$description" ]; then
    summary="${summary}
  Detail: ${description}"
  fi

  if [ -n "$excerpt" ]; then
    summary="${summary}
  Evidence:
$(printf "%s\n" "$excerpt" | sed 's/^/    /')"
  fi

  printf "%s" "$summary"
}

build_failure_summary() {
  local head_sha="$1"
  local failed_check_runs_json="$2"
  local failed_statuses_json="$3"
  local summary excerpt item name conclusion app url description

  summary="Head SHA: ${head_sha}

Failing PR checks were detected on the current pull request head. Use the evidence below as the source of truth for follow-up fixes."

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    name="$(printf "%s" "$item" | jq -r '.name // "Unnamed check"')"
    conclusion="$(printf "%s" "$item" | jq -r '.conclusion // "failed"')"
    app="$(printf "%s" "$item" | jq -r '.app // ""')"
    url="$(printf "%s" "$item" | jq -r '.url // ""')"
    excerpt=""

    if [ "$app" = "github-actions" ] && [ -n "$url" ]; then
      excerpt="$(fetch_actions_failure_excerpt "$url")"
    fi

    summary="$(append_failure_block "$summary" "$name" "$conclusion" "$app" "$url" "" "$excerpt")"
  done < <(printf "%s" "$failed_check_runs_json" | jq -c '.[]?')

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    name="$(printf "%s" "$item" | jq -r '.name // "Unnamed status"')"
    conclusion="$(printf "%s" "$item" | jq -r '.conclusion // "failure"')"
    url="$(printf "%s" "$item" | jq -r '.url // ""')"
    description="$(printf "%s" "$item" | jq -r '.description // ""')"
    summary="$(append_failure_block "$summary" "$name" "$conclusion" "commit-status" "$url" "$description" "")"
  done < <(printf "%s" "$failed_statuses_json" | jq -c '.[]?')

  printf "%s" "$summary"
}

build_pending_summary() {
  local head_sha="$1"
  local check_runs_json="$2"
  local statuses_json="$3"
  local summary item name state

  summary="Head SHA: ${head_sha}

Timed out while waiting for PR checks to finish."

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    name="$(printf "%s" "$item" | jq -r '.name // "Unnamed check"')"
    state="$(printf "%s" "$item" | jq -r '.status // "pending"')"
    summary="${summary}

- ${name} [${state}]"
  done < <(printf "%s" "$check_runs_json" | jq -c '.check_runs[]? | select(.status != "completed")')

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    name="$(printf "%s" "$item" | jq -r '.context // "Unnamed status"')"
    summary="${summary}

- ${name} [pending]"
  done < <(printf "%s" "$statuses_json" | jq -c '.statuses[]? | select(.state == "pending")')

  printf "%s" "$summary"
}

START_TIME="$(date +%s)"
DEADLINE="$((START_TIME + MAX_WAIT_MINUTES * 60))"

while true; do
  NOW="$(date +%s)"

  PR_JSON="$(gh api "repos/${REPOSITORY}/pulls/${PR_NUMBER}" 2>/dev/null || true)"
  if [ -z "$PR_JSON" ]; then
    write_outputs "" "api_error" "false" "0" "Failed to fetch PR #${PR_NUMBER} while collecting checks."
    exit 0
  fi

  HEAD_SHA="$(printf "%s" "$PR_JSON" | jq -r '.head.sha // empty')"
  if [ -z "$HEAD_SHA" ]; then
    write_outputs "" "api_error" "false" "0" "PR #${PR_NUMBER} did not expose a head SHA."
    exit 0
  fi

  CHECK_RUNS_JSON="$(gh api -H 'Accept: application/vnd.github+json' "repos/${REPOSITORY}/commits/${HEAD_SHA}/check-runs?per_page=100" 2>/dev/null || true)"
  if [ -z "$CHECK_RUNS_JSON" ]; then
    write_outputs "$HEAD_SHA" "api_error" "false" "0" "Failed to fetch check runs for commit ${HEAD_SHA}."
    exit 0
  fi

  STATUSES_JSON="$(gh api "repos/${REPOSITORY}/commits/${HEAD_SHA}/status" 2>/dev/null || true)"
  if [ -z "$STATUSES_JSON" ]; then
    write_outputs "$HEAD_SHA" "api_error" "false" "0" "Failed to fetch commit statuses for commit ${HEAD_SHA}."
    exit 0
  fi

  CHECK_RUN_TOTAL="$(printf "%s" "$CHECK_RUNS_JSON" | jq -r '.total_count // 0')"
  STATUS_TOTAL="$(printf "%s" "$STATUSES_JSON" | jq -r '.total_count // 0')"
  TOTAL_CHECKS="$((CHECK_RUN_TOTAL + STATUS_TOTAL))"

  if [ "$TOTAL_CHECKS" -eq 0 ]; then
    if [ "$((NOW - START_TIME))" -lt "$NO_CHECK_GRACE_SECONDS" ] && [ "$NOW" -lt "$DEADLINE" ]; then
      sleep "$POLL_INTERVAL_SECONDS"
      continue
    fi

    write_outputs "$HEAD_SHA" "no_checks" "false" "0" "Head SHA: ${HEAD_SHA}

No PR checks were registered for the current pull request head."
    exit 0
  fi

  PENDING_CHECK_RUNS="$(printf "%s" "$CHECK_RUNS_JSON" | jq -r '[.check_runs[]? | select(.status != "completed")] | length')"
  PENDING_STATUSES="0"
  if [ "$STATUS_TOTAL" -gt 0 ]; then
    PENDING_STATUSES="$(printf "%s" "$STATUSES_JSON" | jq -r '[.statuses[]? | select(.state == "pending")] | length')"
  fi

  FAILED_CHECK_RUNS_JSON="$(printf "%s" "$CHECK_RUNS_JSON" | jq -c '[.check_runs[]? | (.conclusion // "") as $c | select(.status == "completed" and (["success", "neutral", "skipped"] | index($c) | not)) | {name, conclusion: $c, app: (.app.slug // ""), url: (.details_url // .html_url // "")}]')"
  FAILED_STATUSES_JSON="$(printf "%s" "$STATUSES_JSON" | jq -c '[.statuses[]? | select(.state == "failure" or .state == "error") | {name: .context, conclusion: .state, url: (.target_url // ""), description: (.description // "")}]')"

  FAILED_COUNT="$(( $(printf "%s" "$FAILED_CHECK_RUNS_JSON" | jq -r 'length') + $(printf "%s" "$FAILED_STATUSES_JSON" | jq -r 'length') ))"

  if [ "$PENDING_CHECK_RUNS" -eq 0 ] && [ "$PENDING_STATUSES" -eq 0 ]; then
    if [ "$FAILED_COUNT" -eq 0 ]; then
      write_outputs "$HEAD_SHA" "passed" "false" "$TOTAL_CHECKS" "Head SHA: ${HEAD_SHA}

All ${TOTAL_CHECKS} PR checks passed on the current pull request head."
      exit 0
    fi

    write_outputs "$HEAD_SHA" "failed" "true" "$TOTAL_CHECKS" "$(build_failure_summary "$HEAD_SHA" "$FAILED_CHECK_RUNS_JSON" "$FAILED_STATUSES_JSON")"
    exit 0
  fi

  if [ "$NOW" -ge "$DEADLINE" ]; then
    write_outputs "$HEAD_SHA" "timed_out" "false" "$TOTAL_CHECKS" "$(build_pending_summary "$HEAD_SHA" "$CHECK_RUNS_JSON" "$STATUSES_JSON")"
    exit 0
  fi

  sleep "$POLL_INTERVAL_SECONDS"
done
