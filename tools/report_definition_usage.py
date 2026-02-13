#!/usr/bin/env python3
import json
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'
FLOWS_DIR = ROOT / 'data' / 'experience_flows'

# Gather definitions
defs = {p.stem: json.loads(p.read_text()) for p in DEFS_DIR.glob('*.json')}

# Map usages
usage = defaultdict(list)
for f in FLOWS_DIR.glob('*.json'):
    data = json.loads(f.read_text())
    for idx, node in enumerate(data.get('flow', [])):
        def_id = node.get('definition_id')
        if def_id:
            usage[def_id].append((f.name, idx, node))

# Print report
print('Flow Step Definitions Usage Report')
print('Definitions found: ', len(defs))
print('Flows scanned: ', len(list(FLOWS_DIR.glob('*.json'))))
print('')

# List used definitions
used = set(usage.keys())
for d in sorted(used):
    print(f"Definition: {d} - used {len(usage[d])} times")
    for (fname, idx, node) in usage[d]:
        print(f"  - {fname} @ index {idx} (node id: {node.get('id')})")
    print('')

# List unused definitions
unused = set(defs.keys()) - used
if unused:
    print('Unused definitions:')
    for d in sorted(unused):
        print('  -', d)
else:
    print('No unused definitions found')

# Quick suggestions
if unused:
    print('\nSuggestion: remove or consolidate unused definitions in data/flow_step_definitions/')

print('\nReport complete')
