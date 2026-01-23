# Board Flipping Bug - Critical Fix

## Issue
Every move was flipping the board vertically - tiles would reverse their positions in each column after any match or swap.

## Root Cause

**Collection Order Mismatch**

In the `animate_gravity()` function:
- **Collection:** Tiles were collected from TOP to BOTTOM (y: 0 → HEIGHT)
- **Assignment:** Tiles were assigned from BOTTOM to TOP (y: HEIGHT → 0)
- **Result:** This reversed the order of tiles in the column!

### Visual Example

```
Column before gravity:
Position:  [0,   1,   2,   3,   4]
Tiles:     [Red, Blue, Green, null, null]
Grid after gravity: [0, 0, Red, Blue, Green]

WRONG CODE (Top-to-bottom collection):
Collected array: [Red, Blue, Green]  ← Collected top to bottom

Assign bottom-to-top:
Position 4 ← Collected[0] = Red    (WRONG! Should be Green)
Position 3 ← Collected[1] = Blue   (Correct by chance)
Position 2 ← Collected[2] = Green  (WRONG! Should be Red)

Result: [null, null, Green, Blue, Red]  ← FLIPPED! ❌
```

## The Fix

**Match collection order to assignment order - both BOTTOM to TOP**

```gdscript
# BEFORE (WRONG):
for y in range(GameManager.GRID_HEIGHT):  # Top to bottom
    if tiles[x][y] != null:
        visual_tiles_in_column.append(tiles[x][y])

# AFTER (CORRECT):
for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):  # Bottom to top
    if tiles[x][y] != null:
        visual_tiles_in_column.append(tiles[x][y])
```

### Why This Works

```
Column before gravity:
Position:  [0,   1,   2,   3,   4]
Tiles:     [Red, Blue, Green, null, null]
Grid after gravity: [0, 0, Red, Blue, Green]

CORRECT CODE (Bottom-to-top collection):
Collected array: [Green, Blue, Red]  ← Collected bottom to top

Assign bottom-to-top:
Position 4 ← Collected[0] = Green  ✓ Correct!
Position 3 ← Collected[1] = Blue   ✓ Correct!
Position 2 ← Collected[2] = Red    ✓ Correct!

Result: [null, null, Red, Blue, Green]  ← Correct order! ✓
```

## Code Change

**File:** `scripts/GameBoard.gd`
**Function:** `animate_gravity()`
**Line:** ~648

```gdscript
# Changed from:
for y in range(GameManager.GRID_HEIGHT):

# To:
for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
```

**Added comment:**
```gdscript
# IMPORTANT: Collect from BOTTOM to TOP to match assignment order
```

## Testing Results

### Before Fix:
- ❌ Every match flipped the column vertically
- ❌ Red, Blue, Green → became Green, Blue, Red
- ❌ Board looked completely scrambled after moves
- ❌ Impossible to play the game properly

### After Fix:
- ✅ Tiles maintain correct positions
- ✅ Gravity moves tiles down naturally
- ✅ No vertical flipping
- ✅ Game plays normally

## Lessons Learned

**Critical principle for collect-and-redistribute patterns:**

When collecting items from an array and redistributing them to the same or different positions:
1. The collection order MUST match the assignment order
2. Or explicitly reverse the array between collection and assignment
3. Document which direction you're iterating (top-down vs bottom-up)

**In this case:**
- Assignment is BOTTOM to TOP (y: HEIGHT-1 → 0)
- Therefore collection MUST also be BOTTOM to TOP
- Any mismatch causes reversal/flipping

## Related Issues

This bug was introduced when rewriting the gravity system to fix:
- Overlapping tiles
- Empty blocks on board
- Tiles floating upward

The fix for those issues introduced this new bug due to the collection order not being carefully considered.

## Prevention

To prevent similar issues:
1. ✅ Add comments documenting iteration direction
2. ✅ Add visual examples in code comments
3. ✅ Test with distinctive tile patterns to catch reversal bugs
4. ✅ Use consistent iteration direction throughout function
5. ✅ Consider using helper functions that enforce direction

## Files Modified

**`scripts/GameBoard.gd`:**
- `animate_gravity()` - Line ~648
  - Changed collection loop from top-to-bottom to bottom-to-top
  - Added comment explaining why order matters

**`docs/GRAVITY_SYSTEM_REWRITE.md`:**
- Added critical warning about collection order
- Added visual example showing why order matters
- Updated implementation code to show correct order
