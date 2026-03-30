#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 -c "
import yaml, sys, json

def load_jobs(path):
    with open(path) as f:
        data = yaml.safe_load(f)
    return data.get('jobs', {})

errors = []

CLAUDE_EXPECTED_JOBS = [
    'parse-review', 'review', 'notify-review-timeout',
    'fix', 'notify-fix-timeout',
    'parse-pr-fix', 'pr-fix', 'notify-pr-fix-timeout',
    'triage-cleanup', 'triage', 'notify-triage-timeout',
    'auto-pipeline', 'notify-pipeline-timeout',
]

CODEX_EXPECTED_JOBS = [
    'parse-review', 'review', 'notify-review-timeout',
    'fix', 'notify-fix-timeout',
    'auto-pipeline', 'notify-pipeline-timeout',
    'triage-cleanup', 'triage', 'notify-triage-timeout',
]

# Mode -> jobs whose 'if' must reference that mode
MODE_JOBS = {
    'review': ['parse-review', 'review'],
    'fix': ['fix'],
    'triage': ['triage'],
    'auto-pipeline': ['auto-pipeline'],
}

CLAUDE_MODE_JOBS = {**MODE_JOBS, 'pr-fix': ['parse-pr-fix', 'pr-fix']}

# needs chains
NEEDS_CHAINS = {
    'review': 'parse-review',
}
CLAUDE_NEEDS = {**NEEDS_CHAINS, 'pr-fix': 'parse-pr-fix'}

for name, expected_jobs, mode_map, needs_map in [
    ('claude.yml', CLAUDE_EXPECTED_JOBS, CLAUDE_MODE_JOBS, CLAUDE_NEEDS),
    ('codex.yml', CODEX_EXPECTED_JOBS, MODE_JOBS, NEEDS_CHAINS),
]:
    jobs = load_jobs(f'$REPO_ROOT/.github/workflows/{name}')

    # Check job existence
    for job in expected_jobs:
        if job not in jobs:
            errors.append(f'{name}: missing job \"{job}\"')

    # Check if-conditions reference correct mode
    for mode, job_names in mode_map.items():
        for job in job_names:
            if job not in jobs:
                continue
            if_cond = str(jobs[job].get('if', ''))
            if mode not in if_cond:
                errors.append(f'{name}: job \"{job}\" if-condition does not reference \"{mode}\"')

    # Check needs chains
    for job, needed in needs_map.items():
        if job not in jobs:
            continue
        needs = jobs[job].get('needs', [])
        if isinstance(needs, str):
            needs = [needs]
        if needed not in needs:
            errors.append(f'{name}: job \"{job}\" missing needs \"{needed}\"')

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
"

echo "ok"
