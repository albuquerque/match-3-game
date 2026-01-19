# Match-3 Animations and Effects

## Overview
Enhanced visual feedback system with particle effects, animations, and screen shake - similar to popular match-3 games like Candy Crush.

## Features Implemented

### 1. Tile Destruction Effects
**Location**: `scripts/Tile.gd` - `animate_destroy()` and `_create_destruction_particles()`

- **Pop Animation**: Tiles scale up 1.3x before shrinking to zero
- **Rotation**: 1.5 rotations during destruction
- **Color Flash**: Bright white flash before fading
- **Particle Explosion**: 25 colored particles burst outward (upgraded from 12)
  - Color matches tile type (1.3x brighter for impact)
  - **Scale**: 1.0 to 2.5 (much larger and more visible)
  - **Velocity**: 120-250 px/s (faster, more dramatic)
  - **Gravity**: 300 (stronger arc)
  - **Lifetime**: 0.8 seconds
  - Particles have gravity and angular velocity (540°/s)
  - Bright gradient with glow effect (starts at 1.5x color brightness)
  - Auto-cleanup after animation

**Sound**: Plays `tile_match` SFX on destruction

### 2. Tile Spawn Animations
**Location**: `scripts/Tile.gd` - `animate_spawn()`

- **Bouncy Entry**: Uses TRANS_BACK easing for overshoot effect
- **Scale Sequence**:
  1. Pop to 1.3x size (0.15s)
  2. Settle to normal size (0.15s)
- **Rotation Wiggle**: ±0.1 radians rotation during spawn
- **Total Duration**: ~0.3 seconds

### 3. Combo Text Effects
**Location**: `scripts/GameBoard.gd` - `_show_combo_text()` and combo tracking

Displays floating text for matches based on **combo chains** and **match size**:

#### Combo Chain Messages (Priority)
| Combo Chain | Text | Color | When |
|-------------|------|-------|------|
| 5+ chains | "INCREDIBLE! x5" | Bright Magenta | 5+ consecutive matches |
| 4 chains | "AMAZING! x4" | Magenta | 4 consecutive matches |
| 3 chains | "SUPER! x3" | Orange | 3 consecutive matches |
| 2 chains | "COMBO! x2" | Green | 2 consecutive matches |

#### Match Size Messages
| Match Size | Text | Color |
|------------|------|-------|
| 7+ tiles | "AMAZING!" | Magenta |
| 6 tiles | "SUPER!" | Orange |
| 5 tiles | "GREAT!" | Green |
| 4 tiles | "GOOD!" | Blue |
| 3 tiles | "NICE!" | Light Blue |

**Combo System**:
- Tracks consecutive matches (cascades)
- Resets after 2 seconds of no matches
- Combo multiplier shown in text (e.g., "SUPER! x3")
- Shows for: **All 4+ tile matches**, **any cascade (2+ chain)**, or special conditions
- **Only skips plain 3-tile matches** on first move
- **Positioned at screen center** (upper-middle) for full visibility

**Animation**:
- Pop-in with elastic overshoot effect (TRANS_BACK)
- Scales to 1.3x then settles to 1.0x
- Holds for 0.4 seconds
- Fades out over 0.2 seconds
- Font size: 56pt with 5px black outline
- Centered horizontally with 400px width

### 4. Screen Shake
**Location**: `scripts/GameBoard.gd` - `_apply_screen_shake()`

Triggered for matches of 5+ tiles OR 3+ combo chains:
- **Duration**: 0.15 seconds
- **Intensity**: max(match_count * 2, combo_chain * 3) pixels
- **Pattern**: Random directional shake each frame
- Smoothly returns to original position
- **Examples**:
  - 5-tile match = 10 pixel shake
  - 3-chain combo = 9 pixel shake
  - 6-tile match on 4th chain = 12 pixel shake

### 5. Special Tile Activation Effects
**Location**: `scripts/GameBoard.gd` - `highlight_special_activation()` and `_create_special_activation_particles()`

- **Flash Animation**: Tiles flash bright yellow/white
- **Radial Particle Burst**: 40 golden/white particles (upgraded from 20)
  - **Scale**: 1.5 to 3.5 (much larger and more impressive)
  - **Velocity**: 150-350 px/s (faster burst)
  - **Radial acceleration**: 80-150 (stronger outward push)
  - Emission radius: 10px
  - No gravity (floats outward)
  - **Lifetime**: 1.2 seconds (longer visibility)
  - Bright golden glow (starts at 1.5x brightness)
  - Star-like appearance with dynamic scaling
- **Sound**: Plays `special_tile` SFX for 4+ tile matches

### 6. Cascade Combo System
**Location**: `scripts/GameBoard.gd` - `animate_destroy_matches()`

Automatically triggers visual effects based on match size:
- 4+ tiles: Shows combo text
- 5+ tiles: Adds screen shake
- Particles for all matches

### 7. Lightning Beam Effects ⚡
**Location**: `scripts/GameBoard.gd` - `_create_lightning_beam_horizontal()`, `_create_lightning_beam_vertical()`

**Special Tile Activations**:
- **Horizontal Arrow (Type 7)**: Yellow lightning beam shoots across the row
- **Vertical Arrow (Type 8)**: Cyan lightning beam shoots down the column
- **Four-Way Arrow (Type 9)**: Magenta cross - both horizontal and vertical beams with 0.05s stagger

**Row Clear Booster**:
- **Dual lightning beams** shoot horizontally across the row
- Colors: Yellow (1.0, 1.0, 0.3) and Orange-yellow (1.0, 0.8, 0.0)
- **Zigzag pattern** with 8 segments for realistic lightning
- Random vertical offset (±30% of tile size)
- **Width**: 12px → 20px → 15-18px (pulse) - Sleek and visible
- **Brightness**: 3x normal during flash (very bright)
- **Duration**: ~0.4 seconds
- **Line caps**: Rounded for smoother appearance
- **Impact particles** at each tile position (yellow)

**Column Clear Booster**:
- **Dual lightning beams** shoot vertically down the column
- Colors: Cyan (0.3, 0.8, 1.0) and Bright cyan (0.5, 1.0, 1.0)
- **Zigzag pattern** with 8 segments
- Random horizontal offset (±30% of tile size)
- **Width**: 12px → 20px → 15-18px (pulse) - Sleek and visible
- **Brightness**: 3x normal during flash (very bright)
- **Duration**: ~0.4 seconds
- **Line caps**: Rounded for smoother appearance
- **Impact particles** at each tile position (cyan)

**Line Blast Booster** (3 rows/columns):
- Creates staggered lightning beams (0.05s delay between each)
- Horizontal: Yellow beams across 3 rows
- Vertical: Cyan beams down 3 columns
- Creates dramatic cascading effect

**Beam Animation Sequence**:
1. Flash in (0.05s) - Very bright (3x) and wider (20px)
2. Pulse (0.2s) - Width oscillates 15px ↔ 18px
3. Fade out (0.2s) - Opacity to 0
4. Auto-cleanup

## Animation Timing

```
Tile Destruction: 0.3s total
├─ Pop up: 0.1s
├─ Shrink: 0.2s
└─ Particles: 0.6s (overlaps)

Tile Spawn: 0.3s total
├─ Bounce in: 0.15s
├─ Settle: 0.15s
└─ Rotation: 0.3s (parallel)

Combo Text: 1.1s total
├─ Fade in: 0.2s
├─ Display: 0.5s
└─ Fade out: 0.3s

Special Activation: 0.18s
├─ Flash bright: 0.06s
└─ Flash back: 0.12s
```

## Particle Configuration

### Destruction Particles (Per Tile)
- Amount: 25 (upgraded for more impact)
- Lifetime: 0.8s
- Velocity: 120-250 px/s (faster)
- Spread: 180 degrees
- Gravity: (0, 300) (stronger)
- Angular Velocity: ±540 deg/s (more rotation)
- Scale: 1.0-2.5 (much larger)
- Color: Tile color × 1.3 (brighter)
- Explosiveness: 0.9

### Special Activation Particles
- Amount: 40 (doubled for wow factor)
- Lifetime: 1.2s (longer)
- Velocity: 150-350 px/s (faster burst)
- Radial emission (10px radius)
- No gravity
- Radial Acceleration: 80-150
- Angular Velocity: ±360 deg/s
- Scale: 1.5-3.5 (much larger)
- Color: Golden/white gradient (1.5x brightness)
- Explosiveness: 1.0

## Sound Effects Used

- `tile_match` - Normal tile destruction
- `special_tile` - Special tile activation (4+ match)
- `ui_click` - (existing, not added by this feature)

## Performance Considerations

1. **Particle Cleanup**: All particles auto-cleanup after 1-1.2 seconds
2. **Tween Pooling**: Uses Godot's built-in tween system (efficient)
3. **Conditional Effects**: Screen shake only for 5+ matches
4. **One-Shot Particles**: All particles use `one_shot = true`

## Future Enhancements

1. **More Combo Levels**: Add "INCREDIBLE!" for 10+ matches
2. **Rainbow Effects**: Multi-colored particles for special tiles
3. **Chain Reaction Visualization**: Connect lines between cascading matches
4. **Celebration Animations**: Fireworks for level completion
5. **Streak Effects**: Visual feedback for consecutive matches
6. **Haptic Feedback**: Vibration on mobile for big matches
7. **Trail Effects**: Particle trails during tile swaps
8. **Impact Waves**: Ripple effect from match center

## Customization

### Adjusting Particle Count
```gdscript
# In Tile.gd _create_destruction_particles()
particles.amount = 20  # Increase for more particles
```

### Changing Shake Intensity
```gdscript
# In GameBoard.gd animate_destroy_matches()
_apply_screen_shake(0.15, matches.size() * 3)  # Multiply by 3 instead of 2
```

### Modifying Combo Thresholds
```gdscript
# In GameBoard.gd _show_combo_text()
if match_count >= 8:  # Change threshold
    combo_text = "FANTASTIC!"
```

### Adjusting Animation Speed
```gdscript
# In Tile.gd animate_destroy()
tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.2)  # Faster: 0.15s
```

## Testing

To see all effects:
1. Create matches of varying sizes (3, 4, 5, 6, 7+)
2. Activate special tiles (bomb, line blast, etc.)
3. Observe cascading combos for multiple effects
4. Check console for particle creation logs (if debug enabled)

## Known Issues

None currently - all animations working as expected.

### Fixed Issues

**Modern Theme Scaling (Jan 15, 2026)**
- **Issue**: Tiles appeared too large during pop animation in modern theme
- **Cause**: Animation was using absolute scale values instead of relative to sprite's current scale
- **Fix**: Changed `animate_destroy()` to scale relative to `sprite.scale` instead of using `tile_scale` directly
- **Impact**: Pop animation now correctly scales to 1.3x of the tile's actual size regardless of theme

**Combo Text Missing for Special Tiles (Jan 15, 2026)**
- **Issue**: Combo text didn't appear when special tiles were being created or for multiple simultaneous combos
- **Cause**: `animate_destroy_matches_except()` (used when creating special tiles) didn't have combo tracking logic
- **Fix**: Added full combo tracking, text display, and screen shake to `animate_destroy_matches_except()`
- **Impact**: Combo text now shows for ALL matches including special tile creation (4+ matches, T/L shapes)

**Combo Text Positioning (Jan 15, 2026)**
- **Issue**: Combo text could appear partially off-screen at board edges
- **Cause**: Text was positioned at match location instead of screen center
- **Fix**: Changed positioning to always use screen center (upper-middle)
- **Impact**: Combo text is now always fully visible and readable

## Credits

Inspired by popular match-3 games:
- Candy Crush (particle effects, combo text)
- Bejeweled (screen shake, tile pop)
- Toon Blast (bouncy spawns)

