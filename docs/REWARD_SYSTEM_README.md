# Reward System Documentation

## Overview
The reward system manages player progression, currencies, and unlockables in the match-3 game.

## Current Implementation Status

### ✅ Phase 1: Foundation (COMPLETED)
**Currency System**
- **Coins** (Soft Currency) - Starting balance: 500
- **Gems** (Premium Currency) - Starting balance: 50
- **Lives** - Maximum: 5, regenerates 1 every 30 minutes

**Core Features Implemented:**
1. **RewardManager Singleton** (`scripts/RewardManager.gd`)
   - Currency management (coins, gems)
   - Lives system with auto-regeneration
   - Persistent storage (JSON save file: `user://player_progress.json`)
   - Daily login streak tracking
   - Booster inventory management
   - Theme unlock system
   - Achievement tracking

2. **Level Completion Rewards**
   - Base coin reward: `100 + (50 × level_number)`
   - Star system (1-3 stars based on performance):
     - 1 star: 100%-149% of target score
     - 2 stars: 150%-199% of target score
     - 3 stars: 200%+ of target score
   - Bonus gems: 5 gems for first 3-star completion per level

3. **Daily Login System**
   - Tracks consecutive login days
   - Automatic reward distribution:
     - Day 1: 50 coins
     - Day 2: 75 coins
     - Day 3: 100 coins + 5 gems
     - Day 4: 125 coins
     - Day 5: 150 coins
     - Day 6: 175 coins
     - Day 7: 200 coins + 25 gems + 1 hammer booster

4. **UI Integration**
   - Currency display panel showing coins, gems, and lives
   - Real-time updates when currencies change
   - Animated feedback for currency changes

5. **Save/Load System**
   - Automatic saving after every change
   - Persistent player progress across sessions
   - Saves:
     - Currencies (coins, gems, lives)
     - Booster inventory
     - Daily streak data
     - Theme unlocks
     - Achievement progress
     - Level completion statistics

## API Reference

### RewardManager Signals
```gdscript
signal coins_changed(new_amount: int)
signal gems_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal booster_changed(booster_type: String, new_amount: int)
```

### Currency Functions
```gdscript
# Add/spend coins
RewardManager.add_coins(amount: int)
RewardManager.spend_coins(amount: int) -> bool

# Add/spend gems
RewardManager.add_gems(amount: int)
RewardManager.spend_gems(amount: int) -> bool

# Get current amounts
RewardManager.get_coins() -> int
RewardManager.get_gems() -> int
RewardManager.get_lives() -> int
```

### Lives Functions
```gdscript
# Use a life (returns false if no lives available)
RewardManager.use_life() -> bool

# Add lives
RewardManager.add_life(amount: int = 1)

# Refill all lives
RewardManager.refill_lives()

# Get time until next life regenerates (in seconds)
RewardManager.get_time_until_next_life() -> float
```

### Booster Functions
```gdscript
# Add booster to inventory
RewardManager.add_booster(booster_type: String, amount: int = 1)

# Use a booster (returns false if not available)
RewardManager.use_booster(booster_type: String) -> bool

# Check booster count
RewardManager.get_booster_count(booster_type: String) -> int
```

**Available Booster Types:**
- `"hammer"` - Destroy any tile
- `"shuffle"` - Reorganize board
- `"row_clear"` - Clear entire row
- `"column_clear"` - Clear entire column
- `"extra_moves"` - Start with +5 moves
- `"color_reducer"` - Remove 1 tile type

### Level Completion
```gdscript
# Grant rewards after level completion (called automatically by GameManager)
RewardManager.grant_level_completion_reward(level_number: int, stars: int)
```

### Theme Management
```gdscript
# Unlock a theme
RewardManager.unlock_theme(theme_name: String)

# Check if theme is unlocked
RewardManager.is_theme_unlocked(theme_name: String) -> bool

# Set selected theme
RewardManager.set_selected_theme(theme_name: String) -> bool
```

### Save System
```gdscript
# Save current progress (called automatically)
RewardManager.save_progress()

# Load saved progress (called automatically on startup)
RewardManager.load_progress()

# Reset all progress (for debugging)
RewardManager.reset_progress()
```

## Save File Structure
The player progress is saved in JSON format at `user://player_progress.json`:

```json
{
  "coins": 500,
  "gems": 50,
  "lives": 5,
  "last_life_regen_time": 1733654400.0,
  "boosters": {
    "hammer": 0,
    "shuffle": 0,
    "row_clear": 0,
    "column_clear": 0,
    "extra_moves": 0,
    "color_reducer": 0
  },
  "daily_streak": 1,
  "last_login_date": "2024-12-08",
  "total_stars": 0,
  "levels_completed": 0,
  "unlocked_themes": ["legacy"],
  "selected_theme": "legacy",
  "achievements_unlocked": [],
  "total_matches": 0,
  "total_special_tiles_used": 0
}
```

## Future Phases

### Phase 2: Core Rewards (Planned)
- Lives system with UI and refill options
- Shop system for purchasing boosters
- Reward notifications and popups

### Phase 3: Boosters (Planned)
- Pre-game boosters implementation
- In-game boosters implementation
- Booster shop UI
- Usage tracking and analytics

### Phase 4: Themes & Unlockables (Planned)
- Theme shop UI with previews
- Purchase/unlock logic
- Star-based progression gates
- Special unlock conditions

### Phase 5: Advanced Features (Planned)
- Battle Pass system
- Daily challenges
- Achievement system with rewards
- Ad integration (AdMob)

### Phase 6: Polish & Testing (Planned)
- Economy balancing
- UI polish and animations
- Comprehensive testing
- Analytics integration

## Testing

To test the reward system:

1. **Start a new game** - You should receive 500 coins and 50 gems
2. **Complete a level** - Observe coin rewards based on level number
3. **Check star rating** - Stars are calculated based on score vs target
4. **Close and reopen** - Progress should persist
5. **Daily login** - Close app, change system date, reopen to test streak
6. **Currency display** - Watch for animated updates in the UI

## Notes

- The RewardManager is a singleton (autoload) accessible globally
- All currency changes are automatically saved
- Lives regenerate passively every 30 minutes
- First-time players start with starter currencies (500 coins, 50 gems)
- Daily streak resets if player misses a day

---

**Last Updated:** December 8, 2024  
**Version:** Phase 1 Complete

