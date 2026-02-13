# Quick Reference - New Pipeline Architecture

**Purpose:** Quick lookup for understanding the new architecture

---

## Files Created

### Core Pipeline (`scripts/runtime_pipeline/`)

| File | Purpose | Lines |
|------|---------|-------|
| `PipelineContext.gd` | Execution state container | ~60 |
| `PipelineStep.gd` | Base class for all steps | ~25 |
| `ExperiencePipeline.gd` | Step executor / coordinator | ~121 |
| `ContextBuilder.gd` | Builds execution context | ~60 |
| `NodeTypeStepFactory.gd` | Converts nodes to steps | ~70 |

### Pipeline Steps (`scripts/runtime_pipeline/steps/`)

| File | Purpose | Lines |
|------|---------|-------|
| `LoadLevelStep.gd` | Loads levels, waits for completion | ~65 |
| `ShowNarrativeStep.gd` | Shows narrative stages | ~70 |
| `GrantRewardsStep.gd` | Grants rewards directly | ~85 |

### Orchestrator (`scripts/`)

| File | Purpose | Lines |
|------|---------|-------|
| `FlowCoordinator.gd` | Thin orchestrator (replaces god class) | ~220 |

### Modified

| File | Change | Reason |
|------|--------|--------|
| `ExperienceDirector.gd` | Now delegates to FlowCoordinator | Backward compatibility |

---

## How It Works

```
1. GameUI calls ExperienceDirector.load_flow("main_story")
   ↓
2. ExperienceDirector delegates to FlowCoordinator
   ↓
3. FlowCoordinator loads flow JSON via ExperienceFlowParser
   ↓
4. GameUI calls ExperienceDirector.start_flow()
   ↓
5. FlowCoordinator builds PipelineContext (one-time scene tree lookup)
   ↓
6. FlowCoordinator creates pipeline steps via NodeTypeStepFactory
   ↓
7. FlowCoordinator starts ExperiencePipeline with context + steps
   ↓
8. ExperiencePipeline executes steps sequentially
   ↓
9. Each step:
   - Executes with shared PipelineContext
   - Emits step_completed signal when done
   - Pipeline moves to next step
   ↓
10. Pipeline completes → FlowCoordinator emits flow_completed
    ↓
11. ExperienceDirector forwards signal to GameUI
```

---

## Key Classes

### PipelineContext

```gdscript
# Shared execution state - eliminates scene tree searches
var flow_id: String
var current_node: Dictionary
var flow_nodes: Array
var game_board: Node        # Cached reference
var game_ui: Node          # Cached reference
var viewport: Window       # Cached reference
var overlay_layer: CanvasLayer  # Cached reference
```

### PipelineStep (Base Class)

```gdscript
signal step_completed(success: bool)

func execute(context: PipelineContext) -> bool:
    # Override in subclass
    pass

func cleanup():
    # Override for cleanup
    pass
```

### ExperiencePipeline

```gdscript
func start(ctx: PipelineContext, steps: Array) -> void:
    # Executes steps sequentially
    # Emits lifecycle signals
    # Handles step completion
```

### FlowCoordinator

```gdscript
func load_flow(flow_id: String) -> bool:
    # Loads flow JSON
    
func start_flow() -> void:
    # Builds context and steps
    # Starts pipeline execution
    
func start_flow_at_level(level_num: int) -> void:
    # Starts from specific level
```

---

## Adding a New Step Type

### 1. Create Step Class

```gdscript
# scripts/runtime_pipeline/steps/MyNewStep.gd
extends PipelineStep
class_name MyNewStep

func _init():
    super._init("my_new_step")

func execute(context: PipelineContext) -> bool:
    print("[MyNewStep] Executing...")
    
    # Do your work here
    # Use context.game_board, context.game_ui, etc.
    
    # If async work:
    context.waiting_for_completion = true
    # Connect to signals, then emit step_completed later
    
    # If synchronous:
    return true  # or false for failure
```

### 2. Add to Factory

```gdscript
# scripts/runtime_pipeline/NodeTypeStepFactory.gd

static func create_step_from_node(node: Dictionary) -> PipelineStep:
    var node_type = node.get("type", "")
    
    match node_type:
        # ...existing types...
        "my_new_type":
            return _create_my_new_step(node)

static func _create_my_new_step(node: Dictionary) -> PipelineStep:
    var param = node.get("param", "default")
    return MyNewStep.new(param)
```

### 3. Done!

No need to modify ExperienceDirector or FlowCoordinator.

---

## Debugging

### Enable Verbose Logs

Logs are already verbose. Watch for:

```
[ExperienceDirector] Using NEW PIPELINE architecture
[FlowCoordinator] Loading flow: main_story
[ExperiencePipeline] Starting pipeline: main_story with 1 steps
[ExperiencePipeline] Executing step 1/1: load_level
[LoadLevelStep] Loading level 1 (level_01)
[LoadLevelStep] Level completed: level_01
[ExperiencePipeline] Step completed: load_level (success: true)
[ExperiencePipeline] Pipeline completed: main_story
```

### Common Issues

**Issue:** Steps not executing  
**Fix:** Check NodeTypeStepFactory has mapping for node type

**Issue:** Scene references null  
**Fix:** Check ContextBuilder is finding game_board/game_ui

**Issue:** Step never completes  
**Fix:** Check step emits `step_completed.emit(true/false)`

---

## Performance

### Before (Scene Tree Searches)

```gdscript
# Every node execution:
var game_ui = get_node_or_null("/root/MainGame/GameUI")  # Search!
var board = get_node_or_null("/root/MainGame/GameUI/GameBoard")  # Search!
var narrative = get_node_or_null("/root/NarrativeStageManager")  # Search!
# ...repeated 10+ times per flow
```

### After (Context Caching)

```gdscript
# ONCE per flow:
var context = ContextBuilder.build_from_scene_tree()
# context.game_ui = <cached>
# context.game_board = <cached>
# context.viewport = <cached>

# Every step:
context.game_ui  # No search! Instant access
context.game_board  # No search! Instant access
```

**Result:** ~90% reduction in scene tree lookups

---

## Testing Checklist

- [ ] Game launches with new architecture
- [ ] Levels load
- [ ] Levels complete
- [ ] Narrative stages show
- [ ] Rewards granted
- [ ] State saves
- [ ] No console errors
- [ ] Performance acceptable

---

## Future Phases

1. **Multi-Step Flows** - Execute narrative → level → reward sequences
2. **Effect Integration** - Move EffectResolver to use PipelineContext
3. **Remove RewardOrchestrator** - Logic moved to GrantRewardsStep
4. **Additional Steps** - Cutscene, Ad, Premium Gate, etc.
5. **Cleanup** - Remove legacy code paths after thorough testing

---

## Help

- Full details: `docs/ARCHITECTURE_REFACTOR_SUMMARY.md`
- Testing guide: `docs/ARCHITECTURE_REFACTOR_TESTING.md`
- Progress tracker: `docs/REFACTOR_PROGRESS.md`
