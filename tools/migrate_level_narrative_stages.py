#!/usr/bin/env python3
"""
Move level_* narrative stage JSONs into data/narrative_stages/levels/
Creates the target directory if missing. Creates a .bak copy for safety.
"""
import json
from pathlib import Path
from shutil import copy2

ROOT = Path(__file__).resolve().parents[1]
NS_DIR = ROOT / 'data' / 'narrative_stages'
TARGET_DIR = NS_DIR / 'levels'

if not NS_DIR.exists():
    print(f"Narrative stages directory not found: {NS_DIR}")
    raise SystemExit(1)

TARGET_DIR.mkdir(parents=True, exist_ok=True)

moved = []
for p in sorted(NS_DIR.glob('level_*.json')):
    if p.parent == TARGET_DIR:
        continue
    dest = TARGET_DIR / p.name
    bak = p.with_suffix(p.suffix + '.bak')
    print(f"Backing up {p} -> {bak}")
    copy2(str(p), str(bak))
    print(f"Moving {p} -> {dest}")
    copy2(str(p), str(dest))
    p.unlink()
    moved.append(dest.name)

print(f"Moved {len(moved)} files to {TARGET_DIR}")
if moved:
    for m in moved:
        print(" - ", m)
