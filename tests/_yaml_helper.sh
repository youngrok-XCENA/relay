#!/usr/bin/env bash
# Shared YAML parsing helpers using python3 stdlib.
# Source this file, do not execute directly.

_yaml_python() {
  python3 -c "
import yaml, sys, json

def resolve_on_key(data):
    \"\"\"YAML 'on' key becomes True in python yaml parser.\"\"\"
    for k in data:
        if k is True or k == 'on':
            return data[k]
    return None

def navigate(data, path):
    parts = path.split('.')
    for p in parts:
        if p == 'on':
            data = resolve_on_key(data)
        elif isinstance(data, dict):
            data = data.get(p)
        else:
            return None
        if data is None:
            return None
    return data

action = sys.argv[1]
filepath = sys.argv[2]

with open(filepath) as f:
    data = yaml.safe_load(f)

if action == 'validate':
    sys.exit(0)

path = sys.argv[3] if len(sys.argv) > 3 else ''
node = navigate(data, path) if path else data

if action == 'keys':
    if isinstance(node, dict):
        for k in node:
            print(k)
    else:
        sys.exit(1)
elif action == 'value':
    if node is not None:
        print(node)
    else:
        sys.exit(1)
elif action == 'has_key':
    key = sys.argv[4]
    if isinstance(node, dict) and key in node:
        sys.exit(0)
    else:
        sys.exit(1)
elif action == 'json':
    print(json.dumps(node))
" "$@"
}

yaml_parse() {
  _yaml_python validate "$1"
}

yaml_keys() {
  _yaml_python keys "$1" "$2"
}

yaml_value() {
  _yaml_python value "$1" "$2"
}

yaml_has_key() {
  _yaml_python has_key "$1" "$2" "$3"
}

yaml_json() {
  _yaml_python json "$1" "$2"
}
