# Level Transition Theming - Quick Example

## Adding a "Night Mode" Theme

This is a complete example showing how to add a new theme to your level complete screen.

### Step 1: Add Theme Colors

Edit `scripts/LevelTransition.gd` around line 40:

```gdscript
var theme_colors = {
	"modern": {
		"background": Color(0.05, 0.05, 0.1, 1.0),
		"title": Color(1.0, 0.9, 0.3, 1.0),
		"score": Color(0.9, 0.9, 1.0, 1.0),
		"rewards_title": Color(1.0, 1.0, 1.0, 1.0),
		"continue_button": Color(0.3, 1.0, 0.3, 1.0),
		"replay_button": Color(0.3, 0.9, 1.0, 1.0),
	},
	"legacy": {
		"background": Color(0.1, 0.05, 0.0, 1.0),
		"title": Color(1.0, 0.8, 0.2, 1.0),
		"score": Color(1.0, 0.95, 0.85, 1.0),
		"rewards_title": Color(0.95, 0.9, 0.8, 1.0),
		"continue_button": Color(0.4, 0.9, 0.3, 1.0),
		"replay_button": Color(0.4, 0.8, 0.9, 1.0),
	},
	# ADD YOUR NEW THEME HERE
	"night": {
		"background": Color(0.02, 0.02, 0.05, 1.0),      # Very dark blue
		"title": Color(0.8, 0.8, 1.0, 1.0),              # Pale blue
		"score": Color(0.6, 0.6, 0.8, 1.0),              # Muted blue
		"rewards_title": Color(0.7, 0.7, 0.9, 1.0),      # Light blue-gray
		"continue_button": Color(0.5, 0.7, 1.0, 1.0),    # Soft blue
		"replay_button": Color(0.7, 0.5, 1.0, 1.0),      # Soft purple
	}
}
```

### Step 2: Register Theme Path

Edit `scripts/ThemeManager.gd` around line 8:

```gdscript
var theme_paths = {
	"legacy": "res://textures/legacy/",
	"modern": "res://textures/modern/",
	"night": "res://textures/night/"  # ADD THIS LINE
}
```

### Step 3: Create Texture Folder

Create the texture folder for your theme:

```bash
mkdir -p /Users/sal76/src/match-3-game/textures/night
```

Then copy tile textures from an existing theme:

```bash
# Copy from modern theme as a starting point
cp textures/modern/*.png textures/night/
cp textures/modern/*.svg textures/night/
```

### Step 4: Use in Level

Edit a level JSON file (e.g., `levels/level_11.json`):

```json
{
	"level": 11,
	"theme": "night",
	"moves": 28,
	"target_score": 8300,
	"description": "Reach 8300 points in 28 moves!",
	"layout": "full",
	"width": 8,
	"height": 8
}
```

### Step 5: Test It!

Run the game and play to level 11. When you complete it, you should see:
- Very dark blue background
- Pale blue "Level Complete" text
- Soft blue/purple buttons
- Overall nighttime aesthetic

## Dynamic Theme Application

### Apply Theme Based on Time of Day

Add this to `GameUI.gd` in the `_on_level_complete()` function:

```gdscript
func _on_level_complete():
	# ...existing code...
	
	# Apply night theme during evening hours
	var time = Time.get_datetime_dict_from_system()
	if time.hour >= 20 or time.hour < 6:  # 8 PM to 6 AM
		level_transition.apply_theme_colors("night")
	
	level_transition.show_transition(...)
```

### Apply Theme Based on Level Number

```gdscript
func _on_level_complete():
	# ...existing code...
	
	# Use night theme for every 5th level
	if GameManager.level % 5 == 0:
		level_transition.apply_theme_colors("night")
	
	level_transition.show_transition(...)
```

## Result

Your night theme will provide a calm, dark aesthetic perfect for:
- Evening play sessions
- "Midnight" or "Dream" themed levels
- Puzzle levels that require focus
- Relaxing gameplay moments

## Color Tips for Night Theme

**What Works Well:**
- Deep, dark backgrounds (near black with hint of blue)
- Muted, desaturated text colors
- Soft pastels for highlights
- Low contrast (easier on eyes at night)

**Avoid:**
- Bright, saturated colors (too harsh)
- Pure white text (use off-white or pale colors)
- High contrast (too jarring)
- Warm colors (breaks the "night" feel)

## Next Steps

Try creating other themed variations:
- **Sunset**: Warm oranges and purples
- **Ocean**: Blues and teals
- **Forest**: Greens and browns
- **Fire**: Reds and oranges
- **Ice**: Whites and light blues

Each theme can have its own unique color palette that enhances the player's experience!
