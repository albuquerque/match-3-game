#!/usr/bin/env python3
"""
Validate a flow JSON against the experience_flow schema and check effects registry.
Usage: python3 tools/validate_flow.py data/experience_flows/test_definition_flow.json
"""
import json, sys
from pathlib import Path
from jsonschema import Draft7Validator

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / 'docs' / 'schemas' / 'experience_flow.json'
REGISTRY = ROOT / 'data' / 'effects' / 'effects_registry.json'
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'

if len(sys.argv) < 2:
    print('Usage: validate_flow.py <flow.json>')
    sys.exit(2)

flow_path = Path(sys.argv[1])
if not flow_path.exists():
    print(f'Flow file not found: {flow_path}')
    sys.exit(2)

schema = json.loads(SCHEMA.read_text())
validator = Draft7Validator(schema)
flow = json.loads(flow_path.read_text())

# Schema validation
errors = list(validator.iter_errors(flow))
if errors:
    print('Schema validation errors:')
    for e in errors:
        print(' -', e.message, 'at', list(e.path))
else:
    print('Schema: OK')

# definition_id presence checks
missing_defs = []
for i, node in enumerate(flow.get('flow', [])):
    def_id = node.get('definition_id')
    if def_id and not (DEFS_DIR / f"{def_id}.json").exists():
        missing_defs.append((i, def_id))
if missing_defs:
    print('Missing flow_step_definitions for definition_id:')
    for idx, did in missing_defs:
        print(f' - node index {idx}: {did}')
else:
    print('Definition files: OK')

# registry checks
registry = {}
if REGISTRY.exists():
    reg = json.loads(REGISTRY.read_text())
    for e in reg.get('effects', []):
        registry[e['id']] = e

invalid_effects = []
for i, node in enumerate(flow.get('flow', [])):
    md = node.get('metadata', {})
    effs = []
    if isinstance(md, dict) and isinstance(md.get('effects'), list):
        effs.extend(md['effects'])
    if 'effect' in node:
        effs.append(node['effect'])
    for eff in effs:
        if not isinstance(eff, dict) or 'type' not in eff:
            invalid_effects.append((i, eff, 'malformed'))
            continue
        etype = eff['type']
        if etype not in registry:
            invalid_effects.append((i, eff, 'unknown_type'))
            continue
        # loose type checks from registry params
        r = registry[etype]
        params = eff.get('params', {})
        for pkey, pdef in r.get('params', {}).items():
            if pdef['type'] == 'number' and pkey in params and not isinstance(params[pkey], (int, float)):
                invalid_effects.append((i, eff, f'param {pkey} expected number'))
            if pdef['type'] == 'integer' and pkey in params and not isinstance(params[pkey], int):
                invalid_effects.append((i, eff, f'param {pkey} expected integer'))

if invalid_effects:
    print('Invalid effects found:')
    for idx, e, reason in invalid_effects:
        print(f' - node {idx}: reason={reason}, effect={e}')
else:
    print('Effects: OK (registry checks)')

print('Validation complete')
