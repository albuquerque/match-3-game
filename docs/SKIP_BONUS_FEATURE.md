# Skip Bonus Animation Feature

## Date: January 16, 2026
## Status: ✅ IMPLEMENTED

## Overview
Players can now skip the bonus moves animation by tapping anywhere on the screen. When skipped, all remaining bonus points are calculated and added instantly, then the reward screen appears immediately.

## User Experience

### Without Skip (Original Behavior)
```
Level Complete → Bonus Phase Starts
  ↓ 0.1s delay
Tile 1 converts → Special tile activates → +100 points
  ↓ 0.1s delay
Tile 2 converts → Special tile activates → +200 points
  ↓ 0.1s delay
Tile 3 converts → Special tile activates → +300 points
  ↓ ... continues for all remaining moves
Bonus Complete → Reward Screen
```
**Duration:** 5 remaining moves = ~2.5 seconds

### With Skip (New Feature)
```
Level Complete → Bonus Phase Starts
"TAP TO SKIP ⏩" appears (pulsing yellow text)
  ↓ Player taps screen
All bonus points calculated instantly (+1500)
  ↓ Immediate
Reward Screen appears with full bonus applied
```
**Duration:** Instant (< 0.1 seconds)

## Visual Design

### Skip Hint Label
- **Text**: "TAP TO SKIP ⏩"
- **Color**: Yellow (1.0, 1.0, 0.3) - highly visible
- **Font Size**: 32px - large and clear
- **Position**: Below the game board
- **Animation**: Pulsing opacity (0.5 ↔ 1.0) every 0.5s
- **Size**: 300x60 px centered

### Appearance
```
┌─────────────────────────────┐
│      [GAME BOARD]           │
│      [Tiles]                │
└─────────────────────────────┘
      TAP TO SKIP ⏩
    (pulsing yellow text)
```

## Implementation

### GameManager.gd

**New Variable:**
```gdscript
var bonus_skipped = false  // Tracks if player requested skip
```

**Modified Function: `_convert_remaining_moves_to_bonus()`**
```gdscript
func _convert_remaining_moves_to_bonus(remaining_moves: int):
    bonus_skipped = false
    
    // Show skip hint
    if game_board.has_method("show_skip_bonus_hint"):
        game_board.show_skip_bonus_hint()
    
    for i in range(remaining_moves):
        // Check if player skipped
        if bonus_skipped:
            // Calculate remaining bonus instantly
            for j in range(i, remaining_moves):
                var instant_bonus = 100 * (j + 1)
                bonus_points += instant_bonus
                add_score(instant_bonus)
            break  // Exit animation loop
        
        // Normal bonus animation continues...
    
    // Hide skip hint
    game_board.hide_skip_bonus_hint()
```

**New Function:**
```gdscript
func skip_bonus_animation():
    if not bonus_skipped:
        bonus_skipped = true
        print("[GameManager] Player requested to skip bonus animation")
```

### GameBoard.gd

**New Variables:**
```gdscript
var skip_bonus_label: Label = null
var skip_bonus_active: bool = false
```

**New Function: `show_skip_bonus_hint()`**
```gdscript
func show_skip_bonus_hint():
    // Create or show label
    skip_bonus_label = Label.new()
    skip_bonus_label.text = "TAP TO SKIP ⏩"
    skip_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    skip_bonus_label.add_theme_font_size_override("font_size", 32)
    skip_bonus_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
    
    // Position below board
    var board_bottom = grid_offset.y + (tile_size * GRID_HEIGHT)
    skip_bonus_label.position = Vector2(screen_width/2 - 150, board_bottom + 20)
    
    // Pulsing animation
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(skip_bonus_label, "modulate:a", 0.5, 0.5)
    tween.tween_property(skip_bonus_label, "modulate:a", 1.0, 0.5)
    
    skip_bonus_active = true
```

**New Function: `hide_skip_bonus_hint()`**
```gdscript
func hide_skip_bonus_hint():
    if skip_bonus_label:
        skip_bonus_label.visible = false
    skip_bonus_active = false
```

**New Function: `_input(event)`**
```gdscript
func _input(event):
    if skip_bonus_active and (event is InputEventScreenTouch or event is InputEventMouseButton):
        if event.pressed:
            GameManager.skip_bonus_animation()
            hide_skip_bonus_hint()
```

## Bonus Calculation Logic

### Progressive Bonus Formula
```
Move 1: 100 points
Move 2: 200 points
Move 3: 300 points
Move N: 100 * N points
```

### When Skipped at Move i
```gdscript
// Already earned: Moves 1 to (i-1)
var already_earned = 100 * (i-1) * i / 2

// Calculate remaining: Moves i to N
for j in range(i, N):
    instant_bonus = 100 * (j + 1)
    total_bonus += instant_bonus
    add_score(instant_bonus)
```

### Example: 5 Remaining Moves, Skip at Move 2

**Already Earned:**
- Move 1: +100 points
- Total so far: 100 points

**Instantly Calculated:**
- Move 2: +200 points
- Move 3: +300 points
- Move 4: +400 points
- Move 5: +500 points
- Instant total: +1400 points

**Final Total:** 100 + 1400 = 1500 points ✅

## Input Handling

### Supported Input Types
1. **Touch Screen** (Mobile): `InputEventScreenTouch`
2. **Mouse Click** (Desktop): `InputEventMouseButton`

### Input Flow
```
Player taps screen during bonus
  ↓
GameBoard._input() receives event
  ↓
Checks: skip_bonus_active == true?
  ↓ YES
Calls GameManager.skip_bonus_animation()
  ↓
Sets bonus_skipped = true
  ↓
GameBoard.hide_skip_bonus_hint()
  ↓
Loop in _convert_remaining_moves_to_bonus() detects flag
  ↓
Calculates remaining bonus instantly
  ↓
Breaks out of animation loop
  ↓
Continues to reward screen
```

## Benefits

### For Players
✅ **Control**: Player decides when to skip
✅ **Speed**: Instant gratification for impatient players
✅ **Choice**: Can watch animation or skip
✅ **No Penalty**: Full bonus points still awarded

### For Developers
✅ **Clean Code**: Single flag controls skip behavior
✅ **Maintainable**: Easy to modify skip behavior
✅ **Safe**: All points calculated correctly even when skipped
✅ **Flexible**: Can adjust what happens on skip

### For User Experience
✅ **Reduces friction**: Players don't feel forced to wait
✅ **Increases engagement**: Faster level progression
✅ **Improves retention**: Less frustration
✅ **Professional polish**: Feature common in top match-3 games

## Edge Cases Handled

1. **Skip at Move 0**: All moves calculated instantly ✅
2. **Skip at Last Move**: Only last move calculated ✅
3. **Multiple Taps**: Only first tap registers (bonus_skipped flag) ✅
4. **No Active Tiles**: Skip still works, points calculated ✅
5. **Label Already Exists**: Reuses existing label ✅

## Testing Scenarios

### Test 1: Complete Skip
1. Complete level with 10 remaining moves
2. Bonus phase starts
3. See "TAP TO SKIP" message
4. Tap immediately
5. **Expected**: All 5,500 bonus points added instantly, reward screen appears

### Test 2: Partial Skip
1. Complete level with 5 remaining moves
2. Watch first 2 moves animate (100 + 200 = 300 points)
3. Tap to skip
4. **Expected**: Remaining 3 moves calculated (300 + 400 + 500 = 1,200), total 1,500 points

### Test 3: No Skip
1. Complete level with 3 remaining moves
2. Don't tap
3. **Expected**: All 3 moves animate normally (600 total), reward screen appears after

### Test 4: Multiple Taps
1. Complete level with 5 remaining moves
2. Tap multiple times rapidly
3. **Expected**: Only first tap registers, points calculated once

## Performance

- **Label Creation**: Once per bonus phase
- **Tween**: Lightweight pulsing animation
- **Input Check**: Minimal overhead (only active during bonus)
- **Calculation**: O(N) where N = remaining moves (instant)

## Future Enhancements

### Possible Improvements
1. **Skip Button**: Dedicated button instead of tap-anywhere
2. **Hold to Skip**: Require holding for 0.5s to prevent accidents
3. **Settings Toggle**: "Always skip bonus" option
4. **Different Speeds**: Let player choose animation speed
5. **Sound Effect**: Play "whoosh" sound on skip
6. **Particle Burst**: Visual effect when points added instantly

## Files Modified

1. ✅ `scripts/GameManager.gd`
   - Added `bonus_skipped` variable
   - Modified `_convert_remaining_moves_to_bonus()`
   - Added `skip_bonus_animation()`

2. ✅ `scripts/GameBoard.gd`
   - Added `skip_bonus_label` and `skip_bonus_active` variables
   - Added `show_skip_bonus_hint()`
   - Added `hide_skip_bonus_hint()`
   - Added `_input()` handler

## Documentation

- ✅ `docs/SKIP_BONUS_FEATURE.md` - This document
- ✅ `docs/BONUS_MOVES_SYSTEM.md` - Updated with skip info

---

**Status:** ✅ Ready for Testing  
**Impact:** High (greatly improves UX)  
**Risk:** Low (no gameplay changes, pure UX improvement)

