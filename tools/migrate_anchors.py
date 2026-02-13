#!/usr/bin/env python3
"""
Migrate narrative stage files from plural 'anchors' (array) to singular 'anchor' (string).
Creates a backup `<file>.json.bak` before overwriting.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NS_DIR = ROOT / 'data' / 'narrative_stages'

if not NS_DIR.exists():
    print(f"Narrative stages directory not found: {NS_DIR}")
    raise SystemExit(1)

updated = []
for p in sorted(NS_DIR.glob('*.json')):
    text = p.read_text()
    try:
        data = json.loads(text)
    except Exception as e:
        print(f"Skipping {p.name}: failed to parse JSON: {e}")
        continue

    if 'anchors' in data:
        anchors = data.get('anchors')
        if isinstance(anchors, list) and len(anchors) > 0:
            anchor = anchors[0]
            if len(anchors) > 1:
                print(f"Warning: {p.name} had multiple anchors {anchors}; using first: {anchor}")
        else:
            # empty or invalid -> set to empty string and warn
            anchor = ""
            print(f"Warning: {p.name} had non-list or empty 'anchors'; setting anchor to empty string")

        # Backup original
        bak = p.with_name(p.name + '.bak')
        bak.write_text(text)

        # Remove plural and set singular
        data.pop('anchors', None)
        data['anchor'] = anchor

        # Write back pretty JSON
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
        print(f"Migrated {p.name}: anchors -> anchor='{anchor}' (backup: {bak.name})")
        updated.append(p.name)
    else:
        print(f"No anchors in {p.name}; skipping")

print('\nMigration complete. Files updated:')
for n in updated:
    print(' -', n)
if not updated:
    print(' (none)')
