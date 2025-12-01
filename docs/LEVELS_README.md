# Match 3 Game - Level System

## Overview

Your Match 3 game now supports multiple levels with custom board shapes! Levels can have holes, notches, and various patterns to increase difficulty and variety.

## Features

- **10 pre-built levels** with increasing difficulty
- **Custom board shapes** - levels can have blocked cells creating unique patterns
- **JSON-based level configuration** - easy to create and modify levels
- **Dynamic grid sizing** - boards adapt to any size defined in the level
- **Programmatic level generation** - no need to hardcode levels

## Level Configuration

### JSON Format

Levels are defined in JSON files located in the `levels/` directory. Each level file should follow this format:

```json
{
  "level": 1,
  "width": 8,
  "height": 8,
  "target_score": 5000,
  "moves": 30,
  "description": "Welcome! Match 3 tiles to score points.",
  "layout": "0 0 0 0 0 0 0 0\n0 0 0 0 0 0 0 0\n..."
}
```

### Layout Values

The `layout` field defines the board shape using a grid of values:

- **`X`** or **`x`** = Blocked cell (no tile, creates holes/notches)
- **`0`** = Empty cell (will be filled with a random tile)
- **`.`** or **`_`** = Empty cell (alternative notation)
- **`1-6`** = Specific tile type (for special level designs)

### Layout Formats Supported

The LevelManager supports three layout formats:

1. **String format** (recommended):
   ```json
   "layout": "0 0 X X 0 0\n0 0 0 0 0 0\n..."
   ```

2. **2D array format**:
   ```json
   "layout": [[0, 0, -1], [0, 0, 0], ...]
   ```

3. **Flat array format**:
   ```json
   "layout": [0, 0, -1, 0, 0, 0, ...]
   ```

## Included Levels

1. **Level 1**: Standard 8x8 grid - Tutorial level
2. **Level 2**: Corners blocked - Introduction to blocked cells
3. **Level 3**: Cross pattern - Navigate the cross shape
4. **Level 4**: Diamond shape - Strategic matching required
5. **Level 5**: Donut (hole in middle) - Work around the center
6. **Level 6**: T-shape - Asymmetric challenge
7. **Level 7**: Stairway pattern - Diagonal gameplay
8. **Level 8**: Hourglass - Narrow middle section
9. **Level 9**: Swiss cheese - Multiple small holes
10. **Level 10**: Ultimate challenge - Complex pattern

## Creating New Levels

### Method 1: JSON File

1. Create a new file in `levels/` directory (e.g., `level_11.json`)
2. Use the JSON format shown above
3. Design your layout using `0` for tiles and `X` for blocked cells
4. The game will automatically load it on startup

### Example Custom Level

```json
{
  "level": 11,
  "width": 6,
  "height": 6,
  "target_score": 15000,
  "moves": 20,
  "description": "Heart shape!",
  "layout": "0 X 0 0 X 0\n0 0 0 0 0 0\n0 0 0 0 0 0\nX 0 0 0 0 X\nX X 0 0 X X\nX X X X X X"
}
```

### Method 2: Programmatic Generation

You can also create levels programmatically in `LevelManager.gd`:

```gdscript
func create_custom_level():
    var layout = []
    for x in range(width):
        layout.append([])
        for y in range(height):
            # Your logic here
            if should_be_blocked(x, y):
                layout[x].append(-1)  # Blocked
            else:
                layout[x].append(0)   # Normal tile
    
    var level = LevelData.new(level_num, layout, width, height, score, moves, desc)
    levels.append(level)
```

## Level System Architecture

### Key Components

1. **LevelManager** (`scripts/LevelManager.gd`)
   - Singleton that loads and manages all levels
   - Parses JSON files from the `levels/` directory
   - Provides level data to GameManager

2. **GameManager** (`scripts/GameManager.gd`)
   - Loads current level from LevelManager
   - Handles blocked cells in match detection
   - Manages level progression

3. **GameBoard** (`scripts/GameBoard.gd`)
   - Renders only non-blocked tiles
   - Handles gravity and refills around blocked cells
   - Adapts visual layout to any grid size

### Blocked Cell Behavior

- **Matching**: Blocked cells break match chains (tiles can't match across them)
- **Gravity**: Tiles fall around blocked cells
- **Swapping**: Players cannot swap tiles into blocked positions
- **Special Tiles**: Row/column clearing special tiles skip blocked cells

## Tips for Level Design

1. **Difficulty Progression**: Start with fewer blocked cells, gradually add more
2. **Symmetry**: Symmetric patterns are often more satisfying
3. **Strategic Placement**: Block cells in positions that require planning
4. **Target Balance**: Adjust `target_score` and `moves` based on available tiles
5. **Test Thoroughly**: Play your levels to ensure they're beatable

## Modifying Existing Levels

Simply edit the JSON files in the `levels/` directory. Changes will be loaded the next time you run the game.

## Future Enhancements

Potential additions to the level system:

- Level-specific tile colors or types
- Immovable tiles (can't be swapped but can be matched)
- Ice tiles that need to be matched twice
- Goal-based levels (collect specific tiles)
- Time-based challenges
- Locked tiles that unlock after N moves

## Technical Notes

- Levels are loaded in alphabetical order by filename
- If no JSON files are found, the game uses 5 built-in fallback levels
- The `LevelManager` is registered as an autoload singleton
- Grid dimensions can be any size (though UI works best with 6x6 to 10x10)
- Blocked cells are represented internally as `-1` in the grid

## Troubleshooting

**Level not loading?**
- Check JSON syntax is valid
- Ensure layout dimensions match width × height
- Verify the file is in the `levels/` directory

**Layout looks wrong?**
- Remember: layout is specified as [x][y] (column, row)
- First row in the layout string is y=0 (top)
- Use exactly width × height cells in your layout

**Game crashes on level?**
- Ensure there are enough non-blocked cells for gameplay
- Very few tiles may cause infinite loops in refill logic
- Test with at least 50% of cells unblocked

---

Enjoy creating unique and challenging levels for your Match 3 game!

