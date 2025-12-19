# Audio System Implementation

## Overview
Added comprehensive music and sound effects system to the match-3 game using an AudioManager singleton.

## Components Added

### 1. AudioManager (Autoload Singleton)
- **File**: `scripts/AudioManager.gd`
- **Features**:
  - Music playback with crossfading between tracks
  - SFX player pool for multiple simultaneous sounds
  - Separate volume controls for music and SFX
  - Enable/disable toggles for music and SFX
  - Automatic fallback when all SFX players are busy

### 2. Audio Buses
- **File**: `default_bus_layout.tres`
- **Buses**:
  - Master (default)
  - Music (for background music)
  - SFX (for sound effects)

### 3. Music Tracks
Located in `audio/music/`:
- `menu_loop.mp3` - Plays on main menu and start page
- `game_loop.mp3` - Plays during gameplay

### 4. Sound Effects
Located in `audio/sfx/`:
- `ui_click.mp3` - Button clicks and menu interactions
- `tile_swap.mp3` - When tiles are swapped
- `match_chime.mp3` - When tiles are matched
- `combo_chime.mp3` - When combo/cascade matches occur

## Integration Points

### Main Menu
- Plays menu music on load
- UI click sound on play button

### Game UI (Start Page & In-Game)
- Menu music on start page
- Transitions to game music when level starts
- UI click sounds on all buttons:
  - Menu button
  - Restart/Continue buttons
  - All booster buttons (Hammer, Shuffle, Swap, etc.)
  - Settings/Shop/About menu items

### Game Board
- Tile swap sound when tiles are swapped
- Match sound on first match
- Combo sound on cascade matches (depth > 1)

## Usage Examples

### Playing Music
```gdscript
# Play with crossfade
AudioManager.play_music("game", 1.0)

# Stop with fade out
AudioManager.stop_music(0.5)
```

### Playing Sound Effects
```gdscript
# Play with default volume
AudioManager.play_sfx("ui_click")

# Play with volume multiplier
AudioManager.play_sfx("match", 1.5)
```

### Volume Control
```gdscript
# Set music volume (0.0 to 1.0)
AudioManager.set_music_volume(0.7)

# Set SFX volume (0.0 to 1.0)
AudioManager.set_sfx_volume(0.8)

# Enable/disable
AudioManager.set_music_enabled(true)
AudioManager.set_sfx_enabled(false)
```

## Audio Settings
Current default volumes:
- Music: 70% (0.7)
- SFX: 80% (0.8)

Both are enabled by default.

## Future Enhancements
- Add settings UI for volume sliders
- Add more varied SFX for different actions
- Add voice-over support (voice/ folder is ready)
- Add level complete/fail specific music stingers
- Add booster-specific sound effects

