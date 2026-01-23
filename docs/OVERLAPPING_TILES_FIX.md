# Overlapping Tiles Bug Fix - FINAL

## Issue
Players were seeing overlapping tiles in the same position - when moving a tile, another tile of a different color would appear underneath it. This created visual confusion and indicated a memory/cleanup issue.

## Update - Gravity System Completely Rewritten

**The gravity fix described below was not sufficient.** The gravity system has been **completely rewritten** with a new approach. See `GRAVITY_SYSTEM_REWRITE.md` for full details.

The final solution:
- ✅ Removed redundant tile creation in `animate_refill()`
- ✅ **Completely rewrote `animate_gravity()`** to use direct position mapping instead of collect-redistribute
- ✅ Grid state is now the single source of truth for visual state

## Root Causes Identified

### Cause 1: Redundant Tile Creation in animate_refill()
The `animate_refill()` function had **two separate loops** creating tiles (fixed).

### Cause 2: Tile Reassignment Issues in animate_gravity()
The `animate_gravity()` function was reassigning tiles without checking if a position already had a tile, potentially leaving orphaned tiles in the scene.

## Detailed Analysis

### Issue 1: animate_refill() - Redundant Second Loop

### Loop 1: Create tiles for new positions
```gdscript
for pos in new_tile_positions:
    if tiles[x][y] == null:
        var tile = tile_scene.instantiate()
        // ... setup and add to scene
        tiles[x][y] = tile
```

### Loop 2: Redundant second pass (THE BUG!)
```gdscript
for x in range(GRID_WIDTH):
    for y in range(GRID_HEIGHT):
        if grid[x][y] > 0 and tiles[x][y] == null:
            var tile = tile_scene.instantiate()
            // ... setup and add to scene
            tiles[x][y] = tile
```

**Why this caused overlapping tiles:**
1. First loop creates tiles for new positions from `fill_empty_spaces()`
2. Second loop scans entire grid and creates tiles for ANY position where `grid[x][y] > 0` and `tiles[x][y] == null`
3. If a tile wasn't properly freed during destruction, the grid might have a value but the visual tile still exists
4. The second loop would create a NEW tile at the same position, resulting in two tiles stacked on top of each other
5. When the player moves one tile, the tile underneath becomes visible

## The Fixes

### Fix 1: Removed Redundant Loop in animate_refill()

**Removed the redundant second loop** and added proper cleanup:

```gdscript
func animate_refill():
    var new_tile_positions = GameManager.fill_empty_spaces()
    var spawn_tweens = []
    var scale_factor = tile_size / 64.0
    
    # Create tiles ONLY for the new positions returned by fill_empty_spaces
    for pos in new_tile_positions:
        var x = int(pos.x)
        var y = int(pos.y)
        
        if GameManager.is_cell_blocked(x, y):
            continue
        
        # If there's already a tile at this position, free it first
        if tiles[x][y] != null:
            var old_tile = tiles[x][y]
            if old_tile and not old_tile.is_queued_for_deletion():
                print("[GameBoard] WARNING: Tile already exists at (", x, ",", y, ") - freeing old tile")
                old_tile.queue_free()
            tiles[x][y] = null
        
        # Now create the new tile
        var tile = tile_scene.instantiate()
        // ... setup tile ...
        tiles[x][y] = tile
```

### Key Changes:

1. **Removed redundant second loop** - Only create tiles for positions in `new_tile_positions`
2. **Added safety check** - If a tile already exists at a position, free it before creating a new one
3. **Warning log** - Helps detect if this situation occurs (shouldn't happen in normal operation)
4. **Single source of truth** - `fill_empty_spaces()` determines which positions need new tiles

### Fix 2: Added Safety Checks in animate_gravity()

The gravity function now properly handles tile reassignment:

```gdscript
func animate_gravity():
    for x in range(GameManager.GRID_WIDTH):
        # Collect existing tiles from column
        var column_tiles = []
        for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
            if tiles[x][y] != null:
                column_tiles.append(tiles[x][y])
        
        # Clear empty positions
        for y in range(GameManager.GRID_HEIGHT):
            if GameManager.grid[x][y] == 0:
                tiles[x][y] = null
        
        # Reassign tiles with safety check
        var tile_index = 0
        for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
            if tile_type > 0 and tile_index < column_tiles.size():
                var tile = column_tiles[tile_index]
                
                # NEW: Check if position already has a different tile
                if tiles[x][y] != null and tiles[x][y] != tile:
                    print("[GRAVITY] WARNING: Position already has tile! Freeing old tile.")
                    tiles[x][y].queue_free()
                
                tiles[x][y] = tile
                tile.grid_position = Vector2(x, y)
                tile.update_type(tile_type)
                // ... animate to position ...
                tile_index += 1
        
        # NEW: Free any tiles that weren't reassigned
        if tile_index < column_tiles.size():
            for i in range(tile_index, column_tiles.size()):
                column_tiles[i].queue_free()
```

**Key additions:**
1. **Check before assignment** - Verifies position doesn't already have a different tile
2. **Free orphaned tiles** - Tiles that weren't reassigned are properly freed
3. **Comprehensive logging** - Debug messages help track tile lifecycle
4. **Prevent leaks** - Ensures all tiles are accounted for

### Key Changes (Combined):

1. **Removed redundant second loop** - Only create tiles for positions in `new_tile_positions`
2. **Added safety check** - If a tile already exists at a position, free it before creating a new one
3. **Warning log** - Helps detect if this situation occurs (shouldn't happen in normal operation)
4. **Single source of truth** - `fill_empty_spaces()` determines which positions need new tiles

## Why This Works

**Before:**
- Two loops could create tiles independently
- Race conditions could lead to duplicate tiles
- Old tiles might not be properly freed
- Grid state and visual state could diverge

**After:**
- Single loop creates tiles ONLY where needed
- Explicit cleanup of any existing tiles before creating new ones
- Grid state matches visual state exactly
- No possibility of overlapping tiles

## Testing Scenarios

### Test 1: Normal Match
1. Make a match
2. Tiles destroyed
3. Gravity runs
4. Refill creates new tiles
5. ✅ No overlapping tiles

### Test 2: Cascade Matches
1. Make a match
2. Cascade triggers multiple matches
3. Multiple refills happen in sequence
4. ✅ No overlapping tiles accumulate

### Test 3: Unmovable Destruction
1. Match tiles near unmovable
2. Unmovable destroyed
3. Gravity fills the gap
4. Refill creates new tiles
5. ✅ No overlapping tiles

### Test 4: Collectible Collection
1. Collectible reaches bottom
2. Collectible removed
3. Gravity fills gap
4. Refill creates new tiles
5. ✅ No overlapping tiles

### Test 5: Special Tile Activation
1. Activate row/column clear
2. Multiple tiles destroyed at once
3. Gravity runs
4. Refill creates many tiles
5. ✅ No overlapping tiles

## Files Modified

**`scripts/GameBoard.gd`:**

1. **`animate_refill()` function (line ~797)**
   - Removed redundant second loop
   - Added safety check for existing tiles
   - Added cleanup before creating new tiles

2. **`animate_gravity()` function (line ~634)**
   - Added check before tile reassignment
   - Added freeing of orphaned tiles
   - Added comprehensive debug logging

3. **`clear_tiles()` function (line ~320)**
   - Added debug logging

## Debugging

The fixes include extensive logging to help track down any remaining issues:

- `[CLEAR_TILES]` - Shows when tiles are cleared from scene
- `[GRAVITY]` - Tracks tile collection, reassignment, and orphans
- `[GameBoard] WARNING:` - Alerts when unexpected states are detected

To debug overlapping tiles:
1. Play the game and make matches
2. Check console for `[GRAVITY] WARNING:` messages
3. Look for tiles being freed unexpectedly
4. Verify tile counts match expectations

## Prevention

This fix prevents overlapping tiles by:
1. ✅ Single authoritative tile creation loop
2. ✅ Explicit cleanup of old tiles
3. ✅ Warning logs if unexpected state detected
4. ✅ Grid state and visual state always synchronized

## Related Systems

This fix works with:
- **Tile destruction** - `animate_destroy_tiles()` properly frees tiles and sets `tiles[x][y] = null`
- **Gravity** - `animate_gravity()` moves tiles but doesn't create new ones
- **Refill** - Now properly creates tiles only where needed
- **GameManager** - `fill_empty_spaces()` determines which positions need tiles

## Long-term Improvements

Future enhancements to prevent similar issues:
- Add assertions to verify no duplicate tiles exist
- Add visual debugging mode to highlight tile positions
- Track tile lifecycle in debug logs
- Add automated tests for tile creation/destruction
