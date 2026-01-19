# Bonus Moves System - "Sugar Crush" Feature

## Date: January 16, 2026
## Status: ✅ IMPLEMENTED & FIXED

## Recent Fix (Jan 16, 2026)
**Issue**: Players could continue playing after level completion (reward screen never shown)

**Solution**:
1. Set `level_transitioning = true` at start of bonus phase
2. Set `processing_moves = true` during bonus conversion
3. Set `moves_left = 0` after bonus completes
4. Keep `level_transitioning = true` after emitting level_complete signal
5. Store original moves_left for accurate star calculation

This ensures:
- ✅ No input during bonus phase
- ✅ No moves available after completion
- ✅ Level transition screen shows properly
- ✅ Stars calculated correctly based on efficiency

## Overview
When players complete a level with remaining moves, those moves are converted into special tiles that auto-activate for bonus points. This creates an exciting visual celebration and helps players achieve higher star ratings.

## Inspiration
Similar to Candy Crush's "Sugar Crush" feature where remaining moves create special candies after level completion.

## How It Works

### Trigger Conditions
- Player reaches target score
- Moves remaining > 0

### Conversion Process
1. **Level Complete Detected** - GameManager detects score >= target
2. **Pause Before Transition** - Small delay to finish animations
3. **Bonus Phase Begins** - "🎉 BONUS! Converting X remaining moves..."
4. **For Each Remaining Move**:
   - Find random active tile (non-blocked, non-empty, non-special)
   - Convert to Four-Way Arrow special tile
   - Flash visual effect (white-yellow glow)
   - Play transformation sound
   - Wait 0.1s for visual impact
   - Auto-activate the special tile
   - Award progressive bonus points (100, 200, 300, etc.)
5. **Stars Calculated** - Final score includes all bonus points
6. **Transition to Rewards** - Show stars and rewards screen

### Bonus Points Formula
```
Move 1: 100 points
Move 2: 200 points
Move 3: 300 points
Move N: 100 * N points

Total Bonus = 100 * (1 + 2 + 3 + ... + N)
            = 100 * N * (N + 1) / 2
```

### Examples

**5 Remaining Moves:**
- Total Bonus = 100 * 5 * 6 / 2 = 1,500 points

**10 Remaining Moves:**
- Total Bonus = 100 * 10 * 11 / 2 = 5,500 points

**15 Remaining Moves:**
- Total Bonus = 100 * 15 * 16 / 2 = 12,000 points

## Implementation Details

### GameManager.gd

**Function: `_convert_remaining_moves_to_bonus(remaining_moves: int)`**
```gdscript
Purpose: Convert remaining moves to special tiles and activate them
Process:
  1. Set processing_moves = true (lock player input)
  2. Get GameBoard reference
  3. For each remaining move:
     - Get random active tile position
     - Set tile type to FOUR_WAY_ARROW
     - Update visual via GameBoard
     - Wait 0.1s
     - Activate special tile
     - Calculate and add bonus points
  4. Set processing_moves = false (release lock)
  5. Log total bonus
```

**Function: `_get_random_active_tile_position() -> Vector2`**
```gdscript
Purpose: Find a random tile suitable for conversion
Criteria:
  - Not blocked
  - Not empty (type > 0)
  - Not already special (type < 7)
Returns: Random valid position or (-1, -1) if none found
```

**Modified: `on_level_complete()`**
```gdscript
# At start of bonus phase:
level_transitioning = true  # Lock out all gameplay
var original_moves_left = moves_left  # Store for star calculation

if moves_left > 0:
    await _convert_remaining_moves_to_bonus(moves_left)
    moves_left = 0  # Consume all moves
    emit_signal("moves_changed", moves_left)

# Use original_moves_left for star calculation
var moves_used = total_moves - original_moves_left

# At end: Keep level_transitioning = true (prevents further gameplay)
# Signal emitted, but flag stays true until next level loads
```

### GameBoard.gd

**Function: `update_tile_visual(grid_pos: Vector2, new_type: int)`**
```gdscript
Purpose: Update tile appearance when converted to special
Effects:
  - Calls tile.update_type(new_type)
  - Flash tween: Color(3,3,1) → WHITE over 0.3s
  - Plays "special_create" sound
  - Logs conversion
```

## Visual Effects

### Conversion
- **Flash Color**: Bright white-yellow (3x intensity)
- **Duration**: 0.3 seconds
- **Sound**: "special_create" sfx
- **Delay Between**: 0.1s per move (rapid but visible)

### Activation
- **Lightning Beams**: Magenta cross pattern (horizontal + vertical)
- **Particle Effects**: Radial burst at activation point
- **Score Popup**: +100, +200, +300 text (from existing system)

## Impact on Gameplay

### Strategic Implications
1. **Efficiency Rewarded**: Beating level quickly = more bonus moves
2. **Star Boost**: Can upgrade from 1★ to 2★ or 3★ with bonus
3. **Score Padding**: Helps marginal completions feel more rewarding
4. **Visual Spectacle**: Exciting end-of-level celebration

### Balance Considerations
- **Max Moves**: 20 moves → max 2,100 bonus points
- **Not Overpowered**: Requires efficient play to get many remaining moves
- **Fair**: Good players get rewarded, struggling players still complete
- **Engaging**: Turns "wasted moves" into celebration

## Edge Cases Handled

1. **No Active Tiles**: Function returns Vector2(-1,-1), skips that move
2. **Board Full of Specials**: Unlikely, but checked with type < 7 filter
3. **Zero Remaining Moves**: Check `if moves_left > 0` prevents execution
4. **GameBoard Missing**: Null check, logs error, skips bonus
5. **Activation Fails**: Continues to next move even if one fails

## Performance

- **Async Operations**: Uses `await` to prevent blocking
- **Small Delays**: 0.1s per move keeps it snappy (5 moves = 0.5s)
- **Efficient Search**: Single pass through grid for random position
- **No Memory Leaks**: All tweens auto-cleanup via finished signal

## Future Enhancements

### Possible Improvements
1. **Variable Special Types**: Mix of different specials instead of all Four-Way
2. **Cascade Bonus**: Let special tile activations create cascades
3. **Animation Polish**: Particle trails connecting conversions
4. **Sound Variation**: Different pitch/sound for each move
5. **Multiplier Display**: Show "2x BONUS!" text overlay
6. **Skill Shot**: Tap to trigger next conversion early (mini-game)

### Difficulty Scaling
- **Easy Levels**: More moves → more potential bonus
- **Hard Levels**: Fewer moves → completing with remainder is impressive
- **Expert Levels**: Very few moves → big bonus feels earned

## Testing Scenarios

### Scenario 1: Small Bonus
```
Target: 1000
Score at completion: 1100
Remaining: 3 moves
Bonus: 100+200+300 = 600
Final: 1700 (170% of target = 2 stars)
```

### Scenario 2: Large Bonus
```
Target: 5000
Score at completion: 8000
Remaining: 10 moves
Bonus: 100+200+...+1000 = 5500
Final: 13500 (270% of target = 3 stars)
```

### Scenario 3: No Bonus
```
Target: 2000
Score at completion: 2100
Remaining: 0 moves
Bonus: 0
Final: 2100 (105% of target = 1 star)
```

### Scenario 4: Efficiency Master
```
Target: 3000
Score at completion: 4500
Remaining: 15 moves (75% efficiency!)
Bonus: 100+200+...+1500 = 12000
Final: 16500 (550% of target = 3 stars!)
Star from efficiency: ALSO 3 stars (≤50% moves used)
Result: Double 3-star achievement!
```

## Logs to Check

When testing, look for these console messages:

```
[GameManager] 🎉 BONUS! Converting 5 remaining moves to special tiles!
[GameBoard] Updated tile at (3, 4) to type 9 (special)
[GameManager] Bonus move 1/5: Created special tile at (3, 4), +100 points
[GameBoard] Creating cross lightning for four-way arrow at (3, 4)
[GameManager] Bonus move 2/5: Created special tile at (1, 2), +200 points
...
[GameManager] 🌟 Bonus complete! Total bonus points: 1500
[GameManager] Level completed with 3 stars! (Score: 13500, Target: 10000, Moves: 5/20)
```

## Success Criteria

✅ **Functional**: Remaining moves convert to specials
✅ **Visual**: Flash effects and animations play
✅ **Audio**: Sound effects trigger
✅ **Scoring**: Progressive bonus points added
✅ **Stars**: Final score includes bonus for rating
✅ **Fun**: Creates exciting end-of-level moment!

---

**Status:** Ready for Testing! 🎮⭐
**Impact:** High (improves player satisfaction and retention)
**Risk:** Low (self-contained feature, doesn't affect core gameplay)

