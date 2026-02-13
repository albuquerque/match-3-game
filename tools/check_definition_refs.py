#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'
FLOWS_DIR = ROOT / 'data' / 'experience_flows'

ok = True
for f in FLOWS_DIR.glob('*.json'):
    data = json.loads(f.read_text())
    for idx, node in enumerate(data.get('flow', [])):
        def_id = node.get('definition_id')
        if def_id:
            path = DEFS_DIR / f"{def_id}.json"
            if not path.exists():
                print(f"Missing definition {def_id} referenced in {f.name} at index {idx}")
                ok = False

if ok:
    print('All definition references resolved')
else:
    print('Some references are missing')
