#!/usr/bin/env python3
"""
Simple migration tool:
- Scans data/experience_flows/*.json
- Finds repeated `narrative_stage` nodes that share the same properties (excluding `id` and `type`)
- Creates definitions under data/flow_step_definitions/
- Replaces occurrences in the flow files with compact nodes referencing `definition_id`
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLOWS_DIR = ROOT / 'data' / 'experience_flows'
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'
DEFS_DIR.mkdir(parents=True, exist_ok=True)

FLOW_FILES = list(FLOWS_DIR.glob('*.json'))

# Threshold for extracting a definition
THRESHOLD = 3

# helper
def normalize_props(node):
    # Return normalized dict of properties excluding id and type
    return {k: node[k] for k in sorted(node.keys()) if k not in ('id', 'type')}

# collect narrative nodes
groups = {}
occurrences = []
for f in FLOW_FILES:
    data = json.loads(f.read_text())
    flow = data.get('flow', [])
    for idx, node in enumerate(flow):
        if node.get('type') == 'narrative_stage':
            props = normalize_props(node)
            key = json.dumps(props, sort_keys=True)
            groups.setdefault(key, []).append((f, idx, node))

# create definitions for groups with count >= THRESHOLD
created_defs = {}
for key, items in groups.items():
    if len(items) >= THRESHOLD:
        props = json.loads(key)
        # build a safe id
        delay = props.get('auto_advance_delay')
        skippable = props.get('skippable')
        id_parts = ['narrative']
        if delay is not None:
            id_parts.append('auto_%s' % str(delay).replace('.', '_'))
        if skippable is not None:
            id_parts.append('skip_%s' % str(skippable).lower())
        def_id = '_'.join(id_parts)
        # ensure unique
        base = def_id
        i = 1
        while (DEFS_DIR / f"{def_id}.json").exists() or def_id in created_defs:
            def_id = f"{base}_{i}"
            i += 1
        # prepare definition content
        definition = dict(props)
        definition['id'] = def_id
        definition['type'] = 'narrative_stage'
        # write file
        path = DEFS_DIR / f"{def_id}.json"
        path.write_text(json.dumps(definition, indent=2))
        created_defs[key] = def_id
        print(f"Created definition: {path}")

# Apply replacements in flow files
for f in FLOW_FILES:
    data = json.loads(f.read_text())
    flow = data.get('flow', [])
    modified = False
    for idx, node in enumerate(flow):
        if node.get('type') == 'narrative_stage':
            props = normalize_props(node)
            key = json.dumps(props, sort_keys=True)
            if key in created_defs:
                def_id = created_defs[key]
                # replace node with compact reference
                new_node = {'definition_id': def_id, 'id': node.get('id'), 'type': 'narrative_stage'}
                flow[idx] = new_node
                modified = True
                print(f"Updated {f.name} node idx {idx} -> definition_id {def_id}")
    if modified:
        # backup original
        bak = f.with_suffix(f"{f.suffix}.bak")
        if not bak.exists():
            bak.write_text(json.dumps(json.loads(f.read_text()), indent=2))
        f.write_text(json.dumps(data, indent=2))
        print(f"Patched flow file: {f}")

print('\nMigration complete.')
print(f'Created {len(created_defs)} definitions.')
