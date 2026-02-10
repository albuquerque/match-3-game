# RewardOrchestrator System

**Status:** ✅ Implemented - Phase 12  
**Last Updated:** February 10, 2026

---

## Overview

RewardOrchestrator is a centralized system that manages reward timing and distribution across the game. It ensures rewards appear at the right time during level transitions and coordinates with the ExperienceDirector for narrative flow rewards.

**Purpose:**
- Centralize all reward distribution logic
- Manage timing of reward notifications
- Coordinate with ExperienceDirector for flow-based rewards
- Ensure rewards appear on transition screen, not during gameplay

---

## Architecture

### Components

**RewardOrchestrator.gd** (Autoload Singleton)
- Manages reward queue
- Controls timing of reward notifications
- Interfaces with RewardManager
- Provides signal-based coordination

**Integration Points:**
- ExperienceDirector → Triggers rewards from flow nodes
- LevelTransition → Displays rewards during transition
- RewardManager → Actually grants rewards to player
- RewardNotification → Shows visual feedback

---

## How It Works

### Flow

```
1. Level Complete
   ↓
2. ExperienceDirector advances to reward node
   ↓
3. RewardOrchestrator.process_rewards() called
   ↓
4. Rewards queued for transition screen
   ↓
5. LevelTransition shows rewards
   ↓
6. RewardManager.add_coins() / add_gems()
   ↓
7. RewardNotification displays
   ↓
8. Signal: reward_processing_complete
   ↓
9. ExperienceDirector advances to next level
```

### Timing

**Problem Solved:**
- Previously: Rewards could appear during gameplay or at wrong times
- Now: Rewards always appear on transition screen in correct sequence

**Key Feature:**
- Waits for transition screen to be visible
- Shows all rewards with proper timing
- Ensures notifications don't overlap with next level

---

## API Reference

### RewardOrchestrator

**Autoload:** `RewardOrchestrator`

#### Signals

```gdscript
signal reward_processing_complete()
# Emitted when all rewards have been processed and displayed
# ExperienceDirector waits for this before advancing
```

#### Methods

```gdscript
func process_rewards(reward_data: Dictionary) -> void
```
**Description:** Process rewards from an experience flow reward node

**Parameters:**
- `reward_data` (Dictionary) - Reward node data from experience flow
  - `coins` (int, optional) - Coins to grant
  - `gems` (int, optional) - Gems to grant
  - `boosters` (Dictionary, optional) - Boosters to grant
  - `lives` (int, optional) - Lives to grant

**Example:**
```gdscript
var reward_data = {
    "coins": 100,
    "gems": 5,
    "boosters": {
        "hammer": 2,
        "swap": 1
    }
}
RewardOrchestrator.process_rewards(reward_data)
await RewardOrchestrator.reward_processing_complete
# Now rewards are displayed and player has received them
```

---

```gdscript
func grant_level_rewards(coins: int, gems: int) -> void
```
**Description:** Grant rewards earned from completing a level

**Parameters:**
- `coins` (int) - Coins earned from level score
- `gems` (int) - Gems earned from level (usually 0-3 based on stars)

**Example:**
```gdscript
# Called when level completes
var coins_earned = calculate_coin_reward(final_score)
var gems_earned = star_rating  # 0-3 stars
RewardOrchestrator.grant_level_rewards(coins_earned, gems_earned)
```

---

```gdscript
func grant_bonus_rewards(bonus_data: Dictionary) -> void
```
**Description:** Grant bonus rewards from special events

**Parameters:**
- `bonus_data` (Dictionary) - Bonus reward data
  - `coins` (int, optional)
  - `gems` (int, optional)
  - `reason` (String, optional) - Why bonus was granted

**Example:**
```gdscript
RewardOrchestrator.grant_bonus_rewards({
    "coins": 50,
    "reason": "Daily Login Bonus"
})
```

---

## Usage Examples

### Example 1: Experience Director Integration

```gdscript
# ExperienceDirector.gd
func _process_reward_node(node: Dictionary):
    print("[ExperienceDirector] Processing reward node")
    
    # Let orchestrator handle timing
    RewardOrchestrator.process_rewards(node)
    
    # Wait for rewards to finish displaying
    await RewardOrchestrator.reward_processing_complete
    
    print("[ExperienceDirector] Rewards complete, advancing")
    advance_to_next_node()
```

### Example 2: Level Complete Integration

```gdscript
# GameUI.gd or GameManager.gd
func _on_level_complete(final_score: int, stars: int):
    # Calculate rewards
    var coins = final_score / 100
    var gems = stars
    
    # Grant through orchestrator
    RewardOrchestrator.grant_level_rewards(coins, gems)
    
    # Show transition screen
    show_level_transition()
```

### Example 3: Custom Bonus Rewards

```gdscript
# DailyRewardSystem.gd
func claim_daily_reward():
    var reward = {
        "coins": 100,
        "gems": 10,
        "reason": "Day 7 Bonus"
    }
    
    RewardOrchestrator.grant_bonus_rewards(reward)
    await RewardOrchestrator.reward_processing_complete
    
    print("Bonus claimed!")
```

---

## Implementation Details

### Reward Queue

RewardOrchestrator maintains an internal queue of pending rewards:

```gdscript
var pending_rewards: Array = []
var is_processing: bool = false
```

**Processing Flow:**
1. Rewards added to queue
2. `is_processing` flag set
3. Rewards granted one by one with delays
4. Notifications shown for each
5. Signal emitted when complete

### Timing Constants

```gdscript
const REWARD_DELAY = 0.3  # Delay between multiple rewards
const NOTIFICATION_DURATION = 2.0  # How long notification shows
```

**Tunable:** Adjust these in RewardOrchestrator.gd for different feel

---

## Integration with Other Systems

### ExperienceDirector
- Calls `process_rewards()` for reward nodes
- Waits for `reward_processing_complete` signal
- Ensures sequential flow

### RewardManager
- RewardOrchestrator calls RewardManager methods
- RewardManager updates player data
- RewardManager shows notifications

### LevelTransition
- Displays rewards during transition
- Provides visual context for rewards
- Shows cumulative rewards (level + bonus + flow)

### RewardNotification
- Shows individual reward notifications
- "+100 Coins", "+5 Gems", etc.
- Animated appearance and disappearance

---

## Configuration

### Reward Types Supported

```gdscript
# Currencies
"coins": int          # Coins to grant
"gems": int           # Gems to grant

# Items
"boosters": {         # Booster items
    "hammer": int,
    "swap": int,
    // ... etc
}
"lives": int          # Lives to grant

# Future (not yet implemented)
"xp": int            # Experience points
"collectibles": []   # Unlock collectibles
"unlocks": []        # Feature unlocks
```

---

## Debugging

### Enable Debug Logging

```gdscript
# In RewardOrchestrator.gd
var DEBUG_MODE = true  # Set to true for verbose logging
```

**Output:**
```
[RewardOrchestrator] Processing rewards: {"coins": 100, "gems": 5}
[RewardOrchestrator] Granting coins: 100
[RewardOrchestrator] Granting gems: 5
[RewardOrchestrator] ✓ All rewards processed
[RewardOrchestrator] Emitting reward_processing_complete
```

### Common Issues

**Issue:** Rewards not appearing
- Check: Is RewardOrchestrator autoload registered?
- Check: Is `process_rewards()` being called?
- Check: Are you awaiting the signal?

**Issue:** Rewards appearing at wrong time
- Solution: Always call through RewardOrchestrator, not RewardManager directly
- Timing is managed centrally

**Issue:** Duplicate rewards
- Check: Are you calling `process_rewards()` multiple times?
- Each call processes the rewards

---

## Best Practices

### ✅ DO:
- Always use RewardOrchestrator for flow-based rewards
- Await `reward_processing_complete` signal
- Let orchestrator handle timing
- Use for all ExperienceDirector rewards

### ❌ DON'T:
- Call RewardManager directly for flow rewards
- Skip waiting for signal in critical flow
- Mix orchestrator and direct calls
- Process same rewards twice

---

## Future Enhancements

### Planned Features:
1. **Reward Batching** - Combine multiple small rewards
2. **Multipliers** - Apply global multipliers to rewards
3. **Reward Caps** - Daily/weekly limits
4. **Analytics** - Track reward distribution
5. **A/B Testing** - Test different reward amounts
6. **Reward Animations** - Enhanced visual feedback

---

## Files

**Core:**
- `scripts/RewardOrchestrator.gd` - Main implementation
- `project.godot` - Autoload registration

**Related:**
- `scripts/RewardManager.gd` - Actual reward granting
- `scripts/RewardNotification.gd` - Visual notifications
- `scripts/ExperienceDirector.gd` - Flow integration
- `scripts/LevelTransition.gd` - Transition screen

---

## Status

✅ **Implemented and Working:**
- Basic reward processing
- Signal-based coordination
- ExperienceDirector integration
- Coins and gems support

🔮 **Future Additions:**
- Booster rewards through orchestrator
- Collectible unlocks
- XP system integration
- Reward multipliers

---

**Last Updated:** February 10, 2026  
**Phase:** 12 Complete  
**Status:** Production Ready
