#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 -c "
import yaml, sys

def load_action(name):
    with open(f'$REPO_ROOT/.github/actions/{name}/action.yml') as f:
        data = yaml.safe_load(f)
    return set(data.get('inputs', {}).keys()), set(data.get('outputs', {}).keys())

errors = []

EXPECTED = {
    'run-claude': {
        'inputs': {'prompt', 'resume_prompt', 'model', 'max_turns', 'output_format', 'resume_session', 'session_id', 'session_file'},
        'outputs': {'result', 'exit_code', 'failure_type', 'session_id'},
    },
    'run-codex': {
        'inputs': {'prompt', 'resume_prompt', 'model', 'node_path', 'codex_sandbox', 'resume_session', 'session_id', 'session_file'},
        'outputs': {'result', 'exit_code', 'failure_type', 'session_id'},
    },
    'collect-pr-checks': {
        'inputs': {'repository', 'pr_number', 'max_wait_minutes', 'poll_interval_seconds', 'no_check_grace_seconds', 'max_summary_chars'},
        'outputs': {'head_sha', 'status', 'has_failures', 'total_checks', 'summary'},
    },
    'post-comment': {
        'inputs': {'body', 'target', 'type', 'repository', 'token'},
        'outputs': set(),
    },
    'react-emoji': {
        'inputs': {'url', 'reaction', 'token'},
        'outputs': set(),
    },
}

for action, spec in EXPECTED.items():
    actual_inputs, actual_outputs = load_action(action)

    missing_inputs = spec['inputs'] - actual_inputs
    for m in sorted(missing_inputs):
        errors.append(f'{action}: missing input \"{m}\"')

    missing_outputs = spec['outputs'] - actual_outputs
    for m in sorted(missing_outputs):
        errors.append(f'{action}: missing output \"{m}\"')

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
"

echo "ok"
