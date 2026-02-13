# Testing the Refactored Architecture

**Date:** February 11, 2026
**Purpose:** Test the new pipeline-based flow execution

---

## Test Setup

The refactor introduces a new pipeline architecture. The new pipeline is the default and legacy mode has been removed from the codebase.

✅ NEW Pipeline is active by default and should be used for all testing.

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
2. Report errors in console output

### If Levels Don't Load

1. Check that FlowCoordinator is created successfully
2. Verify pipeline steps are being created
3. Check EventBus connections in LoadLevelStep

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

If critical issues are found, revert the refactor using your VCS to the pre-refactor commit/branch that contains the legacy ExperienceDirector implementation (for example: `git checkout <pre-refactor-commit>`), then rebuild/run the project.

Example (replace `<pre-refactor-commit>` with the commit SHA or branch name):

```bash
# create a branch from the pre-refactor commit and switch to it
# (using the commit SHA)
git checkout -b pre-refactor 54686f75e885c788dae8cba3637ac5d00ba0386c

# Alternatively, use the created tag (recommended):
# create a branch from the tag and switch to it
git checkout -b pre-refactor pre-refactor-2026-02-13

# or, if a branch already exists:
git checkout pre-refactor
```
