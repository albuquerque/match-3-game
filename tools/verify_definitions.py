#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'
FLOW_FILE = ROOT / 'data' / 'experience_flows' / 'test_definition_flow.json'

with open(FLOW_FILE) as f:
    flow = json.load(f)

print('Verifying flow:', flow.get('experience_id'))

for i, node in enumerate(flow.get('flow', [])):
    print('\nNode index', i, 'raw:', node)
    def_id = node.get('definition_id')
    if def_id:
        candidate = DEFS_DIR / f"{def_id}.json"
        if candidate.exists():
            d = json.loads(candidate.read_text())
            merged = dict(d)
            # inline override
            for k in node.keys():
                merged[k] = node[k]
            print('  -> Merged with', candidate.name, '=>', merged)
        else:
            print('  -> Definition file not found:', candidate)
    else:
        print('  -> No definition_id; node used as-is')

print('\nVerify complete')
