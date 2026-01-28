# Unmovable Hard Tiles - ✅ FULLY IMPLEMENTED

## Overview

Unmovable Hard tiles are multi‑hit obstacles implemented on the existing `Tile` class (no new classes).
They act as durable blockers (rocks, metal crates, ice blocks) that require multiple hits to break. When destroyed they can either:
- play a destruction effect (particles/sound), and/or
- reveal another tile type or a collectible (optional).

**Status**: Fully functional and tested. All features working correctly.

Design goals:
- ✅ Implement as metadata on the existing `Tile` (no new runtime classes).
- ✅ Allow level authors to specify number of hits, material type and optional multi‑stage textures.
- ✅ Keep gameplay semantics consistent with existing unmovable/blocked cells (they block gravity and swaps).
- ✅ Proper hit tracking - Tile instance manages its own hit counter
- ✅ Support for collectible and tile reveals on destruction
- ✅ Gravity works correctly after destruction/reveal

---

## Level layout encoding

Hard unmovables are encoded inline in level layout strings using the token:

```
H{hits}:{type}
```

Where:
- `hits` is a positive integer (1, 2, 3, ...)
- `type` is a short string name describing the material (e.g. `rock`, `metal`, `ice`)

Examples (4×4 snippet):

```
0000
0 H2:rock 0 0
0000
0000
```

Notes:
- Layout rows are newline separated. Cells may be space‑separated, comma separated or compact per the level format used by the project.
- The `U` token (legacy unmovable soft) remains supported as shorthand for a single‑hit unmovable; it is mapped internally to the same representation as `H1:<default_type>`.

---

## JSON fields supported in level data

In addition to the `layout` string, levels may include optional maps to describe per‑type assets and reveal behavior:

- `hard_textures` (dictionary) — maps a hard type name to an array of texture names or relative paths used for damage stages.
  - Example:

```json
"hard_textures": {
  "rock": ["unmovable_hard_rock_0.svg", "unmovable_hard_rock_1.svg"],
  "ice": ["unmovable_hard_ice_0.svg", "unmovable_hard_ice_1.svg", "unmovable_hard_ice_2.svg"]
}
```

- `hard_reveals` (dictionary) — optional mapping that defines what a hard tile reveals on destroy.
  - Example:

```json
"hard_reveals": {
  "ice": { "type": "collectible", "value": "gem" },
  "crate": { "type": "tile", "value": 3 }
}
```

- `unmovable_type` (string) — level default type used by `U` tokens where no explicit type is provided.

The level loader attaches `hard_textures` and `hard_reveals` entries to the runtime `unmovable_map` for tiles that are hard unmovables.

---

## Runtime representation

When a hard unmovable is encountered in the level layout the loader creates a `unmovable_map` entry keyed by `"x,y"` with the following structure:

```gdscript
{
  "hits": <int>,        # remaining hits
  "type": "rock",     # material id
  "hard": true,        # hard flag
  "textures": [ ... ], # (optional) attached from hard_textures
  "reveals": { ... }   # (optional) attached from hard_reveals
}
```

For `U` tokens the loader creates the same structure but with `"hard": false` and `hits = 1` (soft behavior).

The tile cell in the grid uses the same sentinel value as soft unmovables so matching/gravity logic remains consistent. Visual differences are driven by `unmovable_map` metadata.

---

## Tile API (what level code / engine calls)

All interactions occur on the existing `Tile` instance API:

- `configure_unmovable_hard(hits: int, h_type: String = "rock", textures: Array = [], reveals: Dictionary = {})`
  - Initialize the tile visuals and state for a hard unmovable. Called by `GameBoard` when instancing the visual grid.

- `take_hit(amount: int = 1) -> bool`
  - Applies damage. Returns `true` if the tile was destroyed by this hit.
  - On destruction the implementation will:
    - play destruction particles/sound,
    - if `reveals` defined: transform into the target (collectible or tile) via `configure_collectible()` or `update_type()`;
    - otherwise emit `unmovable_destroyed` signal so `GameManager`/`GameBoard` can proceed.

- `update_visual()` (internal) — tile uses `hard_textures` or a naming convention (see below) to pick the correct sprite per damage stage. The code no longer renders an on‑tile numeric counter; the texture communicates state.

---

## Asset and naming conventions

Recommended asset locations and fallback order:

1. If `hard_textures` is supplied in level JSON with explicit paths, the tile will use those.
2. Theme-aware fallback naming (preferred): `res://textures/{theme}/unmovable_hard_{type}_{stage}.svg` or `.png`.
   - `{stage}` indexes start at 0 for full health, up to `max_hits - 1` for broken state.
3. Single-image fallback (no stage): `res://textures/{theme}/unmovable_hard_{type}.svg`.
4. Legacy soft fallback: `res://textures/{theme}/unmovable_soft_{type}.svg`.

Examples (theme=modern):
- `res://textures/modern/unmovable_hard_rock_0.svg`
- `res://textures/modern/unmovable_hard_rock_1.svg`
- `res://textures/modern/unmovable_hard_rock.svg` (single stage fallback)

When adding new types, place icons for both `legacy` and `modern` themes to maintain consistent visuals across themes.

---

## Level generator guidance

- The project includes a level generator script `tools/level_generator.py`. When producing levels that contain hard unmovables:
  - Emit tokens as `Hn:type` in the layout string.
  - Populate `hard_textures[type]` with the ordered array of texture names (stage 0..N).
  - If a reveal behavior is desired, populate `hard_reveals[type]` with `{"type":"collectible","value":"coin"}` or `{"type":"tile","value":3}`.

Constraints for playability:
- Avoid placing unmovables where no adjacent matches are possible. The generator should validate level solvability and ensure at least one 3‑in‑a‑row opportunity exists to break nearby unmovables when necessary.
- Do not place hard unmovables on the bottommost active cell at level start; collectibles and unmovables spawn/placement rules expect space above to allow gravity behavior.

---

## Implementation Notes

### Hit Tracking Architecture

The final working implementation uses a **single source of truth** for hit tracking:

- **Tile Instance**: The `Tile` class manages its own `hard_hits` counter and is the authoritative source
- **GameManager**: For hard tiles, GameManager calls `take_hit()` on every adjacent match and trusts the tile's return value
- **No Dual Tracking**: GameManager's `unmovable_map` is NOT used for hard tiles (only for soft unmovables)

This architecture ensures:
1. Hard tiles take exactly the number of hits specified in the layout (H1=1 hit, H2=2 hits, etc.)
2. No off-by-one errors or double-counting
3. Clean separation between soft and hard unmovable tracking

### Key Code Flow

When a match occurs adjacent to a hard unmovable:

1. **GameManager.remove_matches()**: Detects adjacent unmovable at position
2. **Check tile type**: Determines if it's a hard unmovable via `tile.is_unmovable_hard`
3. **For hard tiles**: Always call `tile.take_hit(1)`, regardless of any counters
4. **Tile.take_hit()**: 
   - Decrements `hard_hits`
   - Updates texture to show damage progression
   - If `hard_hits == 0`: destroys tile and transforms if reveal is configured
   - Returns `true` if destroyed, `false` if still has hits remaining
5. **GameManager**: If destroyed, schedules gravity and handles reveal (collectible/tile)
6. **Gravity**: Collectibles fall down like normal tiles, get collected at bottom

### Testing

Test levels:
- **level_40.json**: H2:ice that reveals a gem collectible (requires 2 hits)
- **level_41.json**: H2:crate that reveals a normal tile (requires 2 hits)
- **levels 51-60**: Auto-generated levels with various hard unmovable configurations

All features tested and confirmed working:
- ✅ Correct hit count (2 hits for H2, 1 hit for H1, etc.)
- ✅ Texture progression through damage stages
- ✅ Collectible reveals work correctly
- ✅ Normal tile reveals work correctly
- ✅ Gravity applies properly after destruction
- ✅ No tile overlapping or duplication
- ✅ Collectibles get collected at bottom row

---

## Backwards compatibility

- Existing `U` tokens are preserved and mapped to the unified `unmovable_map` format as `H1:<level.default_unmovable_type>` equivalent (internally `U` is treated as a shorthand for `H1` with the default type). Levels using `U` will automatically benefit from hard unmovable features without changes.
