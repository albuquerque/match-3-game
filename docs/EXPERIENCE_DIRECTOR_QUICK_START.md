# Experience Director - Quick Start Guide

**Status:** Phase 12 Complete - Production Ready ✅  
**Last Updated:** 2026-02-10

---

## What is the Experience Director?

The Experience Director is a high-level orchestrator that manages the complete player journey through:
- Story progression
- Reward delivery
- Narrative triggers
- Level transitions
- Monetization hooks

It sits above GameManager and drives the overall player experience using JSON-configured flows.

---

## Quick Setup

### 1. Already Done ✅

The Experience Director is already set up as an autoload and **integrated with the game**!

**Components:**
- `ExperienceDirector` (autoload) - Main orchestrator
- `ExperienceState` - Persistent player journey state
- `ExperienceFlowParser` - JSON flow parser
- `RewardOrchestrator` - Reward timing and distribution ✅
- `CollectionManager` - Collectible cards system ✅

**Integration:**
- ✅ Loads main_story flow with 62 levels (Genesis → Exodus)
- ✅ Tracks progress through biblical narrative
- ✅ Manages reward distribution timing
- ✅ Saves state automatically
- ✅ Production ready!

---

## Testing the Experience Director

### The Easy Way: Just Play the Game! 🎮

1. **Launch the game** (from Godot or builds)
2. **Press "Start"** on the start screen
3. **Play normally** - complete levels
4. **Watch the console** for Experience Director messages

That's it! The Experience Director is working in the background tracking your journey.

### What You'll See in Console:

```
[GameUI] Loading Experience Director main_story flow...
[ExperienceDirector] Flow loaded: main_story
[GameUI] Starting Experience Director flow...
[ExperienceDirector] Processing node [1]: level: level_01
...
[EventBus] level_complete: level_01
[ExperienceDirector] Level complete: level_01
[ExperienceState] Unlocked reward: first_level_complete
[ExperienceDirector] Processing node [3]: level: level_02
```

For detailed testing instructions, see: `docs/EXPERIENCE_DIRECTOR_GAME_INTEGRATION.md`

---

## How to Use

### Loading a Flow

```gdscript
# In your game initialization code
ExperienceDirector.load_flow("main_story")
ExperienceDirector.start_flow()
```

### Accessing Current State

```gdscript
# Get current flow ID
var flow_id = ExperienceDirector.state.current_flow_id

# Get current position in flow
var index = ExperienceDirector.state.current_level_index

# Check if a reward was unlocked
if ExperienceDirector.state.is_reward_unlocked("first_level_reward"):
    print("Player has this reward!")
```

### Manually Advancing (for testing)

```gdscript
# Move to next node in flow
ExperienceDirector.advance_to_next_node()

# Jump to specific index
ExperienceDirector.state.set_level_index(5)
```

---

## Creating a Flow

### Basic Flow Structure

Create a JSON file in `data/experience_flows/`:

```json
{
  "experience_id": "my_custom_flow",
  "version": "1.0.0",
  "name": "My Custom Flow",
  "description": "A custom experience flow",
  "flow": [
    {
      "type": "level",
      "id": "level_001"
    },
    {
      "type": "reward",
      "id": "level_1_complete",
      "rewards": [
        { "type": "coins", "amount": 100 }
      ]
    },
    {
      "type": "narrative_stage",
      "id": "story_intro"
    },
    {
      "type": "level",
      "id": "level_002"
    }
  ]
}
```

### Supported Node Types

**Implemented (Phase 12):**
1. ✅ **level** - Loads a match-3 level
2. ✅ **narrative_stage** - Shows a narrative stage
3. ✅ **reward** - Grants rewards to player (via RewardOrchestrator)
4. ✅ **cutscene** - Plays a cutscene (simple executor present)
5. ✅ **conditional** - Branching logic based on ExperienceState

**Planned for Future:**
6. **unlock** - Unlocks features
7. **ad_reward** - Shows ad with reward
8. **premium_gate** - Checks premium status
9. **dlc_flow** - Loads DLC content

---

### Example: Cutscene Node

```json
{
  "type": "cutscene",
  "id": "intro_cutscene",
  "params": {
    "duration": 4.0,
    "target_path": "MainGame/IntroScene",
    "animation": "intro_anim"
  }
}
```

The `CutsceneExecutor` will attempt to play the named animation on the target node's `AnimationPlayer` or fall back to waiting the specified `duration`.

### Example: Conditional Node

```json
{
  "type": "conditional",
  "condition": { "reward_unlocked": "test_reward_1" },
  "then": {
    "type": "cutscene",
    "id": "reward_cutscene",
    "params": { "duration": 2.0 }
  },
  "else": {
    "type": "narrative_stage",
    "id": "skip_reward_story"
  }
}
```

The `conditional` node evaluates the `condition` and inserts either the `then` or `else` branch nodes into the flow immediately after the conditional node, which are then processed next.

---

## Testing

### Run the Test Suite

```bash
# Open the test scene in Godot
scenes/ExperienceDirectorTest.tscn

# Or run from command line
godot --headless -s scripts/tests/test_experience_director.gd
```

### Manual Testing

```gdscript
# In a test scene
func _ready():
    # Load and start a flow
    ExperienceDirector.load_flow("test_flow_simple")
    ExperienceDirector.start_flow()
    
    # Print current state
    ExperienceDirector.print_current_state()
```

---

## Current Status - Phase 12 Complete

### ✅ Implemented and Working

- **ExperienceDirector** - Complete flow orchestration
- **ExperienceState** - Persistent state management with save/load
- **ExperienceFlowParser** - JSON flow parsing and validation
- **RewardOrchestrator** - Centralized reward timing and distribution
- **CollectionManager** - Collectible cards system
- **Main Story Flow** - 62 levels from Genesis through Exodus
- **Narrative Stages** - 62 biblical narrative stages
- **Level Integration** - Seamless level-to-level progression
- **Auto-advance** - Automatic progression through flow nodes
- **Save Migration** - Existing saves automatically migrate to new system

### 🔮 Planned for Future Phases

- **Cutscene System** - Video/animation playback
- **Conditional Logic** - Branching based on player state/choices
- **DLC Integration** - Dynamic content loading from server
- **Advanced Monetization** - Premium gates, ad rewards
- **Multi-path Stories** - Player choice affecting narrative

---

## Integration Points

### With GameManager

```gdscript
# ExperienceDirector triggers levels
GameManager.level = extracted_level_number

# GameManager signals completion
EventBus.level_complete.emit("level_001", {...})
# ExperienceDirector listens and auto-advances
```

### With NarrativeStageManager

```gdscript
# ExperienceDirector triggers narrative
NarrativeStageManager.load_stage_by_id("creation_intro")

# Narrative completion triggers advance
# (currently manual, will be automatic)
```

### With RewardOrchestrator & RewardManager

```gdscript
# ExperienceDirector uses RewardOrchestrator for reward timing
# When a reward node is processed:
ExperienceDirector.advance_to_next_node()
# → Triggers reward node
# → RewardOrchestrator handles timing
# → Rewards appear on transition screen
# → Then next level loads

# RewardOrchestrator calls RewardManager
RewardManager.add_coins(amount)
RewardManager.add_gems(amount)
# → Updates player balance
# → Shows notification
# → Saves progress
```

---

## State Persistence

### Automatic Saving

Experience state is automatically saved with RewardManager:

```gdscript
# When RewardManager.save_progress() is called
# It automatically includes experience_state data
```

### Save File Structure

In `user://player_progress.json`:

```json
{
  "coins": 500,
  "gems": 50,
  "experience_state": {
    "current_world": 1,
    "current_chapter": 1,
    "current_level_index": 3,
    "current_flow_id": "main_story",
    "unlocked_rewards": ["first_level_reward", "level_2_reward"],
    "seen_narrative_stages": ["creation_intro"],
    "completed_experience_nodes": ["level_001", "level_002"]
  }
}
```

---

## Debugging

### Print Current State

```gdscript
# Print complete director state
ExperienceDirector.print_current_state()

# Print just experience state
ExperienceDirector.state.print_state()

# Print flow summary
ExperienceDirector.parser.print_flow_summary(ExperienceDirector.current_flow)
```

### Common Issues

**Flow not loading:**
- Check file path: `data/experience_flows/your_flow.json`
- Check JSON syntax (use a validator)
- Check console for parser errors

**Auto-advance not working:**
- Ensure `ExperienceDirector.auto_advance = true`
- Check EventBus connections
- Verify level completion is firing events

**State not persisting:**
- Call `RewardManager.save_progress()` after changes
- Check save file at `user://player_progress.json`

---

## Next Steps for Developers

### Current State (Phase 12 Complete)

All core systems are implemented and working:
- ✅ Experience flow orchestration
- ✅ Reward timing and distribution
- ✅ Narrative stage integration
- ✅ Level progression
- ✅ State persistence

### Future Enhancements (Phase 13+)

1. **Cutscene System**
   - Video/animation playback
   - Skippable cutscenes
   - Integration with narrative stages

2. **Advanced Branching**
   - Conditional logic based on player choices
   - Multiple story paths
   - Dynamic difficulty adjustment

3. **Enhanced DLC Integration**
   - Server-side content loading
   - Dynamic story insertion
   - Live events

4. **Monetization Enhancements**
   - Premium story gates
   - Ad-rewarded content unlocks
   - Special offers integration

For detailed roadmap, see: `docs/PHASE_12_IMPLEMENTATION_PLAN.md`

---

## Resources

- **Complete Summary:** `docs/COMPLETE_SESSION_SUMMARY_FEB_10.md`
- **Schema Reference:** `docs/EXPERIENCE_FLOW_SCHEMA.md`
- **Narrative Effects:** `docs/NARRATIVE_EFFECTS_COMPLETE.md`
- **Narrative Stages:** `docs/NARRATIVE_STAGE_GUIDE.md`
- **Collections:** `docs/COLLECTION_SYSTEM_GUIDE.md`
- **Biblical Story:** `docs/BIBLICAL_STORY_PROGRESSION.md`

---

## Questions?

Refer to the complete documentation or check the roadmap for implementation status of specific features.
