# Testing the Refactored Architecture

**Date:** February 11, 2026
**Purpose:** Test the new pipeline-based flow execution

---

## Test Setup

The refactor introduces a new pipeline architecture while maintaining backward compatibility. You can switch between old and new implementations using the `USE_NEW_PIPELINE` flag in ExperienceDirector.

### Current State

✅ **NEW Pipeline** is active by default (`USE_NEW_PIPELINE = true`)
🔄 **LEGACY Implementation** available as fallback (`USE_NEW_PIPELINE = false`)

---

## Quick Test

### 1. Launch the Game

The game will automatically use the new pipeline architecture.

### 2. Watch for Log Messages

You should see:
```
[ExperienceDirector] *** STARTING INITIALIZATION ***
[ExperienceDirector] Using NEW PIPELINE architecture
[ExperienceDirector] FlowCoordinator created
[ExperienceDirector] *** READY AND ACTIVE ***
```

### 3. Press "Start" or Select a Level

**Expected logs:**
```
[ExperienceDirector] Delegating load_flow to FlowCoordinator: main_story
[FlowCoordinator] Loading flow: main_story
[FlowCoordinator] Flow loaded: main_story
[ExperienceDirector] Delegating start_flow to FlowCoordinator
[FlowCoordinator] Starting flow: main_story
[ExperiencePipeline] Starting pipeline: main_story with 1 steps
[ExperiencePipeline] Executing step 1/1: load_level
[LoadLevelStep] Loading level 1 (level_01)
```

### 4. Complete a Level

**Expected logs:**
```
[LoadLevelStep] Level completed: level_01
[ExperiencePipeline] Step completed: load_level (success: true)
[ExperiencePipeline] Pipeline completed: main_story
[FlowCoordinator] Flow completed: main_story
```

---

## Troubleshooting

### If Game Doesn't Start

1. Check console for errors
2. Switch to legacy mode by setting `USE_NEW_PIPELINE = false` in ExperienceDirector.gd
3. Report errors in console output

### If Levels Don't Load

1. Check that FlowCoordinator is created successfully
2. Verify pipeline steps are being created
3. Check EventBus connections in LoadLevelStep

### Fallback to Legacy

If the new pipeline has issues, you can immediately fallback:

1. Open `scripts/ExperienceDirector.gd`
2. Change line ~30: `var USE_NEW_PIPELINE: bool = false`
3. Save and restart game

This will use the original implementation.

---

## What's Different

### New Architecture

- **FlowCoordinator** - Thin orchestrator (replaces god orchestrator)
- **ExperiencePipeline** - Executes steps in sequence
- **Pipeline Steps** - One responsibility per step
- **PipelineContext** - Shared execution state (no scene tree searches)

### Old Architecture (Legacy)

- **ExperienceDirector** - Monolithic orchestrator
- **Node processors** - `_process_*_node()` methods
- **Direct scene tree access** - `get_node_or_null()` everywhere
- **RewardOrchestrator** - Extra orchestration layer

---

## Performance Notes

The new architecture should be:
- ✅ **Faster** - No repeated scene tree searches
- ✅ **More reliable** - Clear execution flow
- ✅ **Easier to debug** - Explicit step progression
- ✅ **Extensible** - Add new steps without touching orchestrator

---

## Next Steps

Once basic functionality is verified:

1. Implement multi-step flows (narrative → level → reward sequences)
2. Add more step types (cutscene, unlock, ad_reward, etc.)
3. Migrate EffectResolver to use PipelineContext
4. Remove RewardOrchestrator (logic moved to GrantRewardsStep)
5. Remove legacy code paths from ExperienceDirector

---

## Questions to Answer

- [ ] Does the game launch successfully?
- [ ] Do levels load correctly?
- [ ] Does level completion work?
- [ ] Are there any console errors?
- [ ] Is performance acceptable?

---

## Rollback Plan

If critical issues are found:

1. Set `USE_NEW_PIPELINE = false` in ExperienceDirector.gd
2. Game immediately uses legacy implementation
3. No code changes needed
4. File a bug report with console output
