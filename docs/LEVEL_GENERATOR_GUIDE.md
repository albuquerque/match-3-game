# Level Generator - Usage Guide

## Overview

The level generator script creates playable match-3 levels with proper unmovable tile placement and collectible distribution. Unmovables are grouped into meaningful barriers (walls, obstacles) that create strategic gameplay challenges.

**Key Features:**
- **Automatic playability validation** - ensures all generated levels are playable
- **Grid-size aware** - adapts patterns and difficulty to grid dimensions
- **Retry mechanism** - attempts multiple times to create valid layouts
- **Fallback safety** - uses simple full rectangle if complex shapes fail validation

## Playability Requirements

The generator ensures all levels meet these criteria:
- ✅ At least 50% of grid cells are playable
- ✅ No isolated single cells (all playable cells have adjacent playable cells)
- ✅ Each row has at least 3 consecutive playable cells (for horizontal matches)
- ✅ Each column has at least 3 consecutive playable cells (for vertical matches)
- ✅ Reasonable target scores based on grid size (max 500 points per cell)

## Grid Size Recommendations

**Small grids (5x5 to 6x6):**
- Best for: Score-based levels or collectible levels
- Unmovables: May be limited or omitted (harder to place without blocking matches)
- Shapes: Full rectangle or diamond only
- Target scores: 2,000 - 18,000 points

**Medium grids (7x7 to 8x8):**
- Best for: All level types
- Unmovables: Works well with barriers and obstacles
- Shapes: Rectangle, frame, diamond
- Target scores: 5,000 - 25,000 points

**Large grids (9x9+):**
- Best for: Complex challenges with multiple features
- Unmovables: Full variety of barrier patterns available
- Shapes: All shapes including checkerboard and cross patterns
- Target scores: Scaled appropriately to grid size

## Basic Usage

```bash
python3 tools/level_generator.py --start 11 --end 50 --out levels
```

## Command-Line Arguments

### Required Arguments
- None (all arguments have defaults)

### Optional Arguments

**`--start NUM`** (default: 11)
- Starting level number

**`--end NUM`** (default: 50)
- Ending level number

**`--out PATH`** (default: `levels`)
- Output directory for generated level files

**`--width NUM`** (default: 8)
- Grid width (number of columns)

**`--height NUM`** (default: 8)
- Grid height (number of rows)

**`--type TYPE`** (default: `random`)
- Level type to generate
- Choices:
  - `random` - Mix of different level types (40% collectibles, 30% unmovables, 20% both, 10% score)
  - `collectibles` - Levels with collectibles only, no unmovables
  - `unmovables` - Levels with unmovable barriers only, no collectibles
  - `both` - Levels with both collectibles and unmovables
  - `score` - Plain score-based levels (no special features)

## Examples

### Generate Random Mix of Levels
```bash
python3 tools/level_generator.py --start 11 --end 50
```

### Generate Only Collectible Levels
```bash
python3 tools/level_generator.py --start 21 --end 30 --type collectibles
```

### Generate Only Unmovable Barrier Levels
```bash
python3 tools/level_generator.py --start 31 --end 40 --type unmovables
```

### Generate Levels with Both Features
```bash
python3 tools/level_generator.py --start 41 --end 50 --type both
```

### Generate Plain Score-Based Levels
```bash
python3 tools/level_generator.py --start 51 --end 60 --type score
```

### Generate Custom Grid Size
```bash
python3 tools/level_generator.py --start 1 --end 10 --width 10 --height 10
```

## Level Features

### Unmovable Tiles

Unmovables are placed in strategic patterns:

**Barrier Patterns:**
- **Horizontal Line** - Barrier across the middle of the board
- **Vertical Line** - Barrier down the center
- **Corner Blocks** - Small clusters in corners
- **Center Cluster** - Group clustered in the middle
- **Scattered Groups** - Multiple small groups (2-3 tiles each)

**Properties:**
- Always adjacent to playable cells (can be destroyed by matches)
- Grouped together (10-20% of playable area)
- Never isolated or unreachable
- Material types vary: snow, glass, wood

### Collectibles

Collectibles are placed strategically:
- 1-3 collectibles per level
- Never placed in bottom row (prevents instant collection)
- Never overlaps with unmovables
- Columns with collectibles spawn more during gameplay

### Board Shapes

The generator creates various board shapes:
- Full rectangle (standard grid)
- Frame (hollow center with blocked cells)
- Cross/Plus shape
- Diamond shape
- Checkerboard pattern (large blocks)

### Difficulty Scaling

**Target Score:**
- Base: 5000 + (level × 300)
- Adjusted for collectibles (60% of normal)
- Adjusted for unmovables (80% of normal)

**Moves:**
- Base: 25 + (level × 0.3)
- +8 moves for unmovables
- +5 moves for collectibles
- Range: 20-60 moves

**Themes:**
- Even levels: Modern theme
- Odd levels: Legacy theme

## Output Format

Generated files follow the existing level JSON format:

```json
{
  "level_number": 61,
  "title": "Level 61",
  "description": "Break through the barriers! Reach 18640 points.",
  "grid_width": 8,
  "grid_height": 8,
  "target_score": 18640,
  "max_moves": 51,
  "num_tile_types": 6,
  "theme": "legacy",
  "layout": "0 0 0 0 U U U 0\n...",
  "collectible_target": 0,
  "unmovable_type": "snow",
  "collectible_type": "coin"
}
```

**Layout Format:**
- Space-separated cells
- Newline-separated rows
- `0` = playable cell
- `X` = blocked cell
- `U` = unmovable soft tile
- `C` = collectible marker

## Tips

1. **Testing Specific Features:**
   - Generate unmovable-only levels to test destruction mechanics
   - Generate collectible-only levels to test collection mechanics
   - Use `both` type for complex combined challenges

2. **Difficulty Tuning:**
   - Generate random mix for variety
   - Adjust width/height for different grid sizes
   - Regenerate if a level is too easy/hard

3. **Overwriting Existing Levels:**
   - Script will overwrite existing level files
   - Back up `levels/` directory before regenerating
   - Generate specific ranges to avoid overwriting good levels

## Troubleshooting

**Issue: "All attempts failed, using safe full rectangle layout"**
- This happens when complex shapes with unmovables create unplayable layouts
- The generator automatically falls back to a simple playable rectangle
- Common with very small grids (5x5, 6x6) and unmovable levels
- **Solution**: This is normal behavior - the fallback ensures playability
- **Alternative**: Use `--type score` or `--type collectibles` for small grids

**Issue: Levels are unplayable**
- **Should not happen** - the generator validates all levels before saving
- If you find an unplayable level, please report it as a bug
- Check that unmovables are adjacent to playable cells
- Verify no collectibles in bottom row
- Ensure sufficient playable space (not too many blocked cells)

**Issue: Too easy/hard**
- Adjust target score manually in generated JSON
- Regenerate with different type
- Modify difficulty scaling in script
- Use smaller/larger grid sizes

**Issue: Boring layouts**
- Try different board shapes (automatic based on grid size)
- Mix level types using `random`
- Use larger grids (8x8+) for more variety
- Manually tweak generated layouts

**Issue: Retrying many times**
- Normal for small grids with unmovables
- The generator ensures playability by retrying
- If you see 5+ retries, consider using simpler level types
- For 5x5 or 6x6 grids, use `--type score` or `--type collectibles`

## Future Enhancements

Potential improvements to the generator:
- Multiple collectible types per level
- Hard unmovables (multi-hit obstacles)
- Rope/chain mechanics for collectibles
- Custom barrier patterns
- Specific shape selection per level
- Boss levels with special layouts
