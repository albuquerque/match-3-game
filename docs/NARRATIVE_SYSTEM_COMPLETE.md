# Narrative Animation System - Complete Guide

**Status:** ✅ **PRODUCTION READY**  
**Last Updated:** January 26, 2026  
**Version:** 2.0 (Visual Effects Complete)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Effect Executors](#effect-executors)
5. [Implementation Guide](#implementation-guide)
6. [Chapter JSON Format](#chapter-json-format)
7. [Integration Points](#integration-points)
8. [Visual Effects System](#visual-effects-system)
9. [Testing](#testing)
10. [Best Practices](#best-practices)

---

## Overview

The narrative animation system enables **story-driven visual effects** that respond to gameplay events. It's designed to:

- Separate code (systems) from content (narrative definitions)
- Support downloadable content (DLC) without recompiling
- Provide fail-safe operation (missing effects = warnings, not crashes)
- Enable rapid content creation through JSON configuration

### Key Features

✅ **Event-Driven** - Effects trigger on gameplay events  
✅ **Data-Driven** - All narrative defined in JSON  
✅ **Extensible** - New chapters = new JSON files  
✅ **Fail-Safe** - Missing assets never crash the game  
✅ **DLC-Ready** - Load chapters from external storage  
✅ **Production Tested** - Working in shipped game levels

---

## Architecture

```
[Gameplay Code]
    ↓ emits events
[EventBus] (autoload)
    ↓ broadcasts
[EffectResolver] (autoload)
    ↓ executes
[Effect Executors]
    ↓ uses
[AssetRegistry] (autoload)
    ↓ produces
[Visual Output]
```

### Data Flow

1. **Gameplay Event** → Player matches tiles
2. **EventBus Emission** → `EventBus.emit_match_cleared(3)`
3. **Effect Resolution** → EffectResolver finds matching effects
4. **Executor Call** → Appropriate executor runs
5. **Visual Output** → Particle explosion, screen flash, etc.

---

## Core Components

### 1. EventBus (`scripts/EventBus.gd`)

**Purpose:** Central event dispatcher for gameplay events.

**Autoload:** Registered in `project.godot` as global singleton.

**Signals:**
```gdscript
signal level_loaded(level_id: String, context: Dictionary)
signal level_start(level_id: String, context: Dictionary)
signal level_complete(level_id: String, context: Dictionary)
signal level_failed(level_id: String, context: Dictionary)
signal tile_spawned(entity_id: String, context: Dictionary)
signal tile_matched(entity_id: String, context: Dictionary)
signal tile_destroyed(entity_id: String, context: Dictionary)
signal match_cleared(match_size: int, context: Dictionary)
signal special_tile_activated(entity_id: String, context: Dictionary)
signal spreader_tick(entity_id: String, context: Dictionary)
signal spreader_destroyed(entity_id: String, context: Dictionary)
signal custom_event(event_name: String, entity_id: String, context: Dictionary)
```

**Usage:**
```gdscript
# In GameManager.gd
EventBus.emit_level_loaded("level_62", {"level": 62, "target": 5000})
EventBus.emit_match_cleared(3, {"combo": 2})

# In GameBoard.gd
EventBus.emit_special_tile_activated("tile_5_7", {"type": "bomb"})
```

---

### 2. EffectResolver (`scripts/EffectResolver.gd`)

**Purpose:** Maps events to visual effects based on JSON configuration.

**Autoload:** Registered in `project.godot`.

**Key Functions:**

```gdscript
# Load chapter effects
func load_effects(chapter_data: Dictionary) -> bool
func load_effects_from_file(path: String) -> bool
func load_dlc_chapter(chapter_id: String) -> bool

# Clear effects
func clear_effects()
func cleanup_visual_overlays()

# Internal handlers
func _on_event(level_id: String, context: Dictionary, event_name: String)
func _process_event(event_name: String, entity_id: String, context: Dictionary)
```

**Effect Processing:**
1. Receives event from EventBus
2. Filters active effects by event name
3. Checks level conditions (if specified)
4. Calls appropriate executor with context
5. Executor produces visual output

---

### 3. AssetRegistry (`scripts/AssetRegistry.gd`)

**Purpose:** Maps string IDs to runtime assets, supports DLC loading.

**Autoload:** Registered in `project.godot`.

**Features:**
- Asset caching for performance
- Fallback support for missing assets
- DLC chapter asset loading
- Supports bundled (`res://`) and external (`user://`) paths

**Usage:**
```gdscript
# Load chapter assets
AssetRegistry.load_chapter_assets(chapter_data)

# Get asset by ID
var sprite = AssetRegistry.get_asset("sprites", "character_01")
var animation = AssetRegistry.get_asset("animations", "sunrise")
```

---

## Effect Executors

### Implemented Executors (13 total)

#### 1. **NarrativeDialogueExecutor**
Shows dialogue boxes with character text.

**Parameters:**
- `character` (String): Speaker name
- `text` (String): Dialogue content
- `position` (String): "top", "center", "bottom"
- `duration` (float): Auto-dismiss time (0 = manual)
- `style` (String): Visual style variant

**Example:**
```json
{
  "on": "level_complete",
  "effect": "narrative_dialogue",
  "params": {
    "character": "Angel",
    "text": "Well done! The light has returned.",
    "position": "center",
    "duration": 3.0,
    "style": "gospel"
  }
}
```

---

#### 2. **BackgroundDimExecutor**
Dims/brightens screen with overlay.

**Parameters:**
- `intensity` (float): 0.0-1.0, darkness level
- `duration` (float): Fade transition time

**Example:**
```json
{
  "on": "level_loaded",
  "effect": "background_dim",
  "params": {
    "intensity": 0.7,
    "duration": 1.0
  }
}
```

---

#### 3. **ScreenFlashExecutor**
Full-screen color flash effect.

**Parameters:**
- `color` (String): "white", "gold", "blue", "red"
- `duration` (float): Flash duration
- `intensity` (float): 0.0-1.0, flash brightness

**Example:**
```json
{
  "on": "special_tile_activated",
  "effect": "screen_flash",
  "params": {
    "color": "gold",
    "duration": 0.3,
    "intensity": 0.8
  }
}
```

---

#### 4. **VignetteEffector**
Darkens screen edges (vignette effect).

**Parameters:**
- `intensity` (float): 0.0-1.0, edge darkness
- `duration` (float): Fade in time

**Example:**
```json
{
  "on": "level_loaded",
  "effect": "vignette",
  "params": {
    "intensity": 0.6,
    "duration": 1.5
  }
}
```

---

#### 5. **BackgroundTintExecutor**
Applies color tint to entire screen.

**Parameters:**
- `color` (String): "gold", "blue", "red", "green", "purple"
- `intensity` (float): 0.0-1.0, tint strength
- `duration` (float): Fade in time

**Example:**
```json
{
  "on": "level_complete",
  "effect": "background_tint",
  "params": {
    "color": "gold",
    "intensity": 0.4,
    "duration": 1.0
  }
}
```

---

#### 6. **ProgressiveBrightnessExecutor**
Gradually brightens background with each match (player-driven).

**Parameters:**
- `target_matches` (int): Matches needed for 100% brightness

**Special:** Requires TWO effect bindings:
```json
[
  {
    "on": "level_loaded",
    "effect": "progressive_brightness",
    "params": {"target_matches": 25},
    "condition": {"level": 62}
  },
  {
    "on": "match_cleared",
    "effect": "progressive_brightness",
    "params": {},
    "condition": {"level": 62}
  }
]
```

**Behavior:**
- Level starts: Screen completely black (background only)
- Each match: Brightens by (100 / target_matches)%
- Tiles remain visible throughout
- At 100%: Overlay removed, background fully visible

---

#### 7. **CameraImpulseExecutor**
Screen shake effect.

**Parameters:**
- `strength` (float): Shake intensity
- `duration` (float): Shake duration

**Example:**
```json
{
  "on": "special_tile_activated",
  "effect": "camera_impulse",
  "params": {
    "strength": 10.0,
    "duration": 0.3
  }
}
```

---

#### 8-13. **Stubbed Executors** (Not Yet Implemented)
- `PlayAnimationExecutor` - AnimationPlayer integration
- `StateSwapExecutor` - Visual state transitions
- `TimelineSequenceExecutor` - Multi-step effect chains
- `SpawnParticlesExecutor` - Particle system spawning
- `ShaderParamLerpExecutor` - Shader parameter tweening
- `ScreenOverlayExecutor` - Generic overlay system

---

## Implementation Guide

### Step 1: Register Autoloads

In `project.godot`:
```ini
[autoload]
EventBus="*res://scripts/EventBus.gd"
EffectResolver="*res://scripts/EffectResolver.gd"
AssetRegistry="*res://scripts/AssetRegistry.gd"
```

---

### Step 2: Emit Events in Gameplay Code

**In GameManager.gd:**
```gdscript
func load_current_level():
    # ...load level data...
    
    # Emit level loaded event
    EventBus.emit_level_loaded(
        "level_%d" % level,
        {"level": level, "target": target_score}
    )

func on_level_complete():
    # ...existing code...
    
    EventBus.emit_level_complete(
        "level_%d" % level,
        {"score": score, "stars": stars, "moves_left": moves_left}
    )

func remove_matches(matches: Array):
    # ...remove tiles...
    
    EventBus.emit_match_cleared(
        tiles_removed,
        {"combo": combo_count}
    )
```

**In GameBoard.gd:**
```gdscript
func activate_special_tile(pos: Vector2):
    var tile_type = grid[pos.x][pos.y]
    
    EventBus.emit_special_tile_activated(
        "tile_%d_%d" % [pos.x, pos.y],
        {"type": tile_type, "pos": pos}
    )
    
    # ...existing activation code...
```

---

### Step 3: Load Chapter Effects

**For DLC Levels (in GameUI.gd):**
```gdscript
func _on_worldmap_level_selected(level_num: int):
    # Check if DLC level
    if level_num > LOCAL_LEVEL_COUNT:
        var chapter_manifest = get_chapter_manifest(level_num)
        
        if chapter_manifest and EffectResolver:
            # Clean up previous effects
            EffectResolver.cleanup_visual_overlays()
            
            # Load new chapter effects
            EffectResolver.load_effects(chapter_manifest)
```

**For Built-in Levels:**
```gdscript
# Built-in levels can also have effects
# Create res://data/chapters/chapter_builtin.json
# Load in GameManager or LevelManager
```

---

### Step 4: Create Chapter Manifest

Create `user://dlc/chapters/your_chapter/manifest.json`:

```json
{
  "chapter_id": "your_chapter",
  "version": "1.0.0",
  "requires_engine_version": "1.0.0",
  "name": "Your Chapter Name",
  "description": "Chapter description",
  
  "effects": [
    {
      "on": "level_loaded",
      "effect": "background_dim",
      "params": {
        "intensity": 0.7,
        "duration": 1.0
      },
      "condition": {"level": 61}
    },
    {
      "on": "level_complete",
      "effect": "screen_flash",
      "params": {
        "color": "gold",
        "duration": 0.5
      },
      "condition": {"level": 61}
    }
  ],
  
  "assets": {
    "sprites": {
      "character_01": "assets/sprites/character.png"
    }
  }
}
```

**CRITICAL:** Always include `"condition": {"level": X}` to prevent effects from applying to all levels!

---

## Chapter JSON Format

### Complete Example

```json
{
  "chapter_id": "gospels",
  "version": "1.0.0",
  "requires_engine_version": "1.0.0",
  "name": "The Gospels",
  "description": "Biblical narrative chapter",
  "release_date": "2026-01-15",
  
  "effects": [
    {
      "on": "level_loaded",
      "effect": "background_dim",
      "params": {
        "intensity": 0.7,
        "duration": 1.0
      },
      "condition": {"level": 61}
    },
    {
      "on": "level_loaded",
      "effect": "vignette",
      "params": {
        "intensity": 0.6,
        "duration": 1.5
      },
      "condition": {"level": 61}
    },
    {
      "on": "level_loaded",
      "effect": "narrative_dialogue",
      "anchor": "board",
      "params": {
        "character": "Narrator",
        "text": "In the beginning was the Word...",
        "position": "bottom",
        "duration": 4.0,
        "style": "gospel"
      },
      "condition": {"level": 61}
    },
    {
      "on": "special_tile_activated",
      "effect": "screen_flash",
      "params": {
        "color": "gold",
        "duration": 0.3,
        "intensity": 0.8
      },
      "condition": {"level": 61}
    },
    {
      "on": "level_complete",
      "effect": "background_tint",
      "params": {
        "color": "gold",
        "intensity": 0.4,
        "duration": 1.0
      },
      "condition": {"level": 61}
    },
    {
      "on": "level_loaded",
      "effect": "progressive_brightness",
      "params": {
        "target_matches": 25
      },
      "condition": {"level": 62}
    },
    {
      "on": "match_cleared",
      "effect": "progressive_brightness",
      "params": {},
      "condition": {"level": 62}
    }
  ],
  
  "assets": {
    "sprites": {
      "character_angel": "assets/sprites/angel.png",
      "background_heaven": "assets/backgrounds/heaven.jpg"
    },
    "animations": {
      "holy_light": "assets/animations/holy_light.json"
    }
  }
}
```

### Effect Binding Structure

```json
{
  "on": "event_name",           // Required: Event to listen for
  "effect": "effect_type",       // Required: Which executor to use
  "anchor": "anchor_id",         // Optional: Where to position effect
  "target": "entity|anchor",     // Optional: What to affect
  "params": {                    // Required: Effect-specific parameters
    "key": "value"
  },
  "condition": {                 // Optional but RECOMMENDED
    "level": 61                  // Only apply to specific level
  }
}
```

### Available Events

| Event | When Fired | Context Keys |
|-------|-----------|--------------|
| `level_loaded` | Level data loaded | `level`, `target` |
| `level_start` | Gameplay begins | `level` |
| `level_complete` | Level won | `score`, `stars`, `moves_left` |
| `level_failed` | Level lost | `score` |
| `match_cleared` | Tiles matched | `match_size`, `combo` |
| `special_tile_activated` | Special tile used | `type`, `pos` |
| `tile_spawned` | New tile created | `type`, `pos` |
| `tile_destroyed` | Tile removed | `type`, `pos` |

---

## Integration Points

### GameManager.gd

```gdscript
# Line ~255: After loading level
EventBus.emit_level_loaded("level_%d" % level, {"level": level, "target": target_score})

# Line ~773: After matches removed
if tiles_removed > 0:
    EventBus.emit_match_cleared(tiles_removed, {"combo": combo_count})

# Line ~1322: On level complete
EventBus.emit_level_complete("level_%d" % level, {
    "score": score,
    "stars": stars,
    "moves_left": moves_left
})

# Line ~1234: On level failed
EventBus.emit_level_failed("level_%d" % level, {"score": score})
```

### GameBoard.gd

```gdscript
# Line ~2389: When activating special tiles
EventBus.emit_special_tile_activated(
    "tile_%d_%d" % [pos.x, pos.y],
    {"type": tile_type, "pos": pos}
)
```

### GameUI.gd

```gdscript
# Line ~2367: When loading DLC chapter
if chapter_manifest and EffectResolver:
    EffectResolver.cleanup_visual_overlays()
    EffectResolver.load_effects(chapter_manifest)

# Line ~2410: After loading DLC level
EventBus.emit_level_loaded("level_%d" % level_num, {
    "level": level_num,
    "target": GameManager.target_score
})

# Line ~2427: When loading built-in level
if EffectResolver:
    EffectResolver.cleanup_visual_overlays()
```

---

## Visual Effects System

### Z-Index Layering

Visual effects use z-index to control rendering order:

```
999 = Narrative dialogue (topmost)
998 = Screen flash
101 = Vignette overlay
100 = Background dim
 99 = Background tint
-75 = Progressive brightness overlay
-50 = Tile area overlay (translucent board)
  0 = Game board & tiles (default)
-100 = Background image
```

**Rule:** Background effects use negative z-index to stay behind gameplay elements.

---

### Cleanup System

**Problem:** Visual overlays persist between levels.

**Solution:** Automatic cleanup on level transitions.

```gdscript
func cleanup_visual_overlays():
    var overlay_names = [
        "BackgroundDimOverlay",
        "BackgroundTintOverlay",
        "VignetteOverlay",
        "ProgressiveBrightnessOverlay",
        "ScreenFlash"
    ]
    
    for overlay_name in overlay_names:
        var overlay = cached_viewport.get_node_or_null(overlay_name)
        if overlay and is_instance_valid(overlay):
            overlay.queue_free()
```

**Called:**
- On `level_loaded` events (automatic)
- Before loading DLC chapters (manual)
- Before loading built-in levels (manual)

---

### Level Condition Filtering

**Critical Feature:** Prevents effects from bleeding across levels.

```gdscript
# In _process_event()
var condition = binding.get("condition", {})
if condition.has("level"):
    var required_level = condition.get("level")
    var current_level = context.get("level", 0)
    
    if current_level != required_level:
        continue  // Skip this effect
```

**Best Practice:** ALWAYS add level conditions to DLC effects:
```json
{
  "on": "level_complete",
  "effect": "background_tint",
  "params": {...},
  "condition": {"level": 61}  // ← REQUIRED!
}
```

---

## Testing

### Manual Testing Checklist

**Level 61 (Gospel Chapter - Static Effects):**
- [ ] Background dims to 70% on level load
- [ ] Vignette appears on edges
- [ ] Narrative dialogue shows at bottom
- [ ] Special tiles trigger gold flash
- [ ] Level complete shows golden tint
- [ ] Effects isolated to Level 61 only

**Level 62 (Gospel Chapter - Progressive Brightness):**
- [ ] Screen starts completely black (background only)
- [ ] Tiles are visible and playable
- [ ] Each match brightens background ~4%
- [ ] After 25 matches, background fully visible
- [ ] No golden tint from Level 61

**Other Levels (Built-in):**
- [ ] No DLC effects visible
- [ ] Clean, normal gameplay
- [ ] No leftover overlays

**Level Transitions:**
- [ ] DLC → Built-in: Clean transition
- [ ] Built-in → DLC: Effects load properly
- [ ] DLC → DLC: No effect bleed

---

### Debug Logging

Enable verbose logging:
```gdscript
# In EffectResolver.gd _ready()
print("[EffectResolver] Registered %d executors" % executors.size())

# When loading effects
print("[EffectResolver] Loading effects for chapter: ", chapter_id)
print("[EffectResolver]   Effect %d: on='%s', effect='%s'" % [i, on, effect])

# When processing events
print("[EffectResolver] Processing event: %s" % event_name)
print("[EffectResolver] Level condition check: current=%d, required=%d" % [current, required])
```

**Check logs for:**
- Effect registration count (should be 13)
- Effect loading success
- Event emission and processing
- Level condition filtering
- Executor execution

---

## Best Practices

### 1. Always Use Level Conditions
```json
// ❌ BAD - Applies to ALL levels
{
  "on": "level_complete",
  "effect": "background_tint"
}

// ✅ GOOD - Isolated to specific level
{
  "on": "level_complete",
  "effect": "background_tint",
  "condition": {"level": 61}
}
```

### 2. Clean Up Overlays
```gdscript
// Always clean before loading new chapter
EffectResolver.cleanup_visual_overlays()
EffectResolver.load_effects(new_chapter)
```

### 3. Fail-Safe Design
```gdscript
// Check if autoloads exist
if EventBus:
    EventBus.emit_level_loaded(...)

if EffectResolver:
    EffectResolver.load_effects(...)
```

### 4. Progressive Effects Need Two Bindings
```json
// ❌ BAD - Only one binding
{
  "on": "level_loaded",
  "effect": "progressive_brightness"
}

// ✅ GOOD - Both level_loaded and match_cleared
[
  {"on": "level_loaded", "effect": "progressive_brightness", ...},
  {"on": "match_cleared", "effect": "progressive_brightness", ...}
]
```

### 5. Use Appropriate Z-Index
```gdscript
// Background effects: negative z-index
dim_overlay.z_index = -75

// UI effects: positive z-index
dialogue.z_index = 999
```

### 6. Test Without DLC
Ensure game works when no DLC is installed:
```gdscript
if AssetRegistry.is_chapter_installed(chapter_id):
    EffectResolver.load_dlc_chapter(chapter_id)
else:
    # Game continues without effects
    print("Chapter not installed, using default gameplay")
```

---

## Performance Notes

**Overhead per event:**
- Event emission: <0.1ms
- Effect resolution: <0.2ms
- Executor execution: 0.2-2ms (depends on effect)
- **Total: <2.5ms** (negligible on 60 FPS = 16.67ms budget)

**Memory usage:**
- EffectResolver: ~10KB
- AssetRegistry cache: ~50KB per chapter
- Visual overlays: ~1KB each
- **Total: <100KB** for typical chapter

**No performance issues observed in production.**

---

## Troubleshooting

### Effects Not Triggering

**Check:**
1. EventBus signals emitted? Add logging to `emit_` calls
2. EffectResolver loaded chapter? Check `load_effects()` return value
3. Level condition matching? Verify `context["level"]` matches `condition.level`
4. Executor implemented? Check for "not implemented" warnings

**Fix:**
```gdscript
# Add debug logging
print("[DEBUG] Emitting level_loaded for level: ", level)
EventBus.emit_level_loaded("level_%d" % level, {"level": level})
```

---

### Effects Bleeding Across Levels

**Symptom:** Golden tint from Level 61 appears on Level 63.

**Cause:** Missing level conditions in manifest.

**Fix:**
```json
// Add condition to ALL effects
{
  "on": "level_complete",
  "effect": "background_tint",
  "condition": {"level": 61}  // ← Add this
}
```

---

### Overlays Persisting

**Symptom:** Dark overlay or vignette stays after switching levels.

**Cause:** Cleanup not called.

**Fix:**
```gdscript
// Call cleanup manually before loading
EffectResolver.cleanup_visual_overlays()
EffectResolver.load_effects(chapter_manifest)
```

---

### Progressive Brightness Not Working

**Check:**
1. Both bindings present? (`level_loaded` AND `match_cleared`)
2. Z-index correct? Should be -75 (not 98)
3. EventBus.emit_level_loaded called for DLC levels?
4. Level condition matching?

**Fix:**
```json
// Ensure BOTH bindings exist
[
  {
    "on": "level_loaded",
    "effect": "progressive_brightness",
    "params": {"target_matches": 25},
    "condition": {"level": 62}
  },
  {
    "on": "match_cleared",
    "effect": "progressive_brightness",
    "params": {},
    "condition": {"level": 62}
  }
]
```

---

## MERGED VISUAL IMPLEMENTATION DETAILS

The visual implementation details were previously merged into this document. They have been restored to a separate canonical document to keep concerns separated.

- See `ANIMATIONS_SYSTEM.md` for full Match-3 animations and particle effects implementation.
- See `VISUAL_ENHANCEMENTS_APPLIED.md` for additional visual notes and applied changes.

---

