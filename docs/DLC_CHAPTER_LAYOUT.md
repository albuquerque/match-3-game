# DLC Chapter Layout and Packaging Guide

This document shows the exact folder layout the game expects for downloadable chapters (DLC), how the game discovers per-level narrative stages inside DLC, and an example chapter zip structure you can produce when building a DLC package.

Summary
- DLC chapters are extracted to: `user://dlc/chapters/<chapter_id>/`
- The `AssetRegistry` autoload scans `AssetRegistry.DLC_BASE_DIR` (default `user://dlc/chapters/`) for installed chapters.
- Per-level narrative stages inside a chapter may be placed at any of these paths (the code searches them in this order):
  - `levels/level_<N>.json`
  - `stages/level_<N>.json`
  - `narrative_stages/levels/level_<N>.json`

What to include in a chapter
- `manifest.json` — mandatory. Contains metadata and an `assets` map that `AssetRegistry` will load.
- `stages/` or `levels/` — optional. Put per-level narrative JSON files here (e.g. `levels/level_63.json`).
- `assets/` — optional but recommended. Textures, particles, animations used by stages and other DLC content.
- Any other content (levels, audio, prefabs) under obvious subfolders.

Recommended chapter root structure (zip layout)

```
my_chapter.zip
├── manifest.json
├── assets/
│   ├── narrative/
│   │   ├── moses_full_sea.png
│   │   └── sea_parted.png
│   └── particles/
│       └── divine_light.json
├── stages/
│   └── exodus_sea_parting.json
├── levels/
│   └── level_63.json
└── docs/
    └── README.md
```

Notes on paths
- When `AssetRegistry` loads a chapter's `manifest.json`, relative asset paths in the manifest are converted to absolute `user://` paths by joining them with the chapter directory. For example:
  - Manifest contains: `"assets": { "textures": { "sea_parted": "assets/narrative/sea_parted.png" }}`
  - AssetRegistry will resolve to: `user://dlc/chapters/my_chapter/assets/narrative/sea_parted.png`
- Narrative stage files placed under `levels/level_<N>.json` (or the other candidate folders) will be discovered by `NarrativeStageManager._try_load_dlc_stage()` and loaded with the same renderer anchor rules as built-in stages.

Minimal manifest example
- See `docs/examples/chapter_manifest_example.json` for a simple manifest you can include in a chapter package.

How the game chooses per-level narrative for level N
1. `NarrativeStageManager.load_stage_for_level(N)` attempts to load `res://data/narrative_stages/levels/level_N.json` (bundled game content).
2. If not found, `_try_load_dlc_stage(N)` enumerates installed chapters and checks the candidate paths listed above inside each chapter directory. The first match wins.
3. When a DLC stage JSON is found it is parsed; its `anchor` value is set on the renderer before loading so DLC authors can target `top_banner`, `fullscreen`, etc.

Authoring tips
- Always include an `id` and `anchor` in your stage JSON.
- Use relative paths in the manifest `assets` mapping to make the chapter portable.
- Avoid placing multiple chapters that define the same `level_N` unless you intentionally want one to override another; chapter precedence is currently first-match.

Testing locally (developer)
- Create a folder at `user://dlc/chapters/test_chapter/` (your game can create it via `DirAccess.make_dir_recursive_absolute()`), place `manifest.json` and `levels/level_999.json` and start the game. Then call `NarrativeStageManager.load_stage_for_level(999)` from the debug console or a test scene.

Limitations & future improvements
- Current precedence is first-found; if you need predictable overriding, add a chapter-priority manifest or rely on `AssetRegistry` ordering.
- Ensure the DLC installation process writes files into `user://dlc/chapters/<chapter_id>/` — mismatched paths will make chapters invisible to the scan.

If you want, I can add a small automated test-scene that creates a `user://dlc/chapters/test_chapter/` folder and writes a sample `manifest.json` and `levels/level_999.json` to prove discovery works; say "yes" and I'll add it under `scenes/tests/`.
