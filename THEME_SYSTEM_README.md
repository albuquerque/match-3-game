# Theme System Implementation

## Overview
The theme system allows the game to switch between different visual styles for tile textures based on the level being played.

## Structure

### Texture Folders
- **`textures/legacy/`** - Contains the original tile images (smaller, simpler style)
- **`textures/modern/`** - Contains the new 1024x1024 tile images (tiles 1-9)

### ThemeManager (Autoload Singleton)
Located at: `scripts/ThemeManager.gd`

The ThemeManager is an autoload singleton that manages which theme is currently active and provides texture paths based on the active theme.

**Key Functions:**
- `set_theme(theme_name: String)` - Sets the current theme ("legacy" or "modern")
- `set_theme_by_name(theme_name: String)` - Alias for set_theme with lowercase conversion
- `get_tile_texture_path(tile_type: int)` - Returns the full path to a tile texture based on current theme
- `get_theme_name()` - Returns the name of the current theme
- `theme_exists(theme_name: String)` - Checks if a theme exists

### Level Configuration
Each level JSON file now includes a `"theme"` field:

```json
{
  "level": 1,
  "width": 8,
  "height": 8,
  "target_score": 5000,
  "moves": 30,
  "description": "Welcome! Match 3 tiles to score points.",
  "theme": "legacy",
  "layout": "..."
}
```

**Current Theme Assignment:**
- **Odd levels (1, 3, 5, 7, 9)** - Use "legacy" theme
- **Even levels (2, 4, 6, 8, 10)** - Use "modern" theme

### Integration

**GameManager:**
- Initializes ThemeManager as autoload singleton
- When loading a level, checks for `theme` field in level data
- Falls back to odd/even rule if no theme specified
- Applies theme before creating the grid

**Tile.gd:**
- Accesses ThemeManager to get texture paths
- Automatically scales all textures to 64x64 pixels regardless of source size
- Supports both 1024x1024 modern tiles and smaller legacy tiles

## Adding New Themes

To add a new theme:

1. Create a new folder in `textures/` (e.g., `textures/winter/`)
2. Add tile images named `tile_1.png` through `tile_11.png`
3. Update `ThemeManager.gd`:
   ```gdscript
   var theme_paths = {
       "legacy": "res://textures/legacy/",
       "modern": "res://textures/modern/",
       "winter": "res://textures/winter/"  // Add new theme
   }
   ```
4. Set the theme in level JSON files:
   ```json
   "theme": "winter"
   ```

## Technical Details

### Tile Scaling
All tile textures are automatically scaled to 64x64 pixels when loaded, regardless of their source resolution:
- Legacy tiles (various sizes) → scaled to 64x64
- Modern tiles (1024x1024) → scaled to 64x64
- Any other size → scaled to 64x64

This ensures consistent visual appearance across themes.

### Default Behavior
If a level doesn't specify a theme:
- Odd levels use "legacy" theme
- Even levels use "modern" theme

If a theme doesn't exist:
- Falls back to "modern" theme

## Files Modified
- `scripts/ThemeManager.gd` - New file (autoload singleton)
- `scripts/GameManager.gd` - Added theme initialization and level theme loading
- `scripts/LevelManager.gd` - Added theme property to LevelData class
- `scripts/Tile.gd` - Updated to use ThemeManager for texture paths
- `project.godot` - Added ThemeManager as autoload
- `levels/level_01.json` through `level_10.json` - Added theme field to all levels
- `textures/modern/` - New folder with 1024x1024 tile images (tiles 1-9)

## Implementation Details

### LevelData Class
The `LevelData` class in `LevelManager.gd` now includes a `theme` property:
```gdscript
class LevelData:
	var level_number: int
	var grid_layout: Array
	var width: int
	var height: int
	var target_score: int
	var moves: int
	var description: String
	var theme: String = ""  # Theme name for this level
```

When loading levels from JSON, the theme is extracted with:
```gdscript
var theme = data.get("theme", "")
```

This allows levels to optionally specify a theme, with a fallback to empty string if not provided.

## Testing
Test the theme system by:
1. Playing odd-numbered levels - should see legacy theme tiles
2. Playing even-numbered levels - should see modern theme tiles
3. Checking that all tiles are scaled correctly to 64x64 pixels
4. Verifying no visual artifacts or scaling issues

