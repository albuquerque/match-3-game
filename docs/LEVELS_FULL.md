# Levels — Consolidated Guide

This document consolidates level file format, level loading, and related notes.

## Level JSON format
- Each level file is a JSON structure describing board layout, moves, target, blocked cells, and metadata (name/description)
- Example:
```json
{
  "level_number": 1,
  "name": "First Light",
  "moves": 20,
  "target": 500,
  "layout": [
    [0,0,0,0,0,0,0,0],
    ...
  ]
}
```

## Level loading
- `LevelManager.gd` loads levels from `levels/` and exposes `get_level(index)` and `current_level_index`
- Exclude non-level files like `world_map.json` from level loading

## Tips for designers
- Gate special tiles with board layout values (>0 means blocked/absent)
- Use `description` field to display on StartPage and WorldMap

## Testing
- Validate JSON files with a linter (ensure arrays are consistent)
- Use `LevelManager.load_all_levels()` debug outputs to verify

Date: 2026-01-19
