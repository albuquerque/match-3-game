# Collectibles System - Complete Guide

**Status**: ✅ Production Ready  
**Last Updated**: January 22, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [Level Configuration](#level-configuration)
4. [Mechanics](#mechanics)
5. [Implementation Details](#implementation-details)
6. [Adding New Collectible Types](#adding-new-collectible-types)
7. [Level Design Guidelines](#level-design-guidelines)
8. [Testing Checklist](#testing-checklist)

---

## Overview

The collectible system provides an alternative win condition for levels. Instead of reaching a target score, players must collect a specific number of items (coins, gems, stars, etc.). This adds variety and strategic depth to gameplay.

### Level Types

**Score-based levels** (`collectible_target: 0`)
- Win condition: Reach target score
- Example: "Reach 10000 points in 30 moves!"

**Collectible-based levels** (`collectible_target > 0`)
- Win condition: Collect all required collectibles
- Score is secondary (still tracked for rewards and stars)
- Example: "Collect 2 coins!"

---

## How It Works

### Dynamic Spawning

Collectibles are **not placed at level start**. Instead:
1. Layout uses 'C' markers to indicate **spawn columns**
2. During gameplay, collectibles spawn randomly from these columns
3. Spawn rate: 30% chance per empty cell in marked columns
4. Only spawns if collectible target not yet reached

### Collection Flow

```
1. Collectible spawns from top of marked column
2. Falls with gravity like regular tiles
3. Immune to special tile effects (lightning, row/column clear)
4. Reaches bottom row
5. Auto-collected with animation (particles + fly-to-UI)
6. Sound effect plays
7. Counter updates (e.g., "Coins: 1/2")
8. Gravity applied, new tiles fall
```

### Win/Lose Conditions

**Collectible Levels**:
- ✅ **Win**: Collect all required collectibles (even if score < target)
- ❌ **Lose**: Run out of moves before collecting all
- 🎉 **Bonus**: Remaining moves convert to special tiles after winning

**Score Levels**:
- ✅ **Win**: Reach target score
- ❌ **Lose**: Run out of moves before reaching score
- 🎉 **Bonus**: Remaining moves convert to special tiles after winning

---

## Level Configuration

### JSON Structure

```json
{
  "level_number": 1,
  "title": "Level 1",
  "description": "Collect 2 coins!",
  "grid_width": 8,
  "grid_height": 8,
  "target_score": 5000,
  "max_moves": 30,
  "num_tile_types": 6,
  "theme": "legacy",
  "layout": "0 0 0 C 0 0 0 0\n0 0 0 0 0 0 0 0\n...",
  "collectible_target": 2,
  "collectible_type": "coin"
}
```

### Field Definitions

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `collectible_target` | int | Number to collect (0 = score-based) | Yes |
| `collectible_type` | string | Type name (coin, gem, star, etc.) | No (default: "coin") |
| `layout` | string | Grid layout with 'C' for spawn columns | Yes |
| `description` | string | Level description shown to player | Yes |

### Layout Format

- `0` = Playable tile
- `X` = Blocked cell (no tile)
- `C` = Collectible spawn column marker
- `U` = Unmovable soft obstacle
- `H` = Unmovable hard obstacle

**Important**: Never place 'C' in the bottom row! The generator prevents this automatically.

### Example Layouts

**Simple Collectible Level**:
```json
"layout": "C 0 0 0 0 0 0 0\n0 0 0 0 0 0 0 0\n0 0 0 0 0 0 0 0\n..."
```
- 1 spawn column (left side)
- Collectibles will spawn from column 0

**Multi-Column Spawning**:
```json
"layout": "C 0 0 0 0 0 0 C\n0 0 0 0 0 0 0 0\n..."
```
- 2 spawn columns (left and right)
- Collectibles spawn from columns 0 and 7

---

## Mechanics

### Collectible Behavior

#### Spawning
- **When**: During refill after tiles are cleared
- **Where**: Columns marked with 'C' in layout
- **Chance**: 30% per empty cell in marked column
- **Condition**: Only if `collectibles_collected < collectible_target`

#### Movement
- Falls with gravity like regular tiles
- Can be swapped with adjacent tiles
- Does **NOT** participate in matches
- Cannot be cleared by matches

#### Special Tile Immunity
Collectibles are **immune** to:
- Horizontal arrow (row clear)
- Vertical arrow (column clear)
- Four-way arrow (cross clear)
- Bomb effects

When special tiles activate:
1. Collectibles in affected area are skipped
2. Other tiles are cleared normally
3. Collectibles fall to fill gaps
4. Continue falling until collected

#### Collection
When collectible reaches **bottom row**:
1. Auto-detected by `_check_collectibles_at_bottom()`
2. Marked as collected
3. Visual animation:
   - Particle burst (golden for coins)
   - Flies to UI counter (top-right)
   - Fades out during flight
4. Sound effect plays
5. Counter increments
6. Rewards 500 points
7. Removed from grid
8. Gravity applies immediately

### UI Display

The HUD automatically adapts:

**Collectible Level**:
```
Target: Coins: 3/5
Progress Bar: 60%
```

**Score Level**:
```
Target: Goal: 10000
Progress Bar: based on score
```

### Bonus Cascade

After level completion with moves remaining:
1. Each remaining move converts to special tile
2. Special tiles activate automatically
3. Collectibles are **excluded** from conversion targets
4. Points awarded: 100, 200, 300, etc. (progressive)
5. Player can skip with "Tap to skip" button

---

## Implementation Details

### Core Files

**GameManager.gd**
- Stores `collectible_target` and `collectible_type`
- Tracks `collectibles_collected` counter
- Spawns collectibles in `fill_empty_spaces()` (30% chance)
- Handles collection in `collectible_landed_at()`
- Checks win condition based on level type

**GameBoard.gd**
- Detects bottom-row collectibles in `_check_collectibles_at_bottom()`
- Configures collectible tiles during refill
- Skips collectibles in special tile activation
- Triggers collection animations

**LevelManager.gd**
- Loads `collectible_target` and `collectible_type` from JSON
- Stores in `LevelData` class
- Passes to GameManager on level load

**Tile.gd**
- Has `is_collectible` flag
- Stores `collectible_type` (e.g., "coin")
- Loads appropriate texture in `update_visual()`
- Visual tint: `Color(1, 0.95, 0.7)` (slight gold)

### Constants

```gdscript
# GameManager.gd
const COLLECTIBLE = 10  # Grid value for collectible tiles
const TILE_TYPES = 6    # Regular tile types (1-6)

# Spawning
const COLLECTIBLE_SPAWN_RATE = 0.3  # 30% chance
```

### Key Functions

**GameManager.fill_empty_spaces()**
```gdscript
# For each empty cell in grid:
if collectible_target > 0 and collectibles_collected < collectible_target:
    # Check if cell is in a collectible spawn column
    for cpos in collectible_positions:
        if int(cpos.x) == x:
            if randf() < 0.3:  # 30% chance
                grid[x][y] = COLLECTIBLE
```

**GameBoard._check_collectibles_at_bottom()**
```gdscript
# Check bottom row for collectibles
for x in range(GRID_WIDTH):
    var tile = tiles[x][bottom_row]
    if tile and tile.is_collectible:
        # Play animation, collect, update counter
        GameManager.collectible_landed_at(pos, type)
```

**Tile.configure_collectible()**
```gdscript
func configure_collectible(c_type: String):
    is_collectible = true
    collectible_type = c_type
    update_visual()  # Load appropriate texture
```

### Signals

```gdscript
signal collectibles_changed(collected, target)
```

Emitted when collectible count changes, used to update UI.

---

## Adding New Collectible Types

### Step 1: Create Textures

Add texture files to theme folders:
```
textures/legacy/gem.png   (or .svg)
textures/modern/gem.png   (or .svg)
```

**Texture Requirements**:
- Size: 64x64 pixels (will be scaled automatically)
- Format: PNG or SVG
- Transparent background recommended
- Clear, recognizable icon

### Step 2: Update Level JSON

```json
{
  "collectible_target": 3,
  "collectible_type": "gem",
  "description": "Collect 3 gems!"
}
```

### Step 3: Done!

The system automatically:
- Loads texture from theme folder
- Displays gems instead of coins
- Uses "gem" in logs and debugging
- No code changes required

### Texture Lookup Order

For `collectible_type: "gem"` and `theme: "legacy"`:
1. `res://textures/legacy/gem.svg` ← Try theme SVG first
2. `res://textures/legacy/gem.png` ← Try theme PNG
3. `res://textures/gem.svg` ← Fallback to root SVG
4. `res://textures/gem.png` ← Fallback to root PNG

### Collectible Type Ideas

- `coin` - Currency/money
- `gem` - Precious stones
- `star` - Achievement stars
- `heart` - Lives/health
- `key` - Unlock items
- `crystal` - Magic items
- `diamond` - Rare items
- `potion` - Power-ups

---

## Level Design Guidelines

### Best Practices

**Spawn Column Placement**
- 1-3 spawn columns for most levels
- Spread across board width (left, center, right)
- Avoid clustering all in one area
- Never in bottom row

**Target Balancing**
- **Early levels** (1-10): 1-2 collectibles
- **Mid levels** (11-30): 3-5 collectibles
- **Late levels** (31+): 5-8 collectibles
- Avoid more than 10 (too grindy)

**Moves Allocation**
- Provide 2-3x the collectible target in moves
- Example: 3 collectibles → 25-30 moves
- Account for RNG spawning luck
- More moves for complex layouts

**Board Layout**
- Ensure clear paths to bottom
- Avoid too many obstacles blocking fall
- Create strategy opportunities (funnels, bottlenecks)
- Mix with unmovable obstacles for challenge

### Example Good Level

```json
{
  "level_number": 15,
  "title": "Crystal Cave",
  "description": "Collect 4 gems!",
  "grid_width": 8,
  "grid_height": 8,
  "target_score": 8000,
  "max_moves": 35,
  "theme": "legacy",
  "layout": "C 0 0 0 0 0 0 C\n0 0 U 0 0 U 0 0\n0 0 0 0 0 0 0 0\n0 U 0 0 0 0 U 0\n0 0 0 C 0 0 0 0\n0 0 0 0 0 0 0 0\n0 0 U 0 0 U 0 0\n0 0 0 0 0 0 0 0",
  "collectible_target": 4,
  "collectible_type": "gem"
}
```

**Why it's good**:
- 3 spawn columns (varied positions)
- Unmovable obstacles create strategy
- 35 moves for 4 collectibles (8.75 moves/collectible)
- Clear paths to bottom
- Engaging theme

### Example Bad Level

```json
{
  "collectible_target": 10,
  "max_moves": 20,
  "layout": "C C C C C C C C\nX X X X X X X X\n..."
}
```

**Why it's bad**:
- Too many collectibles (10)
- Not enough moves (20)
- All spawn columns at top
- Bottom row blocked
- Impossible to complete

---

## Level Generator

### Using the Script

```bash
python3 tools/level_generator.py --start 51 --end 60 --out levels/
```

### What It Generates

- Balanced target scores and moves
- Random board shapes (full, hollow, cross, diagonal)
- 6% chance of special tiles (collectibles, unmovables)
- **Never** places collectibles in bottom row
- Automatic `collectible_type: "coin"` for collectible levels
- Clear descriptions based on level type

### Customization

After generation, manually edit for:
- Different collectible types
- Themed layouts
- Specific spawn patterns
- Difficulty tuning

---

## Testing Checklist

### Functionality Tests
- [ ] Collectibles spawn from marked columns
- [ ] Spawn rate feels balanced (not too many/few)
- [ ] Collectibles fall with gravity
- [ ] Can swap collectibles with adjacent tiles
- [ ] Collectibles don't match with regular tiles
- [ ] Special tiles ignore collectibles
- [ ] Collection animation plays at bottom
- [ ] Sound effect plays on collection
- [ ] Counter updates correctly
- [ ] 500 points awarded per collectible

### Win/Lose Tests
- [ ] Level completes when target reached
- [ ] Level fails when out of moves
- [ ] Score doesn't trigger completion in collectible levels
- [ ] Bonus cascade works with collectibles on board
- [ ] Can collect more than required (4/2)

### UI Tests
- [ ] Target shows "Coins: X/Y" for collectible levels
- [ ] Progress bar updates correctly
- [ ] Transition screen shows collectible count
- [ ] Rewards screen displays properly

### Edge Cases
- [ ] Multiple collectibles at bottom collected simultaneously
- [ ] Collectibles in column with special tile
- [ ] Collectibles during cascade chains
- [ ] Extra collectibles after target met
- [ ] Different collectible types (coin → gem)

---

## Player Experience

### Strategic Elements

**Path Planning**
- Create matches below collectibles to guide them down
- Clear obstacles blocking descent
- Use gravity strategically

**Special Tile Usage**
- Use freely - they won't destroy collectibles
- Clear tiles around collectibles to speed descent
- Create combos for faster collection

**Risk/Reward**
- Do I chase collectibles or build score?
- Should I create special tiles first?
- When to use boosters?

### Visual Feedback

**Collectible Spawning**
- Appears from top of column
- Falls into view with animation
- Distinctive appearance (golden tint)

**Collection**
- Particle burst (30 particles)
- Golden color gradient
- Flies to counter (0.6s)
- Fades during flight
- Sound effect confirmation

**Progress Tracking**
- Always visible in HUD
- Updates immediately
- Visual progress bar
- Clear win condition

---

## Advanced Topics

### Future Enhancements

**Multiple Types Per Level** (not yet implemented)
```json
{
  "collectibles": [
    {"type": "coin", "target": 3},
    {"type": "gem", "target": 2}
  ]
}
```

**Special Collectibles** (not yet implemented)
- Locked: Require matches nearby to unlock
- Moving: Change position each turn
- Splitting: Become multiple when matched

**Collectible Combos** (not yet implemented)
- Bonus for consecutive collections
- Multiplier for speed
- Special effects for many at once

### Performance Considerations

- Collectible spawning: O(columns × rows) per refill
- Collection detection: O(grid_width) per gravity
- Animation: One tween per collectible
- Particles: Auto-cleanup after 1 second

### Debugging

Enable debug logging:
```gdscript
print("[GameManager] Collectible type: ", collectible_type)
print("[GameBoard] Spawned collectible at ", pos)
print("[Tile] Using collectible texture: ", texture_path)
```

Look for these markers:
- 🪙 Collectible events
- ✨ All collectibles collected
- ⚠️ Warnings/issues

---

## Summary

The collectibles system is a fully-featured, production-ready mechanic that:

✅ Adds gameplay variety  
✅ Easy to configure via JSON  
✅ Supports any collectible type  
✅ Theme-aware texture loading  
✅ Smooth animations and feedback  
✅ Robust implementation  
✅ Well-tested and debugged  

Perfect for creating engaging match-3 levels with diverse objectives!
