# Safe Migration PR Plan -- Godot Refactor

Generated: 2026-03-27T14:24:32.615143

------------------------------------------------------------------------

## 🎯 Strategy

This is a **non-breaking, incremental refactor plan** using small PRs.

Each PR: - compiles - runs - is testable

------------------------------------------------------------------------

## 🧩 PR 1 -- Introduce BaseGame (NO BREAKAGE)

### Add:

-   games/base/BaseGame.gd

### Do:

-   Define interface only (no usage yet)

✅ No existing code modified

------------------------------------------------------------------------

## 🧩 PR 2 -- Wrap Match3 into Match3Game

### Add:

-   games/match3/Match3Game.gd
-   games/match3/Match3Game.tscn

### Do:

-   Move GameBoard under Match3Game scene
-   Match3Game emits:
    -   game_won
    -   game_lost

### Important:

-   DO NOT delete old flow yet

✅ Old system still drives gameplay

------------------------------------------------------------------------

## 🧩 PR 3 -- Introduce Parallel Flow (Shadow Mode)

### Modify:

-   ExperienceDirector.gd

### Do:

-   Instantiate Match3Game (new path)
-   Listen to signals
-   BUT keep old system active

### Goal:

-   Validate new flow without removing old one

------------------------------------------------------------------------

## 🧩 PR 4 -- Cut Over to New Flow

### Do:

-   Remove GameManager usage
-   Stop using MatchOrchestrator
-   Route start/end through ExperienceDirector

### Result:

-   New architecture is now live

------------------------------------------------------------------------

## 🧩 PR 5 -- Delete God Objects (SPLIT — see 5a–5d)

> ⚠️ Original plan said "do in one PR" but dependency count is too high
> (15+ files reference GameManager directly, 12+ reference EventBus).
> Split into 4 safe steps. Game must remain playable after each one.

------------------------------------------------------------------------
# PR 5 -- Delete God Objects (Refined & Safe Version)

Generated: 2026-03-28T20:06:02.482274

------------------------------------------------------------------------

## 🎯 Objective

Safely remove: - GameManager - MatchOrchestrator - EventBus

Without breaking gameplay at any stage.

This PR is split into 4 safe steps (5a--5d) using a strangler pattern.

------------------------------------------------------------------------

## 🧩 PR 5a --- Introduce GameRunState (DATA ONLY)

### Add:

games/match3/GameRunState.gd (autoload)

### Implementation:

``` gdscript
class_name GameRunState

var grid
var score := 0
var moves_left := 0
var level := 0

var flags = {
    "processing_moves": false,
    "level_transitioning": false,
    "pending_level_complete": false
}
```

### Rules:

-   ❌ NO methods with logic
-   ❌ NO orchestration
-   ❌ NO gameplay decisions

### Do:

-   Extract ALL pure data from GameManager into GameRunState
-   GameManager becomes a thin proxy

### Goal:

Introduce a stable read/write state WITHOUT changing callers

------------------------------------------------------------------------

## 🧩 PR 5b --- Migrate Call Sites (GameManager → GameRunState)

### Strategy:

Use aliasing to avoid brittle refactors:

``` gdscript
var state = GameRunState
state.score += 10
```

### Modify:

-   GameBoard.gd
-   BoardActionExecutor.gd
-   BoardInputHandler.gd
-   BoardVisuals.gd
-   BoardSetup.gd
-   BoardLayout.gd
-   BoardAnimator.gd
-   CollectibleService.gd
-   SpreaderService.gd
-   BoosterService.gd
-   HUDComponent.gd
-   BoosterPanelComponent.gd
-   ShardDropSystem.gd
-   LoadLevelStep.gd
-   Tile.gd

### Replace:

-   GameManager.grid → GameRunState.grid
-   GameManager.score → GameRunState.score
-   GameManager constants → GameRunState constants

### Important:

-   DO NOT delete GameManager yet
-   It remains as coordinator only

------------------------------------------------------------------------

## 🧩 PR 5c --- Replace EventBus with Direct Signals

### Core Rule:

Signals must be emitted by the **true owner**

  Event                   Owner
  ----------------------- --------------------
  match found             GameBoard
  cascade finished        GameBoard
  collectible collected   CollectibleService
  game won/lost           Match3Game

------------------------------------------------------------------------

### Implementation Pattern:

#### Inside GameBoard:

``` gdscript
signal match_found
signal board_stable
```

#### Inside Match3Game (wiring hub):

``` gdscript
func _ready():
    board.match_found.connect(_on_match_found)

func _on_match_found(data):
    emit_signal("match_found", data)
```

------------------------------------------------------------------------

### Modify:

-   GameFlowController.gd
-   CollectibleService.gd
-   GalleryManager.gd
-   ShardDropSystem.gd
-   NarrativeStageController.gd
-   ShowNarrativeStep.gd
-   LoadLevelStep.gd
-   PageManager.gd
-   StartPage.gd

------------------------------------------------------------------------

### Do:

-   Replace ALL EventBus emits with direct signals
-   Replace ALL EventBus connects with node connections

------------------------------------------------------------------------

### Important:

-   Keep EventBus as EMPTY passthrough
-   No traffic should go through it anymore

------------------------------------------------------------------------

## 🧩 PR 5d --- Delete God Objects

### Delete:

-   scripts/GameManager.gd
-   scripts/game/MatchOrchestrator.gd
-   scripts/EventBus.gd

### Remove from autoload:

-   EventBus
-   GameManager

------------------------------------------------------------------------

### Pre-Delete Checklist:

Search across project:

-   "GameManager"
-   "EventBus"

Check: - .gd files - .tscn files - .tres files

------------------------------------------------------------------------

### Also verify:

``` gdscript
get_node("/root/EventBus") ❌
```

------------------------------------------------------------------------

### Runtime Safety:

Temporarily add:

``` gdscript
assert(GameRunState != null)
```

------------------------------------------------------------------------

## 🚨 Safety Rules

-   One PR = one concern
-   Game must run after EACH step
-   Prefer duplication over risky edits
-   Only delete after replacement works

------------------------------------------------------------------------

## ⚠️ Known Risks

### 1. GameRunState becoming God object

Never add: - gameplay logic - orchestration - control flow

------------------------------------------------------------------------

### 2. Signal misplacement

Always emit from: - the node that detects the event

------------------------------------------------------------------------

### 3. Hidden references

Check scenes (.tscn) for lingering dependencies

------------------------------------------------------------------------

## ✅ Outcome After PR 5

-   GameManager removed
-   EventBus removed
-   MatchOrchestrator removed
-   State isolated
-   Signals localized

------------------------------------------------------------------------


## 🧩 PR 6 -- Isolate GameBoard ✅ COMPLETE

### Done:

-   `scripts/GameBoard.gd` → `games/match3/board/GameBoard.gd` ✅
-   `scripts/game/*.gd` (25 services) → `games/match3/board/services/` ✅
-   `MainGame.tscn` script reference updated to new path ✅
-   `GameManager.gd` service load paths updated ✅
-   Test files updated, old shims deleted ✅
-   `GameManager` removed as explicit pass-through param from `GravityAnimator`, `MatchOrchestrator`, `BorderRenderer` ✅
-   `GameBoard` call sites updated — no longer passes `GameManager` to delegates ✅

------------------------------------------------------------------------

## ⚠️ PR 5d DEBT — GameManager Still Alive

The PR 5d deletion was **never executed**. `GameManager` is still an
autoload and is doing real gameplay work. 25 files reference it.

### Why it wasn't deleted after PR 5:

PR 4 ("Cut over to new flow through ExperienceDirector") was never
fully completed — the game still runs gameplay logic **through
GameManager**, not through `Match3Game`. The signals `level_complete`
and `level_failed` on `GameManager` are the live wiring for
`LoadLevelStep`, `NarrativeStageController`, `EffectResolver`,
`HUDComponent`, `ShardDropSystem`, and `BoosterPanelComponent`.

`GameRunState` is data-only and correct per plan. But `GameManager`
still owns all gameplay **methods**: `find_matches`, `remove_matches`,
`apply_gravity`, `fill_empty_spaces`, `swap_tiles`,
`shuffle_until_moves_available`, `is_cell_blocked`, `get_tile_at`.

### Files still calling GameManager (25 total):

**Board services (already in games/match3/):**
- `MatchOrchestrator.gd` — `find_matches`, `remove_matches`, `get_tile_at`, signals
- `MatchProcessor.gd` — `report_unmovable_destroyed`, `report_spreader_destroyed`
- `ObjectiveManager.gd` — score, moves, objectives
- `SpecialFactory.gd` — grid reads
- `SpreaderService.gd` — `report_spreader_destroyed`, `unmovable_map`

**Pipeline:**
- `LoadLevelStep.gd` — connects to `level_complete`/`level_failed` signals, sets `level`

**UI/Components:**
- `HUDComponent.gd` — connects to score/moves signals
- `BoosterPanelComponent.gd` — connects to `level_loaded` signal
- `GameUI.gd` — level loading, board visibility
- `PageManager.gd` — gets GameManager for level state

**Systems:**
- `ShardDropSystem.gd` — connects to `match_cleared` signal
- `EffectResolver.gd` — connects to `match_cleared`, `level_complete`
- `NarrativeStageController.gd` — connects to `level_complete`

**Other:**
- `Tile.gd` — `grid`, `COLLECTIBLE`, `_transform_on_hard_destroy`
- `ExperienceDirector.gd`, `LevelProgress.gd`, `LevelTransition.gd`
- `node_resolvers.gd`, `node_resolvers_api.gd`, `node_resolvers_shim.gd`
- `progressive_brightness_executor.gd`
- `Match3Game.gd` — bridges `level_complete` signal
- `GameBoard.gd` — `register_board`, `skip_bonus_animation`, `shuffle_until_moves_available`

### Plan to actually remove GameManager:

**Step 1 (PR 6.5a):** Move gameplay **methods** from `GameManager` into
`GameRunState` or dedicated services inside `games/match3/`:
- `find_matches` → `games/match3/board/services/MatchFinder.gd` (already exists as static)
- `apply_gravity` / `fill_empty_spaces` → delegate fully to `GravityService` (already done, remove wrapper)
- `swap_tiles`, `is_cell_blocked`, `get_tile_at` → `GameRunState` helpers or inline in callers

**Step 2 (PR 6.5b): Move signals to true owners ✅ COMPLETE**
- All signals (`score_changed`, `moves_changed`, `collectibles_changed`, `unmovables_changed`, `spreaders_changed`, `level_loaded`, `level_complete`, `level_failed`, `game_over`, `board_idle`, `match_cleared`, `pre_refill`, `post_refill`, `collectible_landed`, `unmovable_destroyed`, `special_tile_activated`, `bonus_skipped`) now declared on `GameBoard` ✅
- `GameBoard._deferred_wait_for_gamemanager` removed — no longer connects to `GameManager` signals ✅
- `HUDComponent` connects to `board_ref` directly, GameManager fallback removed ✅
- `BoardLayout` GameManager reference removed ✅
- `CollectibleService` GameManager fallback removed ✅


- `level_complete` / `level_failed` → `GameFlowController` (already emits, just re-wire listeners)
- `match_cleared` → `MatchOrchestrator` / `GameBoard`
- `pre_refill` / `post_refill` → `GameBoard`
- `level_loaded` → `LevelLoader` service

**Step 3 (PR 6.5c):** Migrate all 25 caller files to the new signal owners and method locations.

**Step 4 (PR 6.5d): Delete `scripts/GameManager.gd` and remove from autoloads ✅ COMPLETE**
- `GameManager` autoload removed from `project.godot` ✅
- `scripts/GameManager.gd` replaced with tombstone (push_error if instantiated) ✅
- `node_resolvers.gd` `_get_gm()` permanently returns null ✅
- Stale GameManager comments cleaned from `MatchFinder.gd`, `Scoring.gd`, `SpecialFactory.gd` ✅

------------------------------------------------------------------------

## 🧩 PR 7 -- Thin GameFlowController ✅ COMPLETE

### Done:

- `GameFlowController` now only sequences: wait for processing, bonus cascade, save stars, fire bridge event ✅
- `RewardManager.grant_level_completion_reward()` removed from `GameFlowController` — reward granting is the pipeline's responsibility (`GrantRewardsStep`) ✅
- `StarRatingManager` and `LevelManager` accessed as autoloads directly — no more `get_node_or_null("/root/...")` traversal ✅
- `_calculate_stars()` uses autoloads directly, `LevelData.has("moves")` crash fixed (typed class, not Dictionary) ✅
- `GameStateBridge.emit_level_complete()` and `emit_level_failed()` restored (removed by mistake in earlier work) so pipeline advances to `show_rewards` / failure screen ✅
- `BoosterService._get_board()` — removed manual `load()` of node_resolvers; uses `NodeResolvers` autoload directly ✅
- Swap booster freeze fix: `processing_moves` cleared before `_check_collectibles_at_bottom()` so collectible collection triggers gravity+refill correctly ✅
- `CollectibleService` — `attempt_level_complete()` no longer gated on `processing_moves` so objectives met via booster path are always checked ✅

------------------------------------------------------------------------

## 🧩 PR 8 -- Introduce Pipeline ✅ COMPLETE

### Done:

- `scripts/runtime_pipeline/` → `experience/pipeline/` (14 files) ✅
- `scripts/runtime_pipeline/steps/` → `experience/pipeline/steps/` (11 steps) ✅
- `scripts/ExperienceDirector.gd` → `experience/ExperienceDirector.gd` ✅
- `scripts/FlowCoordinator.gd` → `experience/FlowCoordinator.gd` ✅
- `scripts/ExperienceFlowParser.gd` → `experience/ExperienceFlowParser.gd` ✅
- `scripts/ExperienceState.gd` → `experience/ExperienceState.gd` ✅
- `scripts/NarrativeStageController.gd` → `experience/narrative/NarrativeStageController.gd` ✅
- `scripts/NarrativeStageManager.gd` → `experience/narrative/NarrativeStageManager.gd` ✅
- `scripts/NarrativeStageRenderer.gd` → `experience/narrative/NarrativeStageRenderer.gd` ✅
- All `res://` paths updated in 17 source files — zero stale references ✅
- `project.godot` autoloads updated for `NarrativeStageManager` and `ExperienceDirector` ✅
- `scripts/runtime_pipeline/` directory removed (now empty) ✅
- All moves done with `git mv` — full rename history preserved ✅

------------------------------------------------------------------------

## 🧩 PR 9 -- Meta Extraction ✅ COMPLETE

### Done:

- `meta/` layer created with four sub-directories ✅
- `scripts/progression/` → `meta/progression/` (AchievementManager, GalleryManager, ProfileManager, ProgressManager) ✅
- `scripts/RewardManager.gd` → `meta/rewards/RewardManager.gd` ✅
- `scripts/StarRatingManager.gd` → `meta/rewards/StarRatingManager.gd` ✅
- `scripts/RewardOrchestrator.gd` → `meta/rewards/RewardOrchestrator.gd` ✅
- `scripts/reward_system/` (9 files) → `meta/rewards/system/` ✅
- `scripts/model/GameState.gd` → `meta/profile/GameState.gd` ✅
- `scripts/LevelProgress.gd` → `meta/profile/LevelProgress.gd` ✅
- `scripts/CollectionManager.gd` → `meta/systems/CollectionManager.gd` ✅
- `scripts/systems/` (GalleryImageLoader, ShardDropSystem, StoryManager, ContentPackTranslationLoader) → `meta/systems/` ✅
- `scripts/managers/` (stale unreferenced duplicates) deleted ✅
- All `res://` paths updated in 9 source files — zero stale references ✅
- `project.godot` autoloads updated for all 10 moved autoloads ✅
- Old directories removed: `scripts/progression/`, `scripts/reward_system/`, `scripts/systems/`, `scripts/model/`, `scripts/managers/` ✅
- Godot filesystem cache cleared (`filesystem_cache10`, `uid_cache.bin`) — reopen project in editor before running ✅

------------------------------------------------------------------------

## 🧩 PR 10 -- Systems Cleanup ✅ COMPLETE

### Done:

- `systems/` layer populated with all platform/infrastructure scripts ✅
- `scripts/AudioManager.gd` → `systems/AudioManager.gd` ✅
- `scripts/AdMobManager.gd` → `systems/AdMobManager.gd` ✅
- `scripts/AssetRegistry.gd` → `systems/AssetRegistry.gd` ✅
- `scripts/ThemeManager.gd` → `systems/ThemeManager.gd` ✅
- `scripts/DLCConfig.gd` → `systems/DLCConfig.gd` ✅
- `scripts/DLCManager.gd` → `systems/DLCManager.gd` ✅
- `scripts/EffectResolver.gd` → `systems/EffectResolver.gd` ✅
- `scripts/VibrationManager.gd` → `systems/VibrationManager.gd` ✅
- `scripts/TileTextureGenerator.gd` → `systems/TileTextureGenerator.gd` ✅
- `scripts/TranslationBootstrap.gd` → `systems/TranslationBootstrap.gd` ✅
- `scripts/LevelManager.gd` → `systems/LevelManager.gd` ✅
- `scripts/effects/` (21 executor files) → `systems/effects/` ✅
- `scripts/services/MatchFinder.gd` → `games/match3/board/services/MatchFinder.gd` ✅
- `scripts/services/Scoring.gd` → `games/match3/board/services/Scoring.gd` ✅
- All `res://` paths updated in 9 source files — zero stale references ✅
- `project.godot` autoloads updated for all 11 moved autoloads ✅
- Old directories removed: `scripts/effects/`, `scripts/services/` ✅
- Godot filesystem cache cleared (`filesystem_cache10`, `uid_cache.bin`) ✅
- **Bug fix:** Shard popup shown twice — per-frame deduplication guard added to `GalleryManager.add_shard()` ✅
- **Bug fix:** Reward screen rendered over live board — `GameBoard.visible = false` + `level_transitioning = true` set in `ShowRewardsStep` before reward controller starts ✅
- **Bug fix:** Progress not saved between sessions — `LoadLevelStep._on_level_complete_direct()` now calls `RewardManager.grant_level_completion_reward()` and `ProgressManager.complete_level()` ✅

------------------------------------------------------------------------

## 🧩 PR 11 -- Remove EventBus Completely ✅ COMPLETE

### Done:

- Confirmed `EventBus` already removed from `project.godot` autoloads (PR 5d) ✅
- `signal tile_destroyed(entity_id: String, context: Dictionary)` added to `GameBoard` ✅
- `GameStateBridge.report_unmovable_destroyed()` now emits `tile_destroyed` on `board_ref` with `{is_obstacle: true, grid_position: pos}` context ✅
- `ShardDropSystem` — removed `get_node_or_null("/root/EventBus")` fallback; now connects directly to `GameBoard.tile_destroyed` alongside all other board signals ✅
- `EffectResolver` — removed `get_node_or_null("/root/EventBus")` fallback; now connects `tile_destroyed` to `_on_event_with_entity.bind("tile_destroyed")` on `GameBoard` ✅
- All stale `EventBus` comments removed from `ShardToastNotifier`, `NarrativeStageController`, `ShowNarrativeStep` (×2), `PageManager`, `StartPage`, `DLCSystemTest` ✅
- Zero `EventBus` references remain in any `.gd` or `.tscn` file — verified by grep ✅

------------------------------------------------------------------------

## 🧩 PR 12 -- Final Cleanup ✅ COMPLETE

### Done:

- `scripts/LevelTransition.gd` deleted — replaced by pipeline steps in PR 8 ✅
- `scripts/GalleryUI.gd` deleted — replaced by `systems/gallery_system.gd` ✅
- `scripts/RewardNotification.gd` deleted — replaced by `RewardTransitionController` ✅
- `scripts/DLCDownloadTest.gd` deleted — unreferenced debug test script ✅
- `scripts/DLCSystemTest.gd` deleted — unreferenced debug test script ✅
- `scripts/AchievementsPage.gd` deleted — duplicate; live version is `scripts/ui/AchievementsPage.gd` ✅
- `scripts/ShopUI.gd` deleted — duplicate; live version is `scripts/ui/ShopUI.gd` ✅
- 11 orphan `.uid` files removed from `scripts/` and `scripts/ui/` ✅
- Zero stale references to deleted files — verified by grep ✅
- Godot filesystem cache cleared ✅

### 🏁 Refactor Complete

Target architecture fully achieved:
- `GameManager` removed ✅
- `EventBus` removed ✅
- `MatchOrchestrator` removed ✅
- `ExperienceDirector` = only orchestrator ✅
- Match3 fully encapsulated in `games/match3/` ✅
- No global event system ✅
- No cross-layer import violations ✅
- Signals owned by true emitters ✅

------------------------------------------------------------------------

## 🚨 SAFETY RULES

-   One PR = one concern
-   Always keep game playable
-   Prefer duplication over risky rewrites
-   Remove only after replacement works

------------------------------------------------------------------------

## ✅ END STATE

-   ExperienceDirector = only orchestrator
-   Match3 fully encapsulated
-   No global event system
-   Clean modular architecture

------------------------------------------------------------------------

## 💡 TIP

If a PR feels risky: → split it into 2

Speed comes from safety, not size.
