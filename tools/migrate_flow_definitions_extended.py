#!/usr/bin/env python3
"""
Extended migration tool:
- Scans data/experience_flows/*.json
- Finds repeated nodes for target types (narrative_stage, reward, ad_reward, premium_gate)
- Creates definitions under data/flow_step_definitions/
- Replaces occurrences in the flow files with compact nodes referencing `definition_id`

Notes:
- Backups are made as .bak if not present.
- Uses exact match of node properties excluding 'id' and 'type' to group nodes.
"""
import json
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
FLOWS_DIR = ROOT / 'data' / 'experience_flows'
DEFS_DIR = ROOT / 'data' / 'flow_step_definitions'
DEFS_DIR.mkdir(parents=True, exist_ok=True)

FLOW_FILES = list(FLOWS_DIR.glob('*.json'))

# Types to consider for extraction
TARGET_TYPES = ['narrative_stage', 'reward', 'ad_reward', 'premium_gate']

# Threshold for extraction
THRESHOLD = 3

# Helper: normalize properties by removing id and type
def normalize_props(node):
    return {k: node[k] for k in sorted(node.keys()) if k not in ('id', 'type')}

# Collect groups
groups = defaultdict(list)
file_contents = {}
for f in FLOW_FILES:
    data = json.loads(f.read_text())
    file_contents[f] = data
    flow = data.get('flow', [])
    for idx, node in enumerate(flow):
        t = node.get('type')
        if t in TARGET_TYPES:
            props = normalize_props(node)
            key = (t, json.dumps(props, sort_keys=True))
            groups[key].append((f, idx, node))

created_defs = {}

for (t, key_props), items in groups.items():
    if len(items) >= THRESHOLD:
        props = json.loads(key_props)
        # create id
        id_parts = [t]
        # try to create compact id using notable properties
        if 'auto_advance_delay' in props:
            id_parts.append('auto_%s' % str(props['auto_advance_delay']).replace('.', '_'))
        if 'skippable' in props:
            id_parts.append('skip_%s' % str(props['skippable']).lower())
        if 'rewards' in props:
            # simple fingerprint based on first reward type
            try:
                first = props['rewards'][0]
                id_parts.append(first.get('type', 'reward'))
            except Exception:
                pass
        # fallback
        def_id = '_'.join(id_parts)
        base = def_id
        i = 1
        while (DEFS_DIR / f"{def_id}.json").exists() or def_id in created_defs.values():
            def_id = f"{base}_{i}"
            i += 1
        # build definition content
        definition = dict(props)
        definition['id'] = def_id
        definition['type'] = t
        # write file
        path = DEFS_DIR / f"{def_id}.json"
        path.write_text(json.dumps(definition, indent=2))
        created_defs[(t, key_props)] = def_id
        print(f"Created definition: {path}")

# Apply replacements
for f, data in file_contents.items():
    flow = data.get('flow', [])
    modified = False
    for idx, node in enumerate(flow):
        t = node.get('type')
        if t in TARGET_TYPES:
            props = normalize_props(node)
            key = (t, json.dumps(props, sort_keys=True))
            if key in created_defs:
                def_id = created_defs[key]
                new_node = {'definition_id': def_id, 'id': node.get('id'), 'type': t}
                # preserve any inline fields that differ from definition (should be none by design)
                # but keep the original id
                flow[idx] = new_node
                modified = True
                print(f"Updated {f.name} node idx {idx} -> definition_id {def_id}")
    if modified:
        bak = f.with_suffix(f"{f.suffix}.bak")
        if not bak.exists():
            bak.write_text(json.dumps(json.loads(f.read_text()), indent=2))
        f.write_text(json.dumps(data, indent=2))
        print(f"Patched flow file: {f}")

print('\nExtended migration complete.')
print(f'Created {len(created_defs)} definitions.')
