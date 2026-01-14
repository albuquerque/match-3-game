# Level Transition System

## Overview
The level transition system provides a clean separation between level completion and the next level loading. This creates a better user experience and allows for future enhancements like story elements or progress maps.

## Implementation

### New Files
- `scripts/LevelTransition.gd` - Dedicated transition screen shown between levels

### Modified Files
- `scripts/GameUI.gd` - Integrated transition screen into game flow
- `scripts/GameBoard.gd` - Improved tile clearing and creation logging

## Flow

### Old Flow (Before)
1. Level completes
2. Level complete dialog appears **on top of game board**
3. Player clicks continue
4. Next level loads
5. Start page shows
6. Player clicks start
7. **Problem**: Board tiles don't populate properly

### New Flow (After)
1. Level completes
2. **Game board is hidden immediately**
3. **Transition screen appears (fullscreen, opaque)**
   - Shows level completed, final score
   - Displays rewards (coins, gems)
   - Automatically claims rewards
   - Shows "Continue to Next Level" button
4. Player clicks Continue
5. Next level data is loaded in background
6. Start page appears with new level info
7. Player clicks Start
8. Game board becomes visible with tiles already created

## Benefits

### User Experience
- Clean visual separation between levels
- No overlapping dialogs on game board
- Clear reward display
- Proper screen transitions

### Technical
- Fixes tile population issues after level complete
- Prevents double-loading of level data
- Better state management
- Improved debugging with logging

### Future Extensibility
The transition screen is designed to accommodate future features:
- **Story elements**: Add narrative text or images between levels
- **Progress map**: Show player's position on a level map
- **Achievements**: Display newly unlocked achievements
- **Statistics**: Show level statistics (combos, special tiles used, etc.)
- **Social features**: Share level completion on social media
- **Challenges**: Present special challenges for the next level
- **Power-up tutorials**: Introduce new boosters or mechanics

## Code Structure

### LevelTransition.gd
```gdscript
func show_transition(completed_level, final_score, coins_earned, gems_earned, has_next_level)
```
- Creates fullscreen opaque background
- Displays level completion information
- Shows rewards and auto-claims them
- Emits signals for game flow control

### Signals
- `continue_pressed` - Player wants to proceed
- `rewards_claimed` - Rewards have been granted

## Usage

### Showing the Transition
```gdscript
level_transition.show_transition(
    GameManager.level,      # Completed level number
    GameManager.score,      # Final score
    coins_earned,           # Coins reward
    gems_earned,            # Gems reward
    has_next_level          # Whether there's a next level
)
```

### Handling Continue
```gdscript
func _on_transition_continue():
    # Called when player clicks continue
    _advance_to_next_level()
```

## Configuration

The transition screen can be customized by modifying `LevelTransition.gd`:

- **Background color**: `background.color` in `_ready()`
- **Title text**: `title_label.text` in `show_transition()`
- **Font sizes**: `add_theme_font_size_override()` calls
- **Layout**: Modify VBoxContainer and child positioning
- **Animations**: Add tween animations in `show_transition()`

## Testing

To test the transition system:
1. Play a level and complete it
2. Verify the transition screen appears with correct information
3. Verify rewards are granted (check coins/gems counters)
4. Click Continue
5. Verify start page appears for next level
6. Click Start
7. Verify game board displays correctly with tiles

## Known Issues
None currently.

## Future Enhancements
1. Add animations (fade in, slide in effects)
2. Add star rating system (1-3 stars based on performance)
3. Add level statistics display
4. Add social sharing buttons
5. Add "replay level" option
6. Add story/dialogue system integration
7. Add progress map integration

