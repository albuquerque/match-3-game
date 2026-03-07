# Match-3 Game — Architecture Refactor History

> Consolidated record of all refactor rounds. Supersedes the separate
> `ARCHITECTURE_REFACTOR_CHANGELOG.md`, `docs/refactor-round2.md`, and `docs/refactor-round3.md`.

---

## Table of Contents

1. [Round 1 — Pipeline Architecture & ExperienceDirector (Feb 2026)](#round-1)
2. [Round 1 Addendum — Service Stubs & Phase E/F (Mar 2026)](#round-1-addendum)
3. [Round 2 — GameBoard Delegation (Mar 2026)](#round-2)
4. [Round 3 — GameBoard God-Orchestrator Elimination (Mar 2026)](#round-3)
5. [Round 4 — Bug Fixes & Regressions (Mar 2026)](#round-4)
6. [Metrics Summary](#metrics-summary)

---

<a name="round-1"></a>
## Round 1 — Pipeline Architecture & ExperienceDirector
**Date:** February 11, 2026
**Status:** ✅ Complete

### Goal
Replace the 951-line `ExperienceDirector` god class with a clean pipeline architecture that
separates responsibilities and eliminates per-node scene-tree searches.

### What Changed

#### New Components
| Component | Purpose |
|-----------|---------|
| `PipelineContext` | Shared execution state — eliminates scene tree searches |
| `PipelineStep` | Base class for all pipeline steps |
| `ExperiencePipeline` | Sequential step executor |
| `ContextBuilder` | Builds and caches execution context once per flow |
| `NodeTypeStepFactory` | Converts flow JSON nodes into pipeline step objects |
| `FlowCoordinator` | Thin orchestrator (~220 lines) that replaced the god class |
| `LoadLevelStep` | Level loading and completion event handling |
| `ShowNarrativeStep` | Narrative stage display with auto-advance and skip |
| `GrantRewardsStep` | Grants rewards directly without a popup |

#### Modified Components
- **`ExperienceDirector.gd`** — Demoted to a compatibility layer that delegates to
  `FlowCoordinator` while preserving all existing API surface.

### Benefits
- **−75%** orchestrator size (951 → 220 lines)
- **−90%** scene tree searches (per-node → once per flow, cached in `PipelineContext`)
- **+30–50%** estimated flow execution speed
- All saves, integrations, and existing call sites remain unchanged

### Backward Compatibility
Full. No migration needed. Legacy toggle removed — the pipeline is the canonical implementation.

### Files Created
```
scripts/
  FlowCoordinator.gd
  runtime_pipeline/
    PipelineContext.gd
    PipelineStep.gd
    ExperiencePipeline.gd
    ContextBuilder.gd
    NodeTypeStepFactory.gd
    steps/
      LoadLevelStep.gd
      ShowNarrativeStep.gd
      GrantRewardsStep.gd
```

---

<a name="round-1-addendum"></a>
## Round 1 Addendum — Service Stubs & Phase E/F
**Date:** February 24 – March 4, 2026
**Status:** ✅ Complete (E4 blocked — see note)

### 2026-02-24 — MatchFinder & Scoring Service Stubs
- Added `scripts/services/MatchFinder.gd` — pure, stateless match-finding utility
- Added `scripts/services/Scoring.gd` — simple scoring helper
- Added unit tests: `tests/test_matchfinder.gd`, `tests/test_scoring.gd`

### 2026-03-04 — Phase E: HUDComponent + BoosterPanelComponent Self-Wiring

#### E1 — HUDComponent self-wiring
- `HUDComponent._ready()` now subscribes directly to `GameManager` signals
  (`score_changed`, `moves_changed`, `level_changed`, `collectibles_changed`,
  `unmovables_changed`, `level_loaded`) and `RewardManager.coins_changed`
- Added `_refresh_from_gm()` for full HUD sync on level load
- **Removed from GameUI (~140 lines):** all HUD signal handler functions

#### E2 — BoosterPanelComponent self-wiring
- `BoosterPanelComponent._ready()` connects to `RewardManager.booster_changed` and
  `GameManager.level_loaded`; refreshes boosters, counts, and icons automatically
- **Removed from GameUI (~250 lines):** `update_booster_ui`, `load_booster_icons`, 9 flat
  press handlers, `_animate_selected_booster`

#### E3 — GameUI housekeeping
- Removed dead debug methods, redundant `@onready` var declarations
- **`GameUI.gd` reduced from 784 → ~240 lines (−544 lines)**

> **E4 BLOCKED:** `HUDComponent.tscn` is not instantiated as a child of `GameUI` in
> `MainGame.tscn`. The `if hud != null: return` guard means HUDComponent self-wiring is
> never triggered — `GameUI`'s fallback handlers are the active HUD path. Pre-requisite:
> add `HUDComponent.tscn` to `MainGame.tscn`, verify HUD, then remove the duplicates.

### 2026-03-04 — Phase F: Unit Tests

| File | Cases | Description |
|------|-------|-------------|
| `tests/test_booster_selector.gd` | 6 | returns array, count range, deterministic, includes common, no duplicates, custom tiers |
| `tests/test_level_loader.gd` | 5 | field assignment, grid call verification, fallback defaults, hard texture attachment, spreader texture |
| `tests/test_game_flow_controller.gd` | 11 | pending flags, score-based completion, primary goal blocks score, collectible/unmovable/spreader completion, level failed, star thresholds, skip bonus |

All tests use lightweight mock stubs — no autoloads, no scene tree required.

---

<a name="round-2"></a>
## Round 2 — GameBoard Delegation Completion
**Date:** March 5, 2026
**Status:** ✅ Complete (E4 still blocked)

### Goal
Complete the six pending tasks (A2, A7, A8, E4, F4, F5) from the original `docs/refactor.md`
plan to bring `GameBoard.gd` closer to its target size by delegating the remaining inline
data-layer responsibilities.

### Baseline at Start of Round 2

| File | Lines | Target |
|------|-------|--------|
| `GameBoard.gd` | 2439 | ~600 |
| `GameManager.gd` | 1008 | ~400 |
| `GameUI.gd` | 447 | ~250 |

### Tasks Completed

#### A8 — Wire `create_visual_grid` to `BoardVisuals`
- Deleted the ~125-line inline duplicate of `BoardVisuals.create_visual_grid()` from GameBoard
- Replaced with a single delegation call: `await BoardVisuals.create_visual_grid(self, tiles)`
- Confirmed signal wiring (`tile_clicked`, `tile_swiped`) uses `gameboard` as connect target
- Verified on Level 1 (square), Level 2 (plus-shape), Level 4 (unmovables), Level 31 (spreaders)

#### A7 — Slim `_damage_adjacent_unmovables`
- Removed the fallback `elif` branch (lines ~2296–2305) that duplicated
  `GameManager.report_unmovable_destroyed()` logic
- `report_unmovable_destroyed()` is now the sole path for updating `unmovable_map` and the
  objective counter

#### A2 — Wire `GravityAnimator` for gravity + refill
- Ported the **barrier/segment-aware column loop** from `GameBoard.animate_gravity()` (111 lines)
  into `GravityAnimator.animate_gravity()` — correctly handles non-square boards and unmovable
  barriers
- Ported the **per-segment spawn logic** from `GameBoard.animate_refill()` (94 lines) into
  `GravityAnimator.animate_refill()` — tiles enter from the top of each open segment, not the
  top of the whole column
- Replaced both inline bodies in GameBoard with one-line delegation calls
- Verified Level 2 (inactive cells not filled), Level 4 (correct segment drop above/below barrier)

#### E4 — Remove duplicate HUD handlers from GameUI
⛔ **BLOCKED** — `HUDComponent.tscn` not in scene tree; GameUI handlers are the active HUD path.
Removing them without first wiring HUDComponent would break the HUD.

#### F4 — `tests/test_objective_manager.gd`
7 test cases: `report_unmovable_cleared`, `report_spreader_destroyed`, `report_collectible_collected`,
`is_complete()` false/true/no-goals, `get_status()` structure. 97 lines.

#### F5 — `tests/test_gravity_animator.gd`
3 coroutine-aware test cases: no-op when `apply_gravity` returns false, empty refill array,
chained call on empty board. 82 lines. Uses `async func _ready()`.

### Outcomes

| File | Before | After | Change |
|------|--------|-------|--------|
| `GameBoard.gd` | 2439 | ~2109 | −330 |
| `GravityAnimator.gd` | 143 | ~192 | +49 (ported logic) |
| `tests/test_objective_manager.gd` | 0 | 97 | new |
| `tests/test_gravity_animator.gd` | — | 82 | new |

---

<a name="round-3"></a>
## Round 3 — GameBoard God-Orchestrator Elimination
**Date:** March 5, 2026
**Status:** ✅ Complete

### Goal
Reduce `GameBoard.gd` from 2109 lines to its ~500-line target by extracting the remaining 75%
of its code into 4 new execution-layer components and 2 delegation completions.

### Why GameBoard Still Suffered from God-Orchestrator Syndrome

Rounds 1–2 extracted the **data-layer** responsibilities (gravity, matching, special tile
computation, spreading, scoring). But GameBoard still owned every **execution-layer**
responsibility: receiving input events, deciding which action to run, animating results,
managing board layout, and reacting to lifecycle signals — all inline.

### Responsibility Breakdown Before Round 3

| Category | Lines | % |
|----------|-------|---|
| Input (`_on_tile_clicked` 110L, `_on_tile_swiped` 48L, `_input` 12L) | 170 | 8% |
| Swap + special position detection | 146 | 7% |
| Booster activation (9 functions) | 233 | 11% |
| Special tile activation (3 functions) | 246 | 12% |
| Animation (destroy, shuffle, highlight, clear) | 226 | 10% |
| Layout/Setup (14 functions) | 270 | 13% |
| Collectible logic | 94 | 4% |
| VisualFX (8 functions; BoardEffects existed but was never wired) | 51 | 2% |
| Adjacent damage (unmovables + spreaders) | 138 | 6% |
| Dead init code / stubs | ~140 | 7% |
| Debug scaffold | 26 | 1% |
| Lifecycle handlers | 97 | 5% |
| Grid utilities (must stay) | 116 | 5% |
| Already-thin delegators | 86 | 4% |
| **TOTAL** | **2109** | **100%** |

**Movable: ~1600 lines (75%) · Must stay: ~509 lines (25%)**

### Steps Executed

| Step | Task | Risk | Lines Saved |
|------|------|------|------------|
| 1 | Delete dead code (stubs, aliases, debug scaffold) | 🟢 NONE | −140 |
| 2 | Delegate 8 VisualFX functions → `BoardEffects.gd` | 🟢 LOW | −51 |
| 3 | Extract `BoardSetup.gd` (layout/visibility/skip-hint) | 🟡 MEDIUM | −270 |
| 4 | Extract `BoardAnimator.gd` (destroy/highlight/shuffle) | 🟡 MEDIUM | −226 |
| 5 | Extract `BoardInputHandler.gd` (input + swap) | 🔴 HIGH | −316 |
| 6 | Extract `BoardActionExecutor.gd` (booster + special tile execution) | 🔴 HIGH | −479 |
| 7 | Extract `CollectibleService.gd` (collection detection + animation) | 🟡 MEDIUM | −94 |
| 8 | Slim adjacent damage → `SpreaderService` / `ObjectiveManager` | 🟡 LOW-MED | −50 |
| | **TOTAL** | | **−1626** |

#### Step 5 — BoardInputHandler architecture detail
`BoardInputHandler` is instantiated as a child `Node` of GameBoard (not static), holding a
`board` reference set in `_ready`. `_on_tile_clicked` and `_on_tile_swiped` are moved there.
GameBoard becomes a 3-line forwarder:
```gdscript
func _on_tile_clicked(tile):
    if BIH and is_instance_valid(BIH):
        await BIH.handle_tile_clicked(tile)
```

#### Step 6 — BoardActionExecutor architecture detail
Rather than copying 9 near-identical booster functions, `BoardActionExecutor` implements a
single generic `execute_action(gameboard, positions, options)` coroutine. Each booster calls it
with the right options dict, collapsing 233 booster lines → ~80 lines.

### New Components Created

| File | Lines | Responsibility |
|------|-------|---------------|
| `scripts/game/BoardSetup.gd` | ~250 | Layout calculation, background/overlay, visibility helpers, skip-hint |
| `scripts/game/BoardAnimator.gd` | ~235 | Destruction animation, shuffle, highlight |
| `scripts/game/BoardInputHandler.gd` | ~220 | Tile input (click/swipe), swap execution |
| `scripts/game/BoardActionExecutor.gd` | ~380 | Booster execution, special tile activation |
| `scripts/game/CollectibleService.gd` | ~95 | Collection detection, fly-to-HUD animation |

### Final Outcomes

| File | Before Round 3 | After Round 3 | Target |
|------|---------------|---------------|--------|
| `GameBoard.gd` | 2109 | **613** | ~600 ✅ |
| `BoardInputHandler.gd` | — | ~220 | new ✅ |
| `BoardActionExecutor.gd` | — | ~380 | new ✅ |
| `BoardAnimator.gd` | — | ~235 | new ✅ |
| `BoardSetup.gd` | — | existing | new ✅ |
| `CollectibleService.gd` | — | ~95 | new ✅ |
| `BoardEffects.gd` | 123 (partial) | ~170 | ~170 ✅ |
| `SpreaderService.gd` | 37 | ~147 | ~90 ✅ |

### What GameBoard.gd Looks Like After Round 3
```
extends Node2D / class_name GameBoard
  ~30 lines  signals + instance vars (tile_size, grid_offset, tiles, script handles)
  ~45 lines  _ready() — layout, script loading, signal wiring
  ~30 lines  grid_to_world_position, world_to_grid_position
  ~20 lines  instantiate_tile_visual, spawn_collectible_visual, create_visual_grid (delegator)
  ~15 lines  animate_gravity, animate_refill, process_cascade (thin delegators)
  ~30 lines  _on_level_loaded, _on_game_over, _on_level_complete (thin wrappers)
  ~25 lines  _on_tile_clicked, _on_tile_swiped (3-line forwarders to BoardInputHandler)
  ~30 lines  9× activate_*_booster (1-line callers into BoardActionExecutor)
  ~10 lines  activate_special_tile, activate_special_tile_chain (delegators)
  ~20 lines  draw_board_borders, _safe_draw_board_borders_deferred
  ~20 lines  hide/show_board_group, set_board_group_visibility
  ~20 lines  update_tile_visual, highlight_matches (thin wrappers)
  ~30 lines  deferred_gravity_then_refill, _task_deferred (cascade helpers)
  ~30 lines  _damage_adjacent_* (thin delegators to SpreaderService/ObjectiveManager)
  ≈ 355–613 lines total
```

---

<a name="round-4"></a>
## Round 4 — Bug Fixes & Regressions After GameManager Refactor
**Date:** March 6, 2026
**Status:** ✅ Complete

### Goal
Fix a set of critical regressions introduced during the GameManager refactor that left the game
unplayable, and correct two gameplay correctness bugs discovered during verification.

### Bugs Fixed

#### 1 — Tile swipes and clicks silently ignored (game unplayable)
`BoardVisuals.clear_tiles()` identified nodes to remove with `has_method("setup")`. The
`BoardInputHandler` node — a direct child of GameBoard — also has a `setup()` method, so it
was `queue_free()`'d on every level load. After the first tile clear, `BIH` held a freed node
reference, causing all input delegation to silently exit via the `is_instance_valid(BIH)` guard.

**Fix:** Changed tile identification from `has_method("setup")` (too broad) to
`"grid_position" in child` — only actual `Tile` nodes carry that property.

#### 2 — `_deferred_debug_auto_swap` method-not-found error on every level load
`BoardVisuals.gd` still called `gameboard.call_deferred("_deferred_debug_auto_swap")` — a debug
scaffold deleted from `GameBoard` in Round 3.

**Fix:** Removed the dead `call_deferred` call.

#### 3 — Duplicate `_on_tile_clicked` / `_on_tile_swiped` parse error
A fix attempt added these methods again to `GameBoard`, not knowing they already existed as
Step 5 delegators. Godot 4 parse error prevented the entire script from loading.

**Fix:** Removed the duplicates.

#### 4 — Double `_on_level_loaded` calls corrupting tile setup
`GameBoard._ready()` connected both `GameManager.level_loaded` and `EventBus.level_loaded` to
`_on_level_loaded()`. Both fire in the same frame, so `BoardSetup.on_level_loaded_setup()` ran
twice — hiding the board group mid-creation and queuing `create_visual_grid` twice.

**Fix:** Removed the redundant `EventBus.level_loaded` connection (GameManager's signal is
canonical). Added a `creating_visual_grid` re-entrancy guard to `_on_level_loaded` as a
secondary safety net.

#### 5 — StartPage reopened on top of the game after pressing Start
`PageManager.close("StartPage")` left an empty stack. The fallback *"no pages → reopen StartPage"*
logic fired before the pipeline started because `GameManager.initialized` was still `false`
(async) and `ExperienceDirector.is_flow_active()` returned `false` (pipeline not yet running).
Users had to press Start twice.

**Fix:** When `StartPage` itself is closed and the stack becomes empty, suppress the auto-reopen
entirely — the flow is starting and will manage navigation.
Also improved `ExperienceDirector.is_flow_active()` to check `pipeline.is_running` directly.

#### 6 — Special tiles (horizontal/vertical clear, bomb) matched as normal tiles
`GameManager.find_matches()` passed `exclude = [COLLECTIBLE, SPREADER]` to `MatchFinder`.
The three special tile type constants (`HORIZTONAL_ARROW` 7, `VERTICAL_ARROW` 8, `FOUR_WAY_ARROW`
9) were absent. Three matching special tiles in a row were consumed as a regular 3-match.

**Fix:**
```gdscript
var exclude = [HORIZTONAL_ARROW, VERTICAL_ARROW, FOUR_WAY_ARROW, COLLECTIBLE, SPREADER]
```

### Files Changed in Round 4

| File | Change |
|------|--------|
| `scripts/game/BoardVisuals.gd` | `clear_tiles`: `has_method("setup")` → `"grid_position" in child`; remove dead `_deferred_debug_auto_swap` call |
| `scripts/GameBoard.gd` | Remove duplicate tile handler methods; remove redundant EventBus connection; add `_on_level_loaded` re-entrancy guard |
| `scripts/game/BoardInputHandler.gd` | Diagnostic print added to `setup()` |
| `scripts/ui/PageManager.gd` | Suppress StartPage auto-reopen when StartPage itself was just closed |
| `scripts/ExperienceDirector.gd` | `is_flow_active()` checks `pipeline.is_running` directly |
| `scripts/GameManager.gd` | Add special tile types to `find_matches` exclude list |

---

<a name="metrics-summary"></a>
## Metrics Summary

### GameBoard.gd Size Over Time

| After | Lines | Change |
|-------|-------|--------|
| Pre-refactor | ~2500 | baseline |
| Round 1 | 2439 | −61 |
| Round 2 | ~2109 | −330 |
| Round 3 | **613** | −1496 |
| Round 4 | **634** | +21 (guard + diagnostic prints) |
| **Target** | **~600** | ✅ |

### New Components Created Across All Rounds

| Component | Round | Lines | Responsibility |
|-----------|-------|-------|---------------|
| `FlowCoordinator.gd` | 1 | ~220 | Flow orchestration |
| `PipelineContext.gd` | 1 | ~80 | Execution state |
| `ExperiencePipeline.gd` | 1 | ~140 | Step executor |
| `LoadLevelStep.gd` | 1 | ~115 | Level loading |
| `ShowNarrativeStep.gd` | 1 | ~634 | Narrative display |
| `GrantRewardsStep.gd` | 1 | ~60 | Reward granting |
| `MatchFinder.gd` | 1+ | ~134 | Pure match detection |
| `Scoring.gd` | 1+ | ~30 | Scoring helper |
| `GravityAnimator.gd` | 2 | ~205 | Gravity + refill animation |
| `BoardSetup.gd` | 3 | ~271 | Layout, visibility, skip-hint |
| `BoardAnimator.gd` | 3 | ~235 | Destroy/highlight animation |
| `BoardInputHandler.gd` | 3 | ~217 | Input handling, swap |
| `BoardActionExecutor.gd` | 3 | ~380 | Booster + special tile execution |
| `CollectibleService.gd` | 3 | ~95 | Collection detection |

### Pending Work

| Item | Status | Blocker |
|------|--------|---------|
| E4 — Remove duplicate HUD handlers from `GameUI` | ✅ Complete | `HUDComponent` added to `MainGame.tscn`; HUD redesigned with MOVES/SCORE/GOAL layout; GameUI −134 lines |
| `GameManager.gd` reduction to ~400 lines | 🔵 FUTURE | Separate refactor branch needed |
| `GameUI.gd` further reduction to ~250 lines | 🔵 FUTURE | On track: now 313 lines |
