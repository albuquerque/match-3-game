# Level Transition Theming - Complete Guide

**Status:** ✅ Fully Implemented  
**Version:** 1.0  
**Date:** February 6, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Color Theming](#color-theming)
4. [Background Images](#background-images)
5. [DLC Integration](#dlc-integration)
6. [Creating Custom Themes](#creating-custom-themes)
7. [Dynamic Theme Switching](#dynamic-theme-switching)
8. [API Reference](#api-reference)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The level complete/transition screen provides a full theming system that allows you to customize the visual appearance of the victory screen between levels.

### What You Can Theme

✅ **Color Schemes** - 6 customizable color properties  
✅ **Background Images** - Full-screen images from bundled or DLC assets  
✅ **Dynamic Switching** - Change themes based on level, chapter, or conditions  
✅ **DLC Support** - Load backgrounds from downloaded content  

### Features

- **Automatic detection** from level theme
- **Manual override** with `apply_theme_colors()`
- **Runtime switching** based on conditions
- **Fallback to default** if theme not found
- **Multiple image formats**: PNG, JPEG, SVG, WebP
- **Transparency support** for PNG images
- **Proper layering**: Background color → Image → UI content

---

## Quick Start

### Using Built-in Themes (2 minutes)

**Step 1:** Set theme in level JSON
```json
{
    "level": 5,
    "theme": "legacy",
    "moves": 25,
    "target_score": 6000
}
```

**Step 2:** Play the level and complete it

**Result:** The level complete screen automatically uses the theme colors!

### Creating a Simple Custom Theme (5 minutes)

**Edit `scripts/LevelTransition.gd`:**

```gdscript
var theme_colors = {
    "modern": { /* existing */ },
    "legacy": { /* existing */ },
    "night": {
        "background": Color(0.02, 0.02, 0.08, 1.0),
        "title": Color(0.9, 0.9, 1.0, 1.0),
        "score": Color(0.7, 0.7, 0.9, 1.0),
        "rewards_title": Color(0.8, 0.8, 1.0, 1.0),
        "continue_button": Color(0.6, 0.8, 1.0, 1.0),
        "replay_button": Color(0.8, 0.6, 1.0, 1.0),
    }
}
```

**Use it:** Set `"theme": "night"` in level JSON or call `apply_theme_colors("night")`

---

## Color Theming

### Built-in Themes

#### Modern Theme (Default)
```gdscript
"modern": {
    "background": Color(0.05, 0.05, 0.1, 1.0),      # Dark blue-gray
    "title": Color(1.0, 0.9, 0.3, 1.0),             # Bright gold
    "score": Color(0.9, 0.9, 1.0, 1.0),             # Light blue-white
    "rewards_title": Color(1.0, 1.0, 1.0, 1.0),     # White
    "continue_button": Color(0.3, 1.0, 0.3, 1.0),   # Bright green
    "replay_button": Color(0.3, 0.9, 1.0, 1.0),     # Cyan
}
```

**Use for:** Contemporary, clean, tech-focused levels

#### Legacy Theme
```gdscript
"legacy": {
    "background": Color(0.1, 0.05, 0.0, 1.0),       # Dark brown
    "title": Color(1.0, 0.8, 0.2, 1.0),             # Warm gold
    "score": Color(1.0, 0.95, 0.85, 1.0),           # Cream
    "rewards_title": Color(0.95, 0.9, 0.8, 1.0),    # Warm white
    "continue_button": Color(0.4, 0.9, 0.3, 1.0),   # Warm green
    "replay_button": Color(0.4, 0.8, 0.9, 1.0),     # Warm cyan
}
```

**Use for:** Biblical, historical, traditional levels

### Theme Color Properties

| Property | Applied To | Purpose | Example |
|----------|-----------|---------|---------|
| `background` | Full-screen ColorRect | Screen background | `Color(0.05, 0.05, 0.1, 1.0)` |
| `title` | "Level Complete!" text | Main title | `Color(1.0, 0.9, 0.3, 1.0)` |
| `score` | Final score display | Score number | `Color(0.9, 0.9, 1.0, 1.0)` |
| `rewards_title` | "Rewards Earned:" label | Rewards header | `Color(1.0, 1.0, 1.0, 1.0)` |
| `continue_button` | "NEXT LEVEL" button | Primary action | `Color(0.3, 1.0, 0.3, 1.0)` |
| `replay_button` | "REPLAY" button | Secondary action | `Color(0.3, 0.9, 1.0, 1.0)` |

### Color Format

All colors use Godot's `Color` class with RGBA values (0.0 to 1.0):

```gdscript
Color(red, green, blue, alpha)

# Examples:
Color(1.0, 0.0, 0.0, 1.0)  # Pure red, fully opaque
Color(0.0, 0.5, 1.0, 1.0)  # Sky blue
Color(0.1, 0.1, 0.1, 0.8)  # Dark gray, 80% opaque
```

---

## Background Images

### Adding Background Images

Add a `background_image` property to any theme:

```gdscript
"forest": {
    "background": Color(0.1, 0.15, 0.05, 1.0),  # Fallback color
    "title": Color(0.5, 1.0, 0.3, 1.0),
    // ...other colors...
    "background_image": "res://textures/backgrounds/forest.jpg"
}
```

### Image Specifications

**Recommended Size:** 720×1280 pixels (portrait)  
**Aspect Ratio:** 9:16 (matches mobile portrait)  
**Format:** PNG, JPEG, WebP, or SVG  
**File Size:** < 500 KB recommended  

**Aspect Ratios:**
| Device | Recommended Size | Aspect |
|--------|-----------------|--------|
| Mobile Portrait | 720×1280 | 9:16 |
| Tablet Portrait | 1080×1920 | 9:16 |
| Landscape | 1920×1080 | 16:9 |

### Supported Image Formats

- ✅ **PNG** - Best for transparency, detailed graphics
- ✅ **JPEG** - Best for photos, smaller file size
- ✅ **WebP** - Modern format, good compression
- ✅ **SVG** - Scalable vector graphics

### Image Layout

**Layering (bottom to top):**
1. Background color (solid)
2. Background image (scaled to cover)
3. UI elements (title, score, buttons)

**Stretch Mode:** `STRETCH_KEEP_ASPECT_COVERED`
- Fills entire screen
- Maintains aspect ratio
- May crop edges on different aspect ratios

### Image Loading

Images are loaded from:
- **Bundled assets:** `"res://textures/backgrounds/image.png"`
- **DLC assets:** `"chapter_id:asset_name"`

**Example:**
```gdscript
// Bundled
"background_image": "res://textures/backgrounds/victory.jpg"

// DLC
"background_image": "chapter_gospels:victory_background"
```

---

## DLC Integration

### Using DLC Backgrounds

You can load background images from DLC chapters using the AssetRegistry!

**Format:** `"chapter_id:asset_name"`

### Step 1: Add to DLC Manifest

**`user://dlc/chapters/chapter_gospels/manifest.json`:**
```json
{
  "chapter_id": "chapter_gospels",
  "version": "1.0.0",
  "name": "The Gospels",
  "assets": {
    "textures": {
      "victory_background": "backgrounds/gospel_victory.jpg",
      "level_complete_bg": "backgrounds/stained_glass.png",
      "peaceful_scene": "backgrounds/garden.jpg"
    }
  }
}
```

### Step 2: Add Images to DLC Package

**Directory structure:**
```
user://dlc/chapters/chapter_gospels/
├── manifest.json
├── levels/
│   ├── level_1.json
│   └── level_2.json
└── backgrounds/
    ├── gospel_victory.jpg
    ├── stained_glass.png
    └── garden.jpg
```

### Step 3: Reference in Theme

**`scripts/LevelTransition.gd`:**
```gdscript
var theme_colors = {
    // ...existing themes...
    "gospels": {
        "background": Color(0.15, 0.1, 0.2, 1.0),
        "title": Color(1.0, 0.9, 0.5, 1.0),
        "score": Color(1.0, 1.0, 0.9, 1.0),
        "rewards_title": Color(0.95, 0.9, 0.8, 1.0),
        "continue_button": Color(0.8, 0.7, 0.3, 1.0),
        "replay_button": Color(0.6, 0.5, 0.8, 1.0),
        "background_image": "chapter_gospels:victory_background"  // ← DLC!
    }
}
```

### Step 4: Use in Levels

**DLC level JSON:**
```json
{
    "level": 1,
    "theme": "gospels",
    "chapter": "chapter_gospels",
    "moves": 30,
    "target_score": 10000
}
```

### Asset Loading Priority

1. **DLC Assets** (AssetRegistry) - `"chapter_id:asset_name"`
2. **Bundled Assets** (ResourceLoader) - `"res://path/to/image.png"`
3. **Fallback** - Background color only

### DLC Asset Registry Integration

The system automatically:
- Detects DLC asset references (`chapter_id:asset_name`)
- Queries AssetRegistry for the texture
- Loads from either bundled or DLC location
- Falls back to background color if unavailable

---

## Creating Custom Themes

### Basic Custom Theme

**Minimum required properties:**
```gdscript
"my_theme": {
    "background": Color(0.1, 0.1, 0.1, 1.0),
    "title": Color(1.0, 1.0, 1.0, 1.0),
    "score": Color(0.9, 0.9, 0.9, 1.0),
    "rewards_title": Color(0.8, 0.8, 0.8, 1.0),
    "continue_button": Color(0.0, 1.0, 0.0, 1.0),
    "replay_button": Color(0.0, 0.8, 1.0, 1.0),
}
```

### Theme with Background Image

```gdscript
"beach": {
    "background": Color(0.9, 0.85, 0.7, 1.0),      # Sandy color
    "title": Color(0.0, 0.4, 0.8, 1.0),            # Ocean blue
    "score": Color(0.1, 0.1, 0.3, 1.0),            # Dark blue
    "rewards_title": Color(0.2, 0.2, 0.4, 1.0),    # Navy
    "continue_button": Color(0.0, 0.6, 0.3, 1.0),  # Sea green
    "replay_button": Color(0.8, 0.5, 0.2, 1.0),    # Sunset orange
    "background_image": "res://textures/backgrounds/beach.jpg"
}
```

### Per-Chapter Themes

Create themes for each chapter:

```gdscript
"chapter1_forest": {
    "background": Color(0.1, 0.2, 0.1, 1.0),
    "title": Color(0.5, 1.0, 0.3, 1.0),
    "score": Color(0.9, 1.0, 0.9, 1.0),
    "rewards_title": Color(0.8, 1.0, 0.8, 1.0),
    "continue_button": Color(0.3, 0.9, 0.2, 1.0),
    "replay_button": Color(0.5, 0.8, 0.3, 1.0),
    "background_image": "res://textures/backgrounds/forest_victory.jpg"
},
"chapter2_ocean": {
    "background": Color(0.0, 0.1, 0.2, 1.0),
    "title": Color(0.3, 0.8, 1.0, 1.0),
    "score": Color(0.9, 0.95, 1.0, 1.0),
    "rewards_title": Color(0.8, 0.9, 1.0, 1.0),
    "continue_button": Color(0.2, 0.7, 1.0, 1.0),
    "replay_button": Color(0.4, 0.6, 0.9, 1.0),
    "background_image": "res://textures/backgrounds/ocean_victory.jpg"
}
```

### Boss Battle Themes

Special themes for boss levels:

```gdscript
"boss": {
    "background": Color(0.15, 0.0, 0.0, 1.0),      # Dark red
    "title": Color(1.0, 0.2, 0.0, 1.0),            # Fiery red
    "score": Color(1.0, 0.9, 0.5, 1.0),            # Golden
    "rewards_title": Color(1.0, 0.8, 0.3, 1.0),    # Warm gold
    "continue_button": Color(1.0, 0.3, 0.0, 1.0),  # Bright red
    "replay_button": Color(0.8, 0.0, 0.2, 1.0),    # Deep red
    "background_image": "res://textures/backgrounds/boss_defeated.jpg"
}
```

---

## Dynamic Theme Switching

### Automatic Theme Detection

The system automatically detects the theme from the current level:

```
Level JSON → ThemeManager → LevelTransition
```

**In `LevelTransition.gd` `_ready()`:**
```gdscript
# Get current theme from ThemeManager
var theme_manager = get_node_or_null("/root/ThemeManager")
if theme_manager:
    var current_theme = theme_manager.current_theme
    apply_theme_colors(current_theme)
```

### Manual Theme Override

Change theme programmatically:

```gdscript
# Get reference to LevelTransition
var level_transition = get_node("/root/MainGame/GameUI/LevelTransition")

# Apply specific theme
level_transition.apply_theme_colors("neon")
```

### Conditional Theming

#### Boss Level Theming

```gdscript
# In GameUI.gd when showing transition
func _on_level_complete():
    # ... existing code ...
    
    # Apply boss theme for every 10th level
    if GameManager.level % 10 == 0:
        level_transition.apply_theme_colors("boss")
    else:
        # Use regular theme from level data
        level_transition.apply_theme_colors(GameManager.current_theme)
    
    level_transition.show_transition(...)
```

#### Time-Based Theming

```gdscript
# Apply different theme based on time of day
func _apply_time_based_theme():
    var time = Time.get_datetime_dict_from_system()
    var hour = time["hour"]
    
    if hour >= 6 and hour < 18:
        level_transition.apply_theme_colors("day")
    else:
        level_transition.apply_theme_colors("night")
```

#### Chapter-Based Theming

```gdscript
# Apply theme based on chapter
func _on_level_complete():
    var chapter = GameManager.current_chapter
    var theme_name = "chapter" + str(chapter) + "_theme"
    level_transition.apply_theme_colors(theme_name)
```

#### Score-Based Theming

```gdscript
# Apply different theme based on performance
func _on_level_complete():
    var stars = GameManager.calculate_stars()
    
    if stars == 3:
        level_transition.apply_theme_colors("perfect")
    elif stars == 2:
        level_transition.apply_theme_colors("good")
    else:
        level_transition.apply_theme_colors("standard")
```

---

## API Reference

### LevelTransition Class

#### Properties

```gdscript
var theme_colors: Dictionary  # Theme color definitions
var background_image: String  # Current background image path
```

#### Methods

##### apply_theme_colors(theme_name: String)

Apply a theme to the transition screen.

**Parameters:**
- `theme_name` (String) - Name of theme from `theme_colors` dictionary

**Returns:** void

**Example:**
```gdscript
level_transition.apply_theme_colors("legacy")
```

**Behavior:**
1. Looks up theme in `theme_colors` dictionary
2. Falls back to "modern" if theme not found
3. Applies all 6 color properties
4. Loads and displays background image if specified
5. Updates all UI elements

##### show_transition(completed_level, final_score, coins_earned, gems_earned, has_next_level)

Show the level complete transition screen.

**Parameters:**
- `completed_level` (int) - Level number just completed
- `final_score` (int) - Final score achieved
- `coins_earned` (int) - Coins rewarded
- `gems_earned` (int) - Gems rewarded
- `has_next_level` (bool) - Whether there's a next level

**Signals Emitted:**
- `continue_pressed` - When player clicks continue
- `rewards_claimed` - When rewards are granted

**Example:**
```gdscript
level_transition.show_transition(
    GameManager.level,
    GameManager.score,
    100,  # coins
    5,    # gems
    true  # has next level
)
```

#### Signals

```gdscript
signal continue_pressed    # Player wants to proceed
signal rewards_claimed     # Rewards have been granted
```

### Theme Color Dictionary Structure

```gdscript
{
    "theme_name": {
        "background": Color,        # Background color
        "title": Color,             # Title text color
        "score": Color,             # Score text color
        "rewards_title": Color,     # Rewards label color
        "continue_button": Color,   # Continue button color
        "replay_button": Color,     # Replay button color
        "background_image": String  # Optional image path
    }
}
```

---

## Examples

### Example 1: Neon Theme

**Create a vibrant neon-style theme:**

```gdscript
"neon": {
    "background": Color(0.0, 0.0, 0.1, 1.0),       # Deep blue-black
    "title": Color(0.0, 1.0, 1.0, 1.0),            # Bright cyan
    "score": Color(1.0, 0.0, 1.0, 1.0),            # Magenta
    "rewards_title": Color(0.0, 1.0, 0.5, 1.0),    # Bright green
    "continue_button": Color(1.0, 1.0, 0.0, 1.0),  # Yellow
    "replay_button": Color(1.0, 0.0, 0.5, 1.0),    # Hot pink
    "background_image": "res://textures/backgrounds/neon_city.jpg"
}
```

**Use it:**
```json
{
    "level": 25,
    "theme": "neon",
    "moves": 30,
    "target_score": 15000
}
```

### Example 2: Gospel Chapter Theme with DLC Background

**DLC manifest:**
```json
{
  "chapter_id": "chapter_gospels",
  "assets": {
    "textures": {
      "victory_bg": "backgrounds/stained_glass.png"
    }
  }
}
```

**Theme definition:**
```gdscript
"gospels": {
    "background": Color(0.15, 0.1, 0.2, 1.0),
    "title": Color(1.0, 0.9, 0.5, 1.0),
    "score": Color(1.0, 1.0, 0.9, 1.0),
    "rewards_title": Color(0.95, 0.9, 0.8, 1.0),
    "continue_button": Color(0.8, 0.7, 0.3, 1.0),
    "replay_button": Color(0.6, 0.5, 0.8, 1.0),
    "background_image": "chapter_gospels:victory_bg"
}
```

### Example 3: Dynamic Boss Theme

**Apply boss theme for every 10th level:**

```gdscript
# In GameUI.gd
func _on_level_complete():
    var level_transition = $LevelTransition
    
    # Check if boss level
    if GameManager.level % 10 == 0:
        level_transition.apply_theme_colors("boss")
    else:
        # Use level's default theme
        var theme = GameManager.get_current_level_theme()
        level_transition.apply_theme_colors(theme)
    
    level_transition.show_transition(
        GameManager.level,
        GameManager.score,
        100, 5, true
    )
```

### Example 4: Time-Based Day/Night Theme

**Automatically switch based on system time:**

```gdscript
# In LevelTransition.gd _ready()
func _ready():
    # ... existing code ...
    
    # Apply time-based theme
    var time = Time.get_datetime_dict_from_system()
    var hour = time["hour"]
    
    if hour >= 6 and hour < 18:
        apply_theme_colors("day")
    else:
        apply_theme_colors("night")
```

**Day theme:**
```gdscript
"day": {
    "background": Color(0.9, 0.9, 1.0, 1.0),
    "title": Color(0.0, 0.3, 0.8, 1.0),
    "score": Color(0.1, 0.1, 0.4, 1.0),
    "rewards_title": Color(0.2, 0.2, 0.5, 1.0),
    "continue_button": Color(0.0, 0.6, 0.0, 1.0),
    "replay_button": Color(0.0, 0.4, 0.8, 1.0),
    "background_image": "res://textures/backgrounds/daytime.jpg"
}
```

**Night theme:**
```gdscript
"night": {
    "background": Color(0.02, 0.02, 0.08, 1.0),
    "title": Color(0.9, 0.9, 1.0, 1.0),
    "score": Color(0.7, 0.7, 0.9, 1.0),
    "rewards_title": Color(0.8, 0.8, 1.0, 1.0),
    "continue_button": Color(0.6, 0.8, 1.0, 1.0),
    "replay_button": Color(0.8, 0.6, 1.0, 1.0),
    "background_image": "res://textures/backgrounds/nighttime.jpg"
}
```

---

## Troubleshooting

### Theme Not Applying

**Symptoms:** Default "modern" theme always shows

**Check:**
1. Theme name in level JSON matches theme name in `theme_colors`
2. Theme is properly defined in `LevelTransition.gd`
3. No typos in theme name
4. Console shows: `[LevelTransition] Applied theme: your_theme_name`

**Solution:**
```gdscript
# Verify theme exists
if not theme_colors.has("my_theme"):
    print("Theme 'my_theme' not found!")
```

### Background Image Not Loading

**Symptoms:** Only background color shows, no image

**Check:**
1. Image file exists at specified path
2. Image format is supported (PNG, JPEG, WebP, SVG)
3. Path is correct (`res://` for bundled, `chapter_id:asset` for DLC)
4. For DLC: AssetRegistry has the asset registered
5. Console shows: `[LevelTransition] Loaded background image: path`

**Solution:**
```bash
# Verify image exists
ls -la textures/backgrounds/your_image.jpg

# Check console for errors
[LevelTransition] Failed to load background image: path
```

### DLC Background Not Loading

**Symptoms:** DLC background doesn't show, falls back to color

**Check:**
1. DLC chapter is installed
2. Asset is registered in manifest.json
3. Asset name matches exactly
4. Format is `"chapter_id:asset_name"`
5. AssetRegistry is initialized

**Console should show:**
```
[AssetRegistry] Registered texture: chapter_gospels:victory_bg
[LevelTransition] Loaded DLC background: chapter_gospels:victory_bg
```

**Solution:**
```gdscript
# Debug DLC asset loading
var asset_registry = get_node_or_null("/root/AssetRegistry")
if asset_registry:
    var texture = asset_registry.get_texture("chapter_gospels:victory_bg")
    if texture:
        print("DLC texture loaded successfully")
    else:
        print("DLC texture not found")
```

### Colors Look Wrong

**Symptoms:** Colors appear different than expected

**Check:**
1. Color values are 0.0-1.0 (not 0-255)
2. Alpha channel is set (fourth parameter)
3. Theme is actually being applied
4. No overlays or filters affecting colors

**Solution:**
```gdscript
# Convert RGB (0-255) to Color (0.0-1.0)
# Wrong: Color(255, 128, 64, 1.0)
# Right: Color(1.0, 0.5, 0.25, 1.0)

# Formula: Color(R/255, G/255, B/255, 1.0)
```

### Image Stretched or Cropped

**Symptoms:** Background image doesn't look right

**Cause:** Image aspect ratio doesn't match screen

**Solution:**
- Use 9:16 aspect ratio images (720×1280)
- Stretch mode is `STRETCH_KEEP_ASPECT_COVERED` (fills screen, may crop)
- Design images with safe area in center
- Test on multiple aspect ratios

---

## Best Practices

### Color Design

✅ **High contrast** - Ensure text is readable over background  
✅ **Consistent palette** - Use related colors from same family  
✅ **Accessibility** - Consider colorblind-friendly combinations  
✅ **Hierarchy** - Title brightest, secondary elements dimmer  

### Image Design

✅ **Consistent style** - Match game's art direction  
✅ **Safe area** - Keep important content in center 80%  
✅ **Optimization** - Compress images, use appropriate format  
✅ **Testing** - Test on different screen sizes  

### Performance

✅ **Image size** - Keep under 500 KB  
✅ **Caching** - Images are cached after first load  
✅ **Format** - Use JPEG for photos, PNG for graphics with transparency  
✅ **Resolution** - Don't use images larger than 2x screen resolution  

---

## Implementation Details

### Files Modified

**`scripts/LevelTransition.gd`:**
- Added `theme_colors` dictionary (lines 39-62)
- Added `background_image` variable (line 65)
- Updated `_ready()` to apply themes (lines 80-119)
- Added `apply_theme_colors()` function (lines 338-389)

### How It Works

```
Level Complete
    ↓
LevelTransition._ready()
    ↓
Get theme from ThemeManager
    ↓
apply_theme_colors(theme_name)
    ↓
1. Look up theme in theme_colors dictionary
2. Apply background color
3. Load background image (if specified)
4. Apply text colors (title, score, rewards)
5. Apply button colors (continue, replay)
    ↓
show_transition() displays themed screen
```

### Layering Order

**Visual stack (bottom to top):**
1. ColorRect (background color)
2. TextureRect (background image) - if present
3. UI Container
   - Title label
   - Score label
   - Rewards container
   - Buttons

**Z-Index:**
- Background: 0
- Image: 1
- UI: 2

---

## Future Enhancements

Potential additions for future versions:

- [ ] Animated background images (WebP, video)
- [ ] Particle effects per theme
- [ ] Audio cues per theme
- [ ] Gradient backgrounds
- [ ] Theme preview in settings
- [ ] Per-star-rating themes (3★, 2★, 1★)
- [ ] Achievement-based themes
- [ ] Seasonal themes (Halloween, Christmas, etc.)
- [ ] Community-created themes
- [ ] Theme editor tool

---

## Summary

The Level Transition Theming system provides:

✅ **Complete color customization** - 6 properties per theme  
✅ **Background image support** - Bundled and DLC assets  
✅ **Automatic theme detection** - From level data  
✅ **Dynamic switching** - Based on conditions  
✅ **Easy extensibility** - Simple dictionary structure  
✅ **Fallback handling** - Graceful degradation  

**The system is production-ready and fully documented!** 🎨✨

---

*For questions or issues, refer to the Troubleshooting section or check console logs for detailed debugging information.*
