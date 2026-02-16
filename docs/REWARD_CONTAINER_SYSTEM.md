# Reward Container System

**Last Updated:** February 16, 2026  
**Status:** ✅ Production Ready

---

## Overview

The Reward Container System provides a flexible, data-driven framework for animated reward containers (chests, boxes, scrolls) with:

- **Multiple Container Types** - Boxes, chests, scrolls with custom animations
- **Real Image Support** - Use PNG/JPG/SVG for container visuals
- **Data-Driven Selection** - JSON rules determine which container to use
- **Customizable Animations** - Configure timing, easing, anchor points
- **DLC-Friendly** - Automatic fallbacks for unknown themes

---

## Quick Start

### 1. Choose a Container

Containers live in `data/reward_containers/`:
- `simple_box.json` - Basic wooden box (default)
- `golden_chest.json` - Special milestone chest
- `biblical_scroll.json` - Scroll for biblical theme
- `fade_chest_example.json` - Custom fade animation

### 2. Configure Container Selection

**Option A: Theme-Based (Recommended)**

Edit `data/theme_container_mappings.json`:
```json
{
  "modern": {
    "reward_container": "simple_box"
  },
  "biblical": {
    "reward_container": "biblical_scroll"
  }
}
```

**Option B: Rule-Based**

Edit `data/container_selection_rules.json`:
```json
{
  "rules": [
    {
      "id": "milestone_levels",
      "enabled": true,
      "condition": {
        "type": "level_modulo",
        "divisor": 10,
        "remainder": 0
      },
      "container": "golden_chest"
    }
  ]
}
```

### 3. Play!

Container is automatically selected and animated based on your configuration.

---

## Container Configuration

### Basic Structure

```json
{
  "container_id": "my_container",
  "display_name": "My Container",
  "theme": "modern",
  
  "visual": {
    "type": "dual_layer",
    "base_layer": {
      "image": "res://textures/containers/chest_closed.png",
      "size": [300, 250]
    },
    "top_layer": {
      "image": "res://textures/containers/chest_lid.png",
      "size": [300, 100]
    }
  },
  
  "animations": {
    "open": {
      "type": "lid_rotate",
      "duration": 0.8,
      "easing": "ease_out",
      "rotation": -120,
      "pivot": "top_left"
    },
    "reveal": {
      "type": "spawn_rewards",
      "pattern": "interactive",
      "anchor": [0, -60]
    }
  }
}
```

---

## Visual Types

### 1. Dual Layer (Recommended)

Two images: base + lid/door that animates

```json
{
  "visual": {
    "type": "dual_layer",
    "base_layer": {
      "image": "res://textures/containers/chest_base.png",
      "size": [300, 250],
      "position": [0, 0]
    },
    "top_layer": {
      "image": "res://textures/containers/chest_lid.png",
      "size": [300, 100],
      "position": [0, -50]
    }
  }
}
```

**Use Cases:**
- Chests with opening lids
- Boxes with removable tops
- Doors that swing open

### 2. Single Layer

One image that fades/scales

```json
{
  "visual": {
    "type": "single_layer",
    "image": "res://textures/containers/scroll.png",
    "size": [400, 300]
  }
}
```

**Use Cases:**
- Scrolls that unroll
- Bags that expand
- Simple fade-in effects

### 3. Image Swap

Transition between closed and open images

```json
{
  "visual": {
    "type": "image_swap",
    "closed_image": "res://textures/containers/chest_closed.png",
    "open_image": "res://textures/containers/chest_open.png",
    "size": [300, 250],
    "transition": {
      "type": "fade",
      "duration": 0.3
    }
  }
}
```

**Use Cases:**
- Pre-rendered open/closed states
- Complex animations done in external tools
- Frame-by-frame style transitions

---

## Animation Types

### Open Animations

#### Lid Rotate

Rotates top layer around a pivot point:

```json
{
  "open": {
    "type": "lid_rotate",
    "duration": 0.8,
    "easing": "ease_out",
    "rotation": -120,
    "pivot": "top_left"
  }
}
```

**Pivot Options:**
- `"top_left"` - Hinged at top-left corner
- `"top_center"` - Hinged at top-center
- `"top_right"` - Hinged at top-right corner
- `"center"` - Rotates around center
- `[x, y]` - Custom pixel coordinates

**Rotation:**
- Negative = Counter-clockwise
- Positive = Clockwise
- Typical range: -180 to 180 degrees

#### Fade Out

Fades container to reveal rewards:

```json
{
  "open": {
    "type": "fade_out",
    "duration": 0.5,
    "easing": "ease_in",
    "target_alpha": 0.0
  }
}
```

#### Scale Up

Grows container then reveals:

```json
{
  "open": {
    "type": "scale_up",
    "duration": 0.6,
    "easing": "ease_out_back",
    "target_scale": [1.5, 1.5],
    "then": "fade_out"
  }
}
```

#### Slide

Slides lid/door to side:

```json
{
  "open": {
    "type": "slide",
    "duration": 0.7,
    "easing": "ease_in_out",
    "direction": "up",
    "distance": 150
  }
}
```

**Directions:** `"up"`, `"down"`, `"left"`, `"right"`

### Reveal Animations

#### Interactive (Recommended)

One-at-a-time with CLAIM button:

```json
{
  "reveal": {
    "type": "spawn_rewards",
    "pattern": "interactive",
    "anchor": [0, -60]
  }
}
```

**Anchor:** `[x, y]` offset from container center where rewards spawn

#### Burst

All rewards explode outward then fly to HUD:

```json
{
  "reveal": {
    "type": "spawn_rewards",
    "pattern": "burst",
    "anchor": [0, 0],
    "burst_radius": 100
  }
}
```

#### Cascade

Rewards appear sequentially with delay:

```json
{
  "reveal": {
    "type": "spawn_rewards",
    "pattern": "cascade",
    "anchor": [0, -60],
    "delay_between": 0.2
  }
}
```

#### Arc

Rewards fly in arcing motion:

```json
{
  "reveal": {
    "type": "spawn_rewards",
    "pattern": "arc",
    "anchor": [0, -60],
    "arc_height": 200
  }
}
```

---

## Customizing Containers

### Using Real Images

1. **Create your images:**
   - Base image (e.g., `chest_base.png`)
   - Lid/door image (e.g., `chest_lid.png`)
   - Recommended size: 300-500px wide
   - Format: PNG with transparency

2. **Place in textures folder:**
   ```
   textures/containers/my_chest_base.png
   textures/containers/my_chest_lid.png
   ```

3. **Create container JSON:**
   ```json
   {
     "container_id": "my_custom_chest",
     "visual": {
       "type": "dual_layer",
       "base_layer": {
         "image": "res://textures/containers/my_chest_base.png",
         "size": [400, 300]
       },
       "top_layer": {
         "image": "res://textures/containers/my_chest_lid.png",
         "size": [400, 120]
       }
     },
     "animations": {
       "open": {
         "type": "lid_rotate",
         "rotation": -110,
         "pivot": "top_left",
         "duration": 0.9
       },
       "reveal": {
         "type": "spawn_rewards",
         "pattern": "interactive"
       }
     }
   }
   ```

4. **Reference in mappings:**
   ```json
   {
     "modern": {
       "reward_container": "my_custom_chest"
     }
   }
   ```

### Adjusting Anchor Points

The anchor point determines where rewards spawn from:

```json
{
  "reveal": {
    "anchor": [0, -60]
  }
}
```

**Coordinate System:**
- `[0, 0]` = Center of container
- `[0, -60]` = 60 pixels above center (typical)
- `[50, 0]` = 50 pixels to the right of center
- `[-50, 30]` = 50 pixels left, 30 pixels down

**Visual Guide:**
```
        [0, -100]
           ↑
  [-50,0] ← [0,0] → [50,0]  (Container Center)
           ↓
        [0, 100]
```

### Timing and Easing

**Duration:**
- Fast: 0.3-0.5s
- Normal: 0.6-0.8s
- Slow: 0.9-1.2s

**Easing Options:**
- `"linear"` - Constant speed
- `"ease_in"` - Starts slow, ends fast
- `"ease_out"` - Starts fast, ends slow
- `"ease_in_out"` - Slow-fast-slow (smooth)
- `"ease_out_back"` - Overshoots then settles (bouncy)

```json
{
  "open": {
    "duration": 0.8,
    "easing": "ease_out_back"
  }
}
```

---

## Data-Driven Selection

### Priority Chain

Container selection follows this priority:

```
1. Manual Override (in experience flow JSON)
   ↓
2. Rule-Based Selection (container_selection_rules.json)
   ↓
3. Theme Mapping (theme_container_mappings.json)
   ↓
4. Default Fallback (_default or simple_box)
```

### Theme Mappings

**File:** `data/theme_container_mappings.json`

```json
{
  "modern": {
    "reward_container": "simple_box",
    "description": "Modern theme uses simple wooden box"
  },
  "biblical": {
    "reward_container": "biblical_scroll",
    "description": "Biblical theme uses scroll container"
  },
  "_default": {
    "reward_container": "simple_box",
    "description": "Fallback for unknown themes (DLC)"
  }
}
```

**DLC Support:**
- Unknown themes automatically use `_default`
- DLCs can include their own mapping JSON
- Graceful fallback ensures game never breaks

### Selection Rules

**File:** `data/container_selection_rules.json`

```json
{
  "rules": [
    {
      "id": "milestone_levels",
      "enabled": true,
      "description": "Every 10th level gets golden chest",
      "condition": {
        "type": "level_modulo",
        "divisor": 10,
        "remainder": 0
      },
      "container": "golden_chest"
    },
    {
      "id": "perfect_completion",
      "enabled": true,
      "description": "3-star completions get crystal chest",
      "condition": {
        "type": "stars_earned",
        "min": 3
      },
      "container": "crystal_chest"
    }
  ],
  "priority": "first_match",
  "fallback": "use_theme_mapping"
}
```

**Condition Types:**

| Type | Parameters | Example |
|------|------------|---------|
| `level_modulo` | divisor, remainder | Every 10th level |
| `level_in_list` | levels[] | Specific levels [10, 20, 30] |
| `level_range` | min, max | Levels 40-50 |
| `stars_earned` | min, max | 3-star completions |
| `coins_earned` | min, max | High coin rewards |
| `gems_earned` | min, max | Gem rewards |
| `total_value` | min, max, gem_multiplier | Combined value |

### Enabling/Disabling Rules

Change `"enabled"` flag:

```json
{
  "id": "milestone_levels",
  "enabled": true  // ← Change to false to disable
}
```

**No code changes or recompilation needed!**

---

## Examples

### Example 1: Simple Box

Basic wooden box with lid rotation:

```json
{
  "container_id": "simple_box",
  "display_name": "Simple Wooden Box",
  "theme": "modern",
  
  "visual": {
    "type": "dual_layer",
    "base_layer": {
      "image": "res://textures/containers/box_base.png",
      "size": [300, 250]
    },
    "top_layer": {
      "image": "res://textures/containers/box_lid.png",
      "size": [300, 100]
    }
  },
  
  "animations": {
    "open": {
      "type": "lid_rotate",
      "duration": 0.8,
      "easing": "ease_out",
      "rotation": -120,
      "pivot": "top_left"
    },
    "reveal": {
      "type": "spawn_rewards",
      "pattern": "interactive",
      "anchor": [0, -60]
    }
  }
}
```

### Example 2: Fade Chest

Chest that fades to reveal rewards:

```json
{
  "container_id": "fade_chest",
  "display_name": "Magical Fade Chest",
  
  "visual": {
    "type": "single_layer",
    "image": "res://textures/containers/magic_chest.png",
    "size": [350, 280]
  },
  
  "animations": {
    "open": {
      "type": "fade_out",
      "duration": 0.6,
      "easing": "ease_in",
      "target_alpha": 0.0
    },
    "reveal": {
      "type": "spawn_rewards",
      "pattern": "burst",
      "anchor": [0, 0],
      "burst_radius": 120
    }
  }
}
```

### Example 3: Biblical Scroll

Scroll that unrolls:

```json
{
  "container_id": "biblical_scroll",
  "display_name": "Ancient Scroll",
  "theme": "biblical",
  
  "visual": {
    "type": "image_swap",
    "closed_image": "res://textures/containers/scroll_closed.png",
    "open_image": "res://textures/containers/scroll_open.png",
    "size": [400, 300],
    "transition": {
      "type": "fade",
      "duration": 0.4
    }
  },
  
  "animations": {
    "reveal": {
      "type": "spawn_rewards",
      "pattern": "cascade",
      "anchor": [0, -80],
      "delay_between": 0.25
    }
  }
}
```

---

## Architecture Compliance

Follows **ARCHITECTURE_GUARDRAILS.md**:

### ✅ Data Separate from Logic
- All container configs in JSON
- Zero hardcoded container logic
- Easy to modify without code changes

### ✅ DLC-Friendly
- `_default` fallback for unknown themes
- Rules can be overridden per DLC
- New containers via JSON only

### ✅ No God Orchestrator
- `RewardContainer` only handles container visuals (< 400 lines)
- `ContainerSelectionRules` only evaluates data (< 150 lines)
- `RewardTransitionController` stays thin (< 500 lines)

### ✅ Single Responsibility
- `RewardContainer` - Container visuals and animations
- `ContainerConfigLoader` - JSON loading
- `ContainerSelectionRules` - Rule evaluation
- `RewardTransitionController` - Orchestration

---

## Troubleshooting

### Container Not Found

**Symptom:** Falls back to `simple_box` or `_default`

**Check:**
1. Container ID matches between mapping and config file
2. JSON file exists in `data/reward_containers/`
3. No typos in container ID
4. JSON is valid (no syntax errors)

### Animation Not Playing

**Check:**
1. Animation type is correct (`"lid_rotate"`, `"fade_out"`, etc.)
2. Duration is greater than 0
3. Images are loaded correctly
4. Pivot point is valid for rotation animations

### Wrong Container Selected

**Check selection priority:**
1. Is there a manual override in flow JSON?
2. Do any rules match? (Check `enabled: true`)
3. Is theme mapped correctly?
4. Does `_default` exist?

### Images Not Loading

**Check:**
1. File path is correct (`res://` prefix)
2. File exists in specified location
3. Image format is supported (PNG, JPG, SVG)
4. `.import` file exists (Godot generates this)

---

## File Locations

### Container Configs
```
data/reward_containers/
  simple_box.json
  golden_chest.json
  crystal_chest.json
  biblical_scroll.json
  fade_chest_example.json
```

### Theme Mappings
```
data/theme_container_mappings.json
```

### Selection Rules
```
data/container_selection_rules.json
```

### Container Images
```
textures/containers/
  box_base.png
  box_lid.png
  chest_closed.png
  chest_open.png
  scroll_closed.png
  scroll_open.png
```

---

## Production Status

**Functionality:** ✅ All container types working  
**Performance:** ✅ Smooth 60 FPS animations  
**Stability:** ✅ No errors, handles missing files gracefully  
**Flexibility:** ✅ Fully data-driven, zero hardcoded logic  
**DLC Support:** ✅ Automatic fallbacks, extensible  

**Status:** READY FOR PRODUCTION ✅

---

## Summary

The Reward Container System provides:

✅ **Flexible Containers** - Multiple types, real images, custom animations  
✅ **Data-Driven** - JSON configuration, no hardcoded logic  
✅ **Rule-Based Selection** - Conditional container choice by level/performance  
✅ **Theme Support** - Different containers per theme  
✅ **DLC-Friendly** - Automatic fallbacks, extensible via JSON  
✅ **Production Ready** - Stable, performant, well-tested  

**Provides a complete solution for animated reward containers!** 🎁
