#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 -c "
import yaml, sys, json

def load_workflow(path):
    with open(path) as f:
        data = yaml.safe_load(f)
    for k in data:
        if k is True or k == 'on':
            return data[k].get('workflow_call', {}).get('inputs', {})
    return {}

errors = []

CLAUDE_EXPECTED = {
    'mode', 'model', 'project_description', 'code_style_guide', 'build_command',
    'test_command', 'format_command', 'file_extensions', 'review_focus', 'max_turns',
    'max_prfix_turns', 'max_review_turns', 'max_diff_size', 'trigger_command',
    'title_keyword', 'trigger_label', 'branch_prefix', 'base_branch', 'bot_user',
    'bot_email', 'pr_template', 'timeout_minutes', 'check_wait_minutes',
    'check_poll_interval_seconds', 'max_check_fix_attempts', 'runner',
}

CODEX_EXPECTED = {
    'mode', 'model', 'project_description', 'build_command', 'test_command',
    'format_command', 'code_style_guide', 'file_extensions', 'review_focus',
    'max_diff_size', 'node_path', 'codex_sandbox', 'trigger_command', 'title_keyword',
    'auto_title_keyword', 'trigger_label', 'branch_prefix', 'base_branch', 'bot_user',
    'bot_email', 'pr_template', 'timeout_minutes', 'check_wait_minutes',
    'check_poll_interval_seconds', 'max_check_fix_attempts', 'runner',
}

REQUIRED = {'mode', 'project_description'}

for name, expected in [('claude.yml', CLAUDE_EXPECTED), ('codex.yml', CODEX_EXPECTED)]:
    inputs = load_workflow(f'$REPO_ROOT/.github/workflows/{name}')
    actual = set(inputs.keys())

    missing = expected - actual
    for m in sorted(missing):
        errors.append(f'{name}: missing input \"{m}\"')

    for req in sorted(REQUIRED):
        if req in inputs and not inputs[req].get('required'):
            errors.append(f'{name}: input \"{req}\" should be required')

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
"

echo "ok"
