#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 -c "
import yaml, sys

def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)

def get_workflow_inputs(data):
    for k in data:
        if k is True or k == 'on':
            return data[k].get('workflow_call', {}).get('inputs', {})
    return {}

errors = []

PAIRS = [
    ('claude-caller.yml', 'claude.yml'),
    ('codex-caller.yml', 'codex.yml'),
    ('relay-claude.yml', 'relay.yml'),
    ('relay-codex.yml', 'relay.yml'),
]

for caller_name, reusable_name in PAIRS:
    caller = load_yaml(f'$REPO_ROOT/.github/workflows/{caller_name}')
    reusable = load_yaml(f'$REPO_ROOT/.github/workflows/{reusable_name}')
    inputs = get_workflow_inputs(reusable)
    required = {k for k, v in inputs.items() if v.get('required')}

    for job_name, job in caller.get('jobs', {}).items():
        with_params = job.get('with', {})
        if not with_params:
            continue

        # Every with: key must exist in reusable inputs
        for param in with_params:
            if param not in inputs:
                errors.append(f'{caller_name} job \"{job_name}\": passes \"{param}\" but {reusable_name} has no such input')

        # Every required input must be provided
        for req in sorted(required):
            if req not in with_params:
                errors.append(f'{caller_name} job \"{job_name}\": missing required input \"{req}\"')

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
"

echo "ok"
