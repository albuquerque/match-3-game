﻿# Match-3 Game Architecture Refactoring Specification

## Document Version: 2.2 (Post-IDE-Restart Audit)
**Date:** March 5, 2026
**Author:** Architecture Review Team
**Status:** In Progress — A2/A7/A8/E4 Pending

---

## Refactor Progress (updated 2026-03-05)
This section is the **single source of truth** for the refactor effort. Update it after every atomic commit.

### Current State Snapshot

| File | Original Lines | Current Lines | Target Lines | Status |
|------|---------------|--------------|-------------|--------|
| `GameBoard.gd` | 3049 | **2101** | ~600 | 🟡 A1/A2/A3/A4/A5/A6/A7/A8 done. **Round 3 needed** |
| `GameManager.gd` | 1546 | **1007** | ~400 | 🟡 Phases B+C+D done — still 607 above target |
| `GameUI.gd` | 784 | **447** | ~250 | 🟡 E4 BLOCKED (HUDComponent not in scene tree) |
| `GameFlowController.gd` | — | **216** | ~200 | ✅ Phase C1 |
| `LevelLoader.gd` | — | **139** | ~140 | ✅ Phase D1 |
| `BoosterSelector.gd` | — | **50** | ~50 | ✅ Phase D2 |
| `HUDComponent.gd` | — | **167** | ~160 | ✅ Phase E1 |
| `BoosterPanelComponent.gd` | — | **146** | ~145 | ✅ Phase E2 |
| `FloatingMenuComponent.gd` | — | **63** | ~63 | ✅ Phase E |
| `GameState.gd` | — | **141** | ~120 | ✅ Created; partially wired |
| `GravityAnimator.gd` | — | **192** | ~200 | ✅ **A2 DONE** (2026-03-05) |
| `test_objective_manager.gd` | — | **97** | ~80 | ✅ **F4 DONE** (2026-03-05) |
| `test_gravity_animator.gd` | — | **82** | ~70 | ✅ **F5 DONE** (2026-03-05) |

---

### Component Creation Status (scripts/game/)

| Component File | Lines | Created | Wired into GameBoard | Wired into GameManager |
|---|---|---|---|---|
| `BoardEffects.gd` | 123 | ✅ | 🟡 partial (combo/shake delegated) | — |
| `BoardLayout.gd` | 174 | ✅ | ✅ **A8 DONE** (2026-03-05) — `create_visual_grid` delegates to `BoardVisuals.create_visual_grid` | — |
| `BoardVisuals.gd` | 235 | ✅ | ✅ **A8 DONE** (2026-03-05) — `create_visual_grid` fixed (unmovable signal wiring) | — |
| `BoosterService.gd` | 165 | ✅ | ✅ **A4 DONE** (2026-03-03) | — |
| `BorderRenderer.gd` | 195 | ✅ | ✅ **A3 DONE** (2026-03-03) | — |
| `EffectsRenderer.gd` | 217 | ✅ | ✅ **A6 DONE** (2026-03-03) | — |
| `GravityAnimator.gd` | 192 | ✅ | ✅ **A2 DONE** (2026-03-05) — full barrier/segment logic; `animate_gravity` + `animate_refill` delegated | — |
| `GravityService.gd` | 62 | ✅ | — | ✅ **B2 DONE** |
| `MatchFinder.gd` | ~~73~~ **DELETED** | ✅ | — | ✅ **B1 DONE** |
| `MatchOrchestrator.gd` | 134 | ✅ | ✅ **A1 DONE** (2026-03-03) | — |
| `MatchProcessor.gd` | 82 | ✅ | — | 🟡 partial |
| `ObjectiveManager.gd` | 73 | ✅ | ✅ **A7 DONE** (2026-03-05) — fallback branch removed from `_damage_adjacent_unmovables` | ✅ **B4 DONE** |
| `Scoring.gd` | ~~10~~ **DELETED** | ✅ | — | ✅ **B1 DONE** |
| `SpecialActivationService.gd` | 44 | ✅ | ✅ **A5 DONE** (2026-03-03) | — |
| `SpecialDetector.gd` | 72 | ✅ | 🟡 partial | — |
| `SpecialFactory.gd` | 102 | ✅ | 🟡 partial | — |
| `SpreaderService.gd` | 36 | ✅ | ✅ **A7 DONE** (2026-03-05) — `_apply_spreader_visuals` stays in GameBoard (needs `tiles` access, not external) | ✅ **B5 DONE** |
| `VisualEffects.gd` | 205 | ✅ | 🟡 partial | — |
| `VisualFactory.gd` | 37 | ✅ | 🟡 partial | — |

### UI Component Status (scripts/ui/components/)

| Component File | Lines | Created | Wired into GameUI |
|---|---|---|---|
| `HUDComponent.gd` | 167 | ✅ | ✅ **E1 DONE** — self-wires via `_connect_signals()`; GameUI still has ~80 lines of duplicate handlers (**E4 pending**) |
| `BoosterPanelComponent.gd` | 146 | ✅ | ✅ **E2 DONE** — self-wires to `RewardManager.booster_changed` and `GameManager.level_loaded` |
| `FloatingMenuComponent.gd` | 63 | ✅ | ✅ — fully wired |

### Service / Model Status

| File | Lines | Created | Status |
|---|---|---|---|
| `scripts/services/MatchFinder.gd` | 133 | ✅ | ✅ Canonical — `game/MatchFinder.gd` duplicate deleted (B1) |
| `scripts/services/Scoring.gd` | 12 | ✅ | ✅ Canonical — `game/Scoring.gd` duplicate deleted (B1) |
| `scripts/model/GameState.gd` | 141 | ✅ | 🟡 Partially wired — `_new_game_state()` / `_apply_game_state()` delegate to it; `get_safe_random_tile` / `would_create_initial_match` removed from GameManager (D3) |
| `scripts/progression/ProgressManager.gd` | 106 | ✅ | ✅ Active autoload |
| `scripts/progression/AchievementManager.gd` | 33 | ✅ | ✅ Active autoload |
| `scripts/progression/GalleryManager.gd` | 30 | ✅ | ✅ Active autoload |
| `scripts/progression/ProfileManager.gd` | 29 | ✅ | ✅ Active autoload |

---

### Completed Milestones

- [x] GameUI — StartPage integration and display handling
- [x] GameUI — Dynamic Enhanced GameOver panel (created at runtime)
- [x] GameUI — HUD reorganization and cleaner top-bar layout
- [x] GameUI — Dynamic booster panel (rebuilds based on `GameManager.available_boosters`)
- [x] GameUI — LevelTransition integration and ExperienceDirector routing
- [x] GameManager — `board_ref` registration API (`register_board` / `unregister_board` / `get_board`)
- [x] GameManager — `MatchFinder` + `Scoring` duplicates deleted; `scripts/services/` versions canonical
- [x] GameManager — `GameState` model (`scripts/model/GameState.gd` — 141 lines, partially wired)
- [x] GameManager — `ObjectiveManager` wired for all `report_*` functions (B4)
- [x] All `scripts/game/` component files created (17 active + 2 deleted duplicates)
- [x] All `scripts/ui/components/` component files created (3 files)
- [x] Narrative system, ExperienceDirector, ExperienceFlow — working
- [x] Level loading via ExperienceFlow — working
- [x] Translations via PO files — working
- [x] Spreader, Unmovable, Collectible objective types — working
- [x] Bonus cascade after level complete — working
- [x] Level completion detection — working
- [x] **Data consolidation — `data/chapters/` deleted.** All in-level effect + narrative data now lives in `data/narrative_stages/levels/level_N.json`. Global fallback is `data/narrative_stages/levels/default.json`. `_load_chapter_effects()` + `_load_in_level_narrative()` collapsed into single `_load_level_narrative()`.
- [x] Phase A: A1, A2, A3, A4, A5, A6, A7, A8 complete (2026-03-05)
- [x] Phase B: B1, B2, B3, B4, B5 complete
- [x] Phase C: C1, C2 complete (GameFlowController created and wired, 216 lines)
- [x] Phase D: D1, D2, D3 complete (LevelLoader 139 lines, BoosterSelector 50 lines, GameState helpers extracted)
- [x] Phase E: E1, E2, E3 complete (HUDComponent 167 lines, BoosterPanelComponent 146 lines, FloatingMenuComponent 63 lines)
- [x] Phase F: F1 (test_booster_selector 82 lines), F2 (test_level_loader 170 lines), F3 (test_game_flow_controller 269 lines), F4 (test_objective_manager 97 lines), F5 (test_gravity_animator 82 lines) written

---

## Immediate Next Steps (Phase-Based Wiring Plan)

> **Strategy:** Do NOT create new files. Wire the existing component files into the god objects and delete the duplicated inline code. Small, safe, atomic commits only.


---

### Phase A — Wire GameBoard to existing game/ components
**Goal:** Reduce `GameBoard.gd` from 3049 → ~600 lines by delegating to already-written components.
**Status: 🟡 PARTIAL — A1/A3/A4/A5/A6 complete (2026-03-03). A2 and A7 still pending. Current: 2439 lines.**

#### A1 ✅ — Wire MatchOrchestrator: remove GameBoard.process_cascade (2026-03-03)
- `process_cascade` is a short delegation call to `MatchOrchestrator`. Inline body removed.

#### A2 ❌ PENDING — Wire GravityAnimator: remove inline animate_gravity and animate_refill
- `animate_gravity` (~111 lines, line 1322) and `animate_refill` (~94 lines, line 1433) are still **fully inline** in GameBoard.
- `GravityAnimator.gd` (142 lines) exists but is not yet called from GameBoard.
- **Action:** Port the barrier/segment loop logic into `GravityAnimator.animate_gravity(board, gm)` and `GravityAnimator.animate_refill(board, gm)`. Replace the ~205 inline lines with two `await` delegation calls.
- **Risk:** MEDIUM — gravity is critical path. Test non-square boards (Level 2 plus-shape) and boards with unmovables/spreaders.
- **Estimated reduction:** −205 lines from GameBoard
- **Commit:** `refactor(GameBoard): wire GravityAnimator, remove inline gravity/refill animation`

#### A3 ✅ — Wire BorderRenderer: remove GameBoard border drawing (2026-03-03)
- `draw_board_borders` is an 18-line wrapper delegating to `BR.draw_board_borders()`.

#### A4 ✅ — Wire BoosterService: remove all booster activation bodies from GameBoard (2026-03-03)
- All 9 booster activation functions delegate to `BoosterService`.

#### A5 ✅ — Wire SpecialActivationService: remove GameBoard special tile activation (2026-03-03)
- `activate_special_tile` and `activate_special_tile_chain` delegate to `SpecialActivationService`.

#### A6 ✅ — Move lightning beam methods to EffectsRenderer (2026-03-03)
- `_create_lightning_beam_horizontal` and `_create_lightning_beam_vertical` are 7-line wrappers calling `ER.*`.

#### A7 ❌ PENDING — Wire SpreaderService + ObjectiveManager: remove adjacent damage functions
- `_damage_adjacent_unmovables` (~65 lines, line 2246), `_damage_adjacent_spreaders` (~40 lines, line 2311), and `_apply_spreader_visuals` (~38 lines, line 2351) are still **fully inline** in GameBoard (~143 lines total).
- **Action:** Move these three into `ObjectiveManager.damage_adjacent_unmovables(board, gm, matched_positions)`, `SpreaderService.damage_adjacent_spreaders(board, gm, matched_positions)`, and `SpreaderService.apply_spreader_visuals(board, gm, new_positions)`. Replace with 1–3 line delegation calls.
- **Risk:** MEDIUM — spreader and unmovable logic is subtle. Test Level 4 (unmovables) and Level 31 (spreaders).
- **Estimated reduction:** −143 lines from GameBoard
- **Commit:** `refactor(GameBoard): wire SpreaderService + ObjectiveManager for adjacent tile damage`

#### A8 (NEW) ❌ PENDING — Wire BoardLayout: move create_visual_grid out of GameBoard
- `create_visual_grid` (~125 lines, line 505) is still fully inline.
- `BoardLayout.gd` (174 lines) exists but `create_visual_grid` has not been moved into it.
- **Action:** Move grid creation loop into `BoardLayout.create_visual_grid(board, gm)`. Replace the inline function with a delegation wrapper.
- **Risk:** MEDIUM — board setup is called on level load. Test carefully.
- **Estimated reduction:** −90 lines from GameBoard
- **Commit:** `refactor(GameBoard): wire BoardLayout.create_visual_grid, remove inline grid creation`

---

### Remaining Work Summary (as of 2026-03-05)

| # | Task | File(s) | Est. Reduction | Priority |
|---|------|---------|---------------|----------|
| **A2** | Wire GravityAnimator — remove inline `animate_gravity` + `animate_refill` | `GameBoard.gd`, `GravityAnimator.gd` | −205 lines | 🔴 HIGH |
| **A7** | Wire SpreaderService/ObjectiveManager — remove 3 adjacent damage functions | `GameBoard.gd`, `ObjectiveManager.gd`, `SpreaderService.gd` | −143 lines | 🔴 HIGH |
| **A8** | Wire BoardLayout — move `create_visual_grid` | `GameBoard.gd`, `BoardLayout.gd` | −90 lines | 🟡 MEDIUM |
| **E4** | Remove duplicate HUD signal handlers from GameUI | `GameUI.gd` | −80 lines | 🟡 MEDIUM |
| **F4** | Write `tests/test_objective_manager.gd` (currently 0 lines) | `tests/test_objective_manager.gd` | — | 🟡 MEDIUM |
| **F5** | Write `tests/test_gravity_animator.gd` (after A2) | `tests/test_gravity_animator.gd` | — | 🟢 LOW |

---

### Remaining Work Summary (as of 2026-03-05)

| # | Task | File(s) | Est. Reduction | Priority | Status |
|---|------|---------|---------------|----------|--------|
| **E4** | Remove duplicate HUD handlers from GameUI | `GameUI.gd` | −80 lines | 🟡 MEDIUM | ⛔ BLOCKED — HUDComponent not in scene tree |
| **Round 3** | Extract remaining ~1500 lines from GameBoard | `GameBoard.gd` | −1500 lines | 🔴 HIGH | 📋 Needs new plan |

**E4 Pre-requisite:** Add `HUDComponent.tscn` as a child of `GameUI` in `MainGame.tscn`,
confirm HUD still works, then delete the ~85-line fallback from `GameUI.gd`.

**Round 3 targets in `GameBoard.gd` (~2109 lines) — see `docs/refactor-round3.md` for full plan:**
- **Step 1:** Delete ~140 lines of dead stubs (`_await_tweens_with_timeout`, `_mark_tween_finished`, debug scaffold, dead alias vars)
- **Step 2:** Delegate 8 VisualFX functions → `BoardEffects.gd` (already exists, ~51 lines)
- **Step 3:** Extract `BoardSetup.gd` (NEW) — 14 layout/setup functions (~270 lines)
- **Step 4:** Extract `BoardAnimator.gd` (NEW) — 7 destroy/highlight/shuffle animations (~226 lines)
- **Step 5:** Extract `BoardInputHandler.gd` (NEW) — `_on_tile_clicked`, `_on_tile_swiped`, `perform_swap`, `find_special_tile_position` (~316 lines) ⚠️ HIGH RISK
- **Step 6:** Extract `BoardActionExecutor.gd` (NEW) — 9 booster funcs + special tile activation (~479 lines) ⚠️ HIGH RISK
- **Step 7:** Extract `CollectibleService.gd` (NEW) — `_check_collectibles_at_bottom` (~94 lines)
- **Step 8:** Slim AdjDamage → `SpreaderService`/`ObjectiveManager` static funcs (~50 lines)
- **Projected result:** `GameBoard.gd` ~510 lines ✅ within ~600 target

---

### Phase B — Wire GameManager to existing game/ components
**Goal:** Reduce `GameManager.gd` from 1545 → ~400 lines.
**Status: ✅ COMPLETE (2026-03-03) — Phases B+C+D together: 1546 → 1007 lines (−539 lines)**

#### B1 ✅ — Wire MatchFinder, delete duplicates
- `find_matches()` slimmed to a single-line delegation to `MatchFinder` autoload
- `scripts/game/MatchFinder.gd` deleted (duplicate); `scripts/services/MatchFinder.gd` (133 lines) is canonical
- `scripts/game/Scoring.gd` deleted (duplicate); `scripts/services/Scoring.gd` (12 lines) is canonical

#### B2 ✅ — Clean up apply_gravity and fill_empty_spaces
- Both functions kept as canonical barrier-aware implementations in GameManager (GravityService stub too simple to replace them)
- Removed verbose multi-paragraph comments

#### B3 ✅ — Simplify create_empty_grid and fill_grid_from_layout
- Replaced 120+ lines of multi-fallback defensive code with `_new_game_state()` + `_apply_game_state()` helpers (~35 lines total) delegating to `GameState.gd`

#### B4 ✅ — Wire ObjectiveManager reporting functions
- `report_spreader_destroyed`, `report_unmovable_destroyed`, `collectible_landed_at` each slimmed to 6–10 line wrappers delegating to ObjectiveManager

#### B5 ✅ — Wire SpreaderService: slim check_and_spread_tiles
- Inline fallback spread loop removed; `SpreaderService.spread()` is the only path
- `has_possible_moves` refactored using `_copy_grid()` helper, eliminating code duplication

---

### Phase C — Extract GameFlowController from GameManager
**Goal:** Extract level-complete/fail/bonus cascade logic into its own component.
**Status: ✅ COMPLETE (2026-03-03) — rolled into Phase B+C+D total**

#### C1 ✅ — Create GameFlowController, wire into GameManager
- Created `scripts/game/GameFlowController.gd` (216 lines) containing:
  - `attempt_level_complete()` / `perform_level_completion_check()` — objective evaluation
  - `on_level_complete()` — star calc, rewards, EventBus emission, bonus trigger
  - `convert_remaining_moves_to_bonus()` — full bonus cascade with skip support
  - `perform_level_failed_check()` — out-of-moves detection
  - `_emit_eventbus_level_complete()` / `_emit_eventbus_level_failed()` — EventBus helpers
- GameManager functions replaced with 1–3 line wrappers delegating to `_flow_ctrl`

#### C2 ✅ — Instantiate GameFlowController in _init_resolvers
- `_flow_ctrl` instantiated via `load().new()` + `add_child()` + `setup(self)` in `_init_resolvers()`

---

### Phase D — Extract LevelLoader and BoosterSelector
**Goal:** Reduce `GameManager.gd` from ~1100 → ~600 lines.
**Status: ✅ COMPLETE (2026-03-03) — 1108 → 940 lines (−168 lines)**

#### D1 ✅ — Extract LevelLoader service
- Created `scripts/game/LevelLoader.gd` (~140 lines)
  - `load_level()` — async, awaits LevelManager ready, calls `_apply_level_data()` or `_apply_fallback()`
  - `_apply_level_data()` — writes all level fields onto GameManager vars, applies theme, builds grid, wires ObjectiveManager, attaches hard textures
  - `_attach_hard_textures()` / `_init_objective_manager()` — helper methods
- `GameManager.load_current_level()` reduced from ~200 lines to ~35 lines
- Inline fallback `_load_current_level_inline()` kept for safety (~20 lines)

#### D2 ✅ — Extract BoosterSelector service
- Created `scripts/game/BoosterSelector.gd` (~50 lines) with `static func select(level, tiers, weights)` 
- `GameManager.select_level_boosters()` reduced from ~35 to 6 lines with inline fallback `_select_boosters_inline()`

#### D3 ✅ — Remove get_safe_random_tile / would_create_initial_match from GameManager
- Both already exist in `GameState.gd`; removed ~30 lines of duplication from GameManager
- `fill_initial_grid()` simplified to a direct `randi()` loop (fallback path only)


---

### Phase E — Finish GameUI component wiring
**Goal:** Reduce `GameUI.gd` from 784 → ~250 lines.
**Status: 🟡 PARTIAL (2026-03-03) — 784 → 446 lines (−338 lines). Still ~196 lines above target.**

**Discrepancy note:** The previous snapshot claimed ~240 lines; actual count is 446. The HUDComponent (`_connect_hud_signals`, 8 inline signal handlers ~60 lines) and game-over panel code still reside in GameUI. The targets below are still outstanding.

#### E1 ✅ — HUDComponent self-wiring (2026-03-03)
- `HUDComponent._ready()` now calls `_connect_signals()` — subscribes to `GameManager` and `RewardManager` signals directly.
- Added `_refresh_from_gm()` and `_refresh_currency()` helpers.
- **Remaining:** GameUI still has `_connect_hud_signals()` (~25 lines) + duplicate handlers `_on_score_changed`, `_on_moves_changed`, `_on_level_changed`, `_on_collectibles_changed`, `_on_unmovables_changed`, `_on_currency_changed`, `_refresh_target_display`, `_refresh_currency_display` (~80 lines). These should be removed from GameUI as HUDComponent now owns them.
- **Pending cleanup commit:** `ui: remove duplicate HUD signal handlers from GameUI (~80 lines)`

#### E2 ✅ — BoosterPanelComponent self-wiring (2026-03-03)
- `BoosterPanelComponent._ready()` connects to `RewardManager.booster_changed` and `GameManager.level_loaded` automatically.
- `GameUI.update_booster_ui()` (6-line delegator, line 289) remains but is now minimal.

#### E3 ✅ — Remove debug methods and leftover flat-node signal wiring (2026-03-03)
- `_deferred_startpage_check`, `_deferred_children_dump` removed.
- Most `gm.connect()` calls for HUD signals moved to HUDComponent.

#### E4 (NEW) — Remove duplicate HUD handlers from GameUI
- **Action:** Delete `_connect_hud_signals()`, `_on_score_changed`, `_on_moves_changed`, `_on_level_changed`, `_on_collectibles_changed`, `_on_unmovables_changed`, `_on_currency_changed`, `_refresh_target_display`, `_refresh_currency_display`, and the private label accessor helpers (`_score_label`, `_moves_label`, etc.) from `GameUI.gd`. HUDComponent owns these.
- **Risk:** LOW — HUDComponent already handles all of these via `_connect_signals()`. Verify visually that HUD still updates after removing GameUI handlers.
- **Estimated reduction:** −80 lines from GameUI → brings GameUI to ~366 lines.
- **Commit:** `ui(GameUI): remove duplicate HUD signal handlers, rely fully on HUDComponent`

---

### Phase F — Tests and Documentation
**Status: 🟡 PARTIAL (as of 2026-03-05)**

#### F1 ✅ — `tests/test_booster_selector.gd` (82 lines)
6 test cases: returns Array, count always 3-5, determinism, always includes a common booster, no duplicates, custom tier override.

#### F2 ✅ — `tests/test_level_loader.gd` (170 lines)
5 test cases: field assignment from `MockLevelData`, `create_empty_grid` + `fill_grid_from_layout` called, fallback defaults (8×8 / 10000 / 30 moves), hard texture attachment to `unmovable_map`, spreader texture map population.

#### F3 ✅ — `tests/test_game_flow_controller.gd` (269 lines)
11 test cases: pending flag set on `attempt_level_complete`, no-op when already pending, score-based completion triggers `on_level_complete`, primary objective blocks score-only completion, collectible/unmovable/spreader goal completion, `perform_level_failed_check` emits `game_over`, fails skipped when score or collectible already met, `_calculate_stars` thresholds (1/2/3 stars), `skip_bonus_animation` sets `bonus_skipped` flag.

#### F4 ❌ PENDING — `tests/test_objective_manager.gd`
File exists at 0 lines — **not yet written**. Should cover: `report_unmovable_cleared`, `report_spreader_destroyed`, `collectible_landed_at`, objective completion checks for all goal types.

#### F5 ❌ PENDING — `tests/test_gravity_animator.gd`
After A2 (GravityAnimator wiring), add tests for barrier segment detection and column segment logic.

#### F6 ✅ — Changelog updated
`ARCHITECTURE_REFACTOR_CHANGELOG.md` updated with dated entries through Phase F.

---

### How to Mark Items Complete
After each atomic commit, check the relevant box in the Component Creation Status tables above, add the commit hash and date inline, and update the "Current State Snapshot" table line counts.

### Notes & Assumptions
- Godot 4.5+ and GDScript coding conventions apply (tabs for indentation).
- Keep existing autoload signals and public APIs stable — external systems (`ExperienceDirector`, `RewardManager`, `LevelManager`) must not require changes.
- Prioritize wiring existing components before creating new ones.
- Never break a working game feature. Test after every commit.
- GameManager should ultimately know only: grid data, score, moves, level number, and how to coordinate its services. All other logic lives in focused components.

---

## Table of Contents
1. [Current Problems](#current-problems)
2. [Target Architecture Overview](#target-architecture-overview)
3. [Core Navigation Flow](#core-navigation-flow)
4. [Component Specifications](#component-specifications)
5. [File Structure](#file-structure)
6. [Data Flow Examples](#data-flow-examples)
7. [Implementation Phases](#implementation-phases)
8. [Success Criteria](#success-criteria)
9. [Appendix: Sample Code Templates](#appendix-sample-code-templates)

---

## Current Problems

### Identified Issues in Current Codebase

| Problem | Location | Impact |
|---------|----------|--------|
| **God Classes** | `GameBoard.gd` (3049 lines), `GameManager.gd` (1545 lines) | Difficult to maintain, debug, or extend |
| **Tight Coupling** | UI directly manipulates game logic | Changes in one system break others |
| **Mixed Concerns** | Level loading, boosters, objectives, narrative flow tangled in GameManager | No clear separation of responsibilities |
| **Un-wired Components** | 19 component files in `scripts/game/` exist but code NOT removed from God Objects | Components are dead weight — duplication + risk |
| **Missing Abstractions** | Gallery, achievements, profile exist as autoloads but not fully integrated | Cannot extend features without touching core files |
| **Unclear Navigation** | PageManager exists but some navigation bypasses it | Back button behavior inconsistent |
| **Progress Tracking** | ProgressManager autoload exists; partially integrated | Player progress partially tracked |

---

## Target Architecture Overview

### High-Level Architecture


```
┌─────────────────────────────────────────────────────────────┐
│                         ENTRY POINT                                                                                   │
│                      ┌───────────────┐                                                                         │
│                      │   HomePage           │                                                                        │
│                      │   (Main Hub)           │                                                                         │
│                      └───────┬───────┘                                                                          │
└──────────────────────────────┼───────────────────────────────┘
│
┌───────────────┼───────────────┬───────────────┐
▼               ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  WorldMap   │ │  Gallery    │ │Achievements │ │  Settings   │
│Level Select │ │   Page      │ │    Page     │ │    Page     │
└──────┬──────┘ └─────────────┘ └─────────────┘ └─────────────┘
│              │               │               │
▼              ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ GameScene   │ │   About     │ │  Profile    │ │   Future    │
│  Gameplay   │ │    Page     │ │    Page     │ │   Pages     │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

```

### System Layers

```

┌─────────────────────────────────────────────────────────────┐
│                    NAVIGATION LAYER                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ HomePage │  │ WorldMap │  │ Gallery  │  │Settings  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│       │              │              │              │        │
│       └──────────────┼──────────────┼──────────────┘        │
│                 ┌────▼────┐    ┌────▼────┐                  │
│                 │ GameScene│    │ Profile │                  │
│                 └────┬────┘    └────┬────┘                  │
└──────────────────────┼────────────────┼──────────────────────┘
│                │
▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                      GAME LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ GameManager  │  │  GameBoard   │  │ObjectiveSys  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │BoosterSystem │  │  LevelManager│                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                   PROGRESSION LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ProgressMgr   │  │GalleryMgr    │  │AchievementMgr│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ProfileMgr    │  │ RewardManager│                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                   EXPERIENCE LAYER                           │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ExperienceDir │  │NarrativeMgr  │                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                      EVENT BUS                               │
│              (Central Communication Hub)                     │
└─────────────────────────────────────────────────────────────┘

```

---

## Core Navigation Flow

### Page Manager Responsibilities

The `PageManager` (autoload) manages all navigation with a stack-based approach:

```gdscript
# PageManager.gd - Core Navigation Controller
enum Page {
    HOME,
    WORLD_MAP,
    GALLERY,
    ACHIEVEMENTS,
    SETTINGS,
    ABOUT,
    PROFILE,
    GAME
}

# Navigation Rules:
# 1. All pages except HOME must provide a way to return to HOME
# 2. GameScene automatically returns to HOME on completion/failure
# 3. Back button/gesture pops the navigation stack
# 4. Each page can be initialized with data parameters
```

Page Relationships

Page Purpose Navigation Rules Key Data
HomePage Main navigation hub with "Play Next" button Root of navigation stack Player stats summary
WorldMap Visual level selection with unlock status Returns to HomePage Level progress data
GalleryPage Unlockable art/cutscenes/music (categorized) Returns to HomePage Unlocked items
AchievementsPage Achievement list with progress tracking Returns to HomePage Achievement progress
SettingsPage Game configuration with tabs Returns to HomePage User preferences
AboutPage Credits, version, external links Returns to HomePage Static content
ProfilePage Player stats, collection progress Returns to HomePage Player statistics
GameScene Active gameplay Auto-returns to HomePage Level data

---

Component Specifications

1. PageManager (Autoload)

Purpose: Central navigation controller managing page stack and transitions.

Key Features:

· Stack-based navigation with back button support
· Page transition animations
· State preservation when switching pages
· Deep linking support (direct navigation to any page)

API:

```gdscript
func go_to_page(page: Page, data: Dictionary = {}) -> void
func go_back() -> void
func get_current_page() -> Page
func replace_current_page(page: Page, data: Dictionary = {}) -> void
func clear_stack_and_go_to(page: Page, data: Dictionary = {}) -> void
```

Signals:

· page_changed(from_page: Page, to_page: Page)
· navigation_stack_updated(stack: Array)

2. HomePage (Main Hub)

Purpose: Primary navigation hub showing player status and quick actions.

UI Elements:

· Player avatar/name
· Currency display (coins, gems)
· "Play Next Level" prominent button
· Grid of navigation buttons:
  · World Map
  · Gallery
  · Achievements
  · Settings
  · About
  · Profile
· Notification badges on buttons with updates

Key Logic:

```gdscript
# On ready:
- Get next incomplete level from ProgressManager
- Update "Play Next" button text: "Play Level X" or "Continue Story"
- Check for unviewed gallery items (show badge)
- Check for new achievements (show badge)

# On Play Next pressed:
- Get next level ID from ProgressManager
- Navigate to GameScene with level ID
```

3. WorldMap (Level Selection)

Purpose: Visual representation of all levels with unlock/completion status.

Features:

· Scrollable/zoomable map background
· Level nodes at specific coordinates (defined in level data)
· Visual states: Locked, Unlocked, Completed (with stars)
· Tooltips showing level name and objectives
· "Return to Hub" button

Level Node States:

```
🔒 Locked - Cannot play, shows unlock condition
🔓 Unlocked - Available to play, shows level number
⭐ Completed - Shows 1-3 stars earned
🎉 Perfect - Special animation for 3-star completion
```

Key Logic:

```gdscript
func build_map():
    all_levels = LevelManager.get_all_levels()
    progress = ProgressManager.get_level_progress()
    
    for level in all_levels:
        node = create_level_node(level)
        node.position = level.map_coordinates
        node.state = get_level_state(level.id, progress)
        node.pressed.connect(_on_level_selected.bind(level.id))
```

4. ProgressManager (Autoload) - NEW

Purpose: Central tracking for all player progress and unlocks.

Data Tracked:

```gdscript
{
    "levels": {
        "level_1": {
            "completed": true,
            "stars": 3,
            "high_score": 12500,
            "moves_used": 15,
            "completed_at": 1709123456,
            "play_count": 3
        }
    },
    "narratives_seen": ["intro_1", "level_5_complete", "booster_tutorial"],
    "gallery_unlocks": {
        "concept_art": ["hero_01", "enemy_03"],
        "cutscenes": ["intro", "ending"],
        "music": ["main_theme", "boss_battle"]
    },
    "achievements": {
        "first_match": {"unlocked": true, "unlocked_at": 1709123456},
        "combo_master": {"progress": 8, "target": 10, "unlocked": false}
    },
    "statistics": {
        "total_play_time": 3600,
        "total_matches": 1250,
        "total_swaps": 3420,
        "boosters_used": 45,
        "best_combo": 12
    }
}
```

Key Methods:

```gdscript
func complete_level(level_id: String, stars: int, score: int, moves: int) -> void
func is_level_unlocked(level_id: String) -> bool
func get_next_incomplete_level() -> String
func mark_narrative_seen(narrative_id: String) -> void
func unlock_gallery_item(category: String, item_id: String) -> void
func update_achievement(achievement_id: String, progress: int) -> void
func get_player_stats() -> Dictionary
```

5. GalleryManager (Autoload) - NEW

Purpose: Manage unlockable collectibles across categories.

Categories:

```
📁 concept_art/     - Early designs, sketches
📁 cutscenes/       - Unlocked cinematics
📁 music/           - Soundtrack tracks
📁 character_art/   - Character illustrations
📁 special/         - Secret unlocks, Easter eggs
```

Unlock Conditions:

```gdscript
var unlock_rules = {
    "concept_art/hero_01": {"type": "level_complete", "level": 1},
    "concept_art/enemy_03": {"type": "level_stars", "level": 5, "stars": 3},
    "cutscenes/secret_ending": {"type": "all_levels_complete", "stars_required": 3},
    "music/boss_theme": {"type": "achievement", "achievement": "defeated_boss"}
}
```

API:

```gdscript
func check_for_unlocks(event_type: String, event_data: Dictionary) -> void
func get_unlocked_items(category: String) -> Array
func is_item_unlocked(category: String, item_id: String) -> bool
func get_all_unlocked() -> Dictionary
func preview_item(category: String, item_id: String) -> Dictionary
```

6. AchievementManager (Autoload) - NEW

Purpose: Track and manage achievement progression.

Achievement Categories:

· 🏆 Level-Based: Complete levels with specific conditions
· 📊 Collection-Based: Unlock gallery items
· ⚡ Skill-Based: Combos, special matches
· 🎯 Hidden: Secret achievements (reveal when unlocked)

Achievement Structure:

```gdscript
{
    "id": "combo_master",
    "title": "Combo Master",
    "description": "Achieve a 10x combo",
    "category": "skill",
    "points": 50,
    "hidden": false,
    "progress_max": 10,
    "icon": "res://assets/achievements/combo.png",
    "unlock_event": "combo_made",
    "condition": func(combo): return combo >= 10
}
```

7. ProfileManager (Autoload) - NEW

Purpose: Track player statistics and profile information.

Statistics Tracked:

```gdscript
# Gameplay Stats
- Levels Played: 127
- Levels Completed: 98
- Total Stars: 247
- Total Score: 1,247,890
- Best Combo: 12
- Total Matches: 5,432
- Total Swaps: 12,891
- Boosters Used: 234
- Play Time: 24h 36m

# Collection Stats
- Gallery Completion: 67%
- Items Collected: 45/67
- Achievements Unlocked: 23/50

# Streaks
- Current Login Streak: 7 days
- Longest Streak: 15 days
```

8. ExperienceDirector (Revised)

Purpose: Event-driven narrative system that triggers story moments based on game events.

Event Triggers:

```gdscript
# Trigger Points
- Level Start (first time, special conditions)
- Level Complete (first time, score thresholds)
- Booster First Use (tutorial moments)
- Special Match Made (rare tile combinations)
- Gallery Item Unlock (story reveals)
- Achievement Unlock (character development)
```

Narrative Database Structure:

```gdscript
{
    "id": "post_level_5",
    "trigger": "level_complete",
    "conditions": {
        "level": 5,
        "first_time": true,
        "stars_required": 2
    },
    "content": {
        "type": "dialog",
        "speaker": "Mentor",
        "portrait": "mentor_happy",
        "text": "Excellent work! You've unlocked the ancient temple...",
        "choices": [
            {"text": "Tell me more", "next": "post_level_5a"},
            {"text": "Show me the map", "action": "open_world_map"}
        ]
    }
}
```

9. Refactored GameManager

Purpose: Pure match-3 game logic only. No UI, no progression, no narrative.

Responsibilities:

· Grid management and match detection
· Move validation and processing
· Score calculation
· Cascade handling
· Objective state tracking (via ObjectiveSystem)
· Booster effect application (via BoosterSystem)

What GameManager NO LONGER Does:

· ❌ Loads JSON level data (delegated to LevelManager)
· ❌ Tracks player progress (delegated to ProgressManager)
· ❌ Manages UI updates (emits events instead)
· ❌ Handles narrative triggers (emits events for ExperienceDirector)
· ❌ Controls boosters directly (uses BoosterSystem)

10. SettingsPage with Tabs

Purpose: Comprehensive settings management with tabbed interface.

Tab Structure:

```
┌─────────────────────────────────────┐
│ [Audio] [Video] [Gameplay] [Language] [Account] │
├─────────────────────────────────────┤
│ Audio Settings:                      │
│ ┌─────────────────────────────────┐ │
│ │ ▶ Master Volume:    ███████░░ 80%│ │
│ │ ▶ Music Volume:     ██████░░░ 60%│ │
│ │ ▶ SFX Volume:       ████████░░70%│ │
│ │ ▶ Voice Volume:     ███████░░ 70%│ │
│ │ □ Mute when minimized            │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

File Structure

```
match-3-game/
├── scripts/
│   ├── navigation/
│   │   ├── PageManager.gd           # Stack navigation (AUTOLOAD)
│   │   ├── HomePage.gd               # Main hub
│   │   ├── WorldMap.gd               # Level selection
│   │   ├── GalleryPage.gd            # Unlockables display
│   │   ├── AchievementsPage.gd       # Achievement display
│   │   ├── SettingsPage.gd           # Game settings
│   │   ├── AboutPage.gd              # Credits & info
│   │   └── ProfilePage.gd            # Player stats
│   │
│   ├── game/
│   │   ├── GameManager.gd            # Match-3 core (REFACTORED)
│   │   ├── GameBoard.gd              # Visual board
│   │   ├── ObjectiveSystem.gd        # Win conditions
│   │   └── BoosterSystem.gd          # Booster logic (NEW)
│   │
│   ├── progression/
│   │   ├── ProgressManager.gd        # Level unlocks, progress (NEW - AUTOLOAD)
│   │   ├── GalleryManager.gd         # Unlockable content (NEW - AUTOLOAD)
│   │   ├── AchievementManager.gd     # Achievement tracking (NEW - AUTOLOAD)
│   │   └── ProfileManager.gd         # Player stats (NEW - AUTOLOAD)
│   │
│   ├── experience/
│   │   ├── ExperienceDirector.gd     # Narrative triggers (REVISED - AUTOLOAD)
│   │   └── NarrativeManager.gd       # Dialog/cutscene display
│   │
│   └── systems/
│       ├── LevelManager.gd           # JSON data loading (AUTOLOAD)
│       ├── RewardManager.gd          # Currencies (AUTOLOAD)
│       ├── ThemeManager.gd           # Visual theming (AUTOLOAD)
│       └── EventBus.gd                # Global communication (AUTOLOAD)
│
├── scenes/
│   ├── pages/
│   │   ├── HomePage.tscn
│   │   ├── WorldMap.tscn
│   │   ├── GalleryPage.tscn
│   │   ├── AchievementsPage.tscn
│   │   ├── SettingsPage.tscn
│   │   ├── AboutPage.tscn
│   │   ├── ProfilePage.tscn
│   │   └── GameScene.tscn
│   │
│   ├── panels/
│   │   ├── NarrativePanel.tscn
│   │   ├── OutOfLivesDialog.tscn
│   │   └── LevelCompletePanel.tscn
│   │
│   └── components/
│       ├── LevelNode.tscn            # WorldMap level icon
│       ├── GalleryItem.tscn          # Gallery thumbnail
│       └── AchievementItem.tscn      # Achievement display
│
├── data/
│   ├── levels/                       # JSON level files
│   ├── gallery/                       # Gallery definitions
│   ├── achievements.json
│   ├── narratives.json
│   └── campaign.json                  # Stage definitions
│
└── autoloads.cfg                       # Configure all autoloads
```

---

Data Flow Examples

Example 1: Starting Game from HomePage

```gdscript
// Sequence:
1. User clicks "Play Next" on HomePage
2. HomePage calls ProgressManager.get_next_incomplete_level()
3. ProgressManager returns "level_7"
4. HomePage calls PageManager.go_to_page(GAME, {level_id: "level_7"})
5. PageManager instantiates GameScene with level_id
6. GameScene loads level data from LevelManager
7. GameScene initializes GameManager with level data
8. Game board appears
```

Example 2: Completing a Level

```gdscript
// Sequence:
1. GameManager detects all objectives complete
2. GameManager emits game_completed signal with results
3. ProgressManager receives signal, updates level progress
   - Marks level as completed
   - Calculates stars
   - Unlocks next level
4. GalleryManager checks for unlock conditions
5. AchievementManager updates relevant achievements
6. ExperienceDirector checks for narrative triggers
7. If narrative exists, shows it via NarrativeManager
8. GameScene calls PageManager.go_back() to return to HomePage
9. HomePage refreshes display (updates "Play Next" button)
```

Example 3: Unlocking Gallery Item

```gdscript
// Sequence:
1. Player completes level 10 with 3 stars
2. ProgressManager.complete_level() called
3. ProgressManager emits level_completed signal
4. GalleryManager receives signal, checks unlock rules
5. Rule matches → GalleryManager.unlock_item("character_art", "hero_alt")
6. GalleryManager emits gallery_item_unlocked signal
7. EventBus broadcasts to all listeners
8. HomePage receives signal, shows badge on Gallery button
9. If GalleryPage is open, it refreshes to show new item
10. ProfileManager updates gallery completion percentage
```

---

Implementation Phases

Phase 1: Foundation (Week 1-2)

Goal: Establish navigation and core managers

Task Files Affected Dependencies
Create EventBus autoload EventBus.gd None
Create PageManager PageManager.gd EventBus
Create ProgressManager ProgressManager.gd EventBus
Refactor HomePage HomePage.gd PageManager, ProgressManager
Create basic navigation between existing pages Various PageManager

Success Check:

· Can navigate between HomePage and existing pages
· Back button works correctly
· ProgressManager can save/load basic level progress

Phase 2: World Map & Level Progression (Week 3-4)

Goal: Implement level selection and unlock system

Task Files Affected Dependencies
Create WorldMap scene WorldMap.gd, WorldMap.tscn ProgressManager
Create LevelNode component LevelNode.gd, LevelNode.tscn None
Enhance ProgressManager for level unlocking ProgressManager.gd None
Implement level completion flow GameManager.gd (refactor) ProgressManager
Connect WorldMap to GameScene PageManager.gd LevelManager

Success Check:

· WorldMap shows correct unlock states
· Completing level N unlocks level N+1
· "Play Next" on HomePage works correctly
· Level progress persists across sessions

Phase 3: Gallery System (Week 5-6)

Goal: Implement unlockable gallery with categories

Task Files Affected Dependencies
Create GalleryManager GalleryManager.gd ProgressManager, EventBus
Create GalleryPage GalleryPage.gd, GalleryPage.tscn GalleryManager
Create GalleryItem component GalleryItem.gd, GalleryItem.tscn None
Define gallery unlock rules gallery_data.json GalleryManager
Connect game events to gallery unlocks GameManager.gd (events) GalleryManager, EventBus

Success Check:

· Gallery items unlock based on game events
· Categories display correctly
· Unlocked items persist
· Notification badges appear on Gallery button

Phase 4: Achievement System (Week 7-8)

Goal: Implement achievement tracking and display

Task Files Affected Dependencies
Create AchievementManager AchievementManager.gd ProgressManager, EventBus
Create AchievementsPage AchievementsPage.gd, AchievementsPage.tscn AchievementManager
Define achievements achievements.json None
Connect game events to achievements Various AchievementManager, EventBus

Success Check:

· Achievements track progress correctly
· Unlocked achievements show immediately
· Progress persists across sessions
· Hidden achievements reveal when unlocked

Phase 5: Profile & Statistics (Week 9-10)

Goal: Track and display player statistics

Task Files Affected Dependencies
Create ProfileManager ProfileManager.gd ProgressManager, EventBus
Create ProfilePage ProfilePage.gd, ProfilePage.tscn ProfileManager
Add statistics tracking to game events Various ProfileManager
Implement statistics display ProfilePage.gd ProfileManager

Success Check:

· All relevant statistics tracked
· Profile page displays correctly
· Statistics persist and update
· Collection completion percentages accurate

Phase 6: Narrative System (Week 11-12)

Goal: Implement event-driven narrative triggers

Task Files Affected Dependencies
Refactor ExperienceDirector ExperienceDirector.gd ProgressManager, EventBus
Create NarrativeManager NarrativeManager.gd PanelManager
Create NarrativePanel NarrativePanel.tscn None
Define narrative database narratives.json None
Connect triggers to game events GameManager.gd (events) ExperienceDirector

Success Check:

· Narratives trigger at correct times
· Each narrative only plays once
· Dialog choices affect game state where appropriate
· Narratives can be skipped

Phase 7: Settings & Polish (Week 13-14)

Goal: Implement settings and final polish

Task Files Affected Dependencies
Create SettingsPage with tabs SettingsPage.gd, SettingsPage.tscn None
Create AboutPage AboutPage.gd, AboutPage.tscn None
Implement save/load for settings SettingsPage.gd None
Add transition animations PageManager.gd None
Final testing and bug fixes Various All systems

Success Check:

· All settings persist
· About page displays correctly
· Smooth transitions between pages
· No regressions in existing functionality

---

Success Criteria

File Size Metrics

Component Current Target Status
GameUI.gd 800+ lines < 300 lines (split) ❌
GameManager.gd 600+ lines < 300 lines ❌
All new components N/A < 300 lines each ✅

Functional Requirements

Navigation

· HomePage shows correct "Play Next" based on progress
· All pages can navigate back to HomePage
· Back button/gesture works consistently
· Page transitions are smooth

Progression

· WorldMap correctly shows locked/unlocked/completed levels
· Completing level N with any stars unlocks level N+1
· Star ratings (1-3) persist and display correctly
· "Play Next" always points to first incomplete level

Gallery

· Gallery items unlock based on game events
· Categories (Concept Art, Cutscenes, Music, etc.) work
· Unlocked items are viewable
· Locked items show unlock condition
· Notification badges appear when new items unlock

Achievements

· Achievements track progress correctly
· Unlocked achievements show immediately
· Progress persists across sessions
· Hidden achievements reveal when unlocked

Profile

· All relevant statistics track accurately
· Collection completion percentages calculate correctly
· Play time accumulates properly
· Statistics update in real-time

Narrative

· Narratives trigger on correct events
· Each narrative only plays once
· Dialog choices affect game state where appropriate
· Narratives can be skipped

Settings

· Audio settings affect game volume
· Video settings apply correctly
· Language settings change UI text
· All settings persist

Code Quality Metrics

· `GameBoard.gd` < 600 lines (Phase A target)
· `GameManager.gd` < 400 lines (Phases B–D target)
· `GameUI.gd` < 250 lines (Phase E target)
· No other single file exceeds 400 lines of code
· GameManager no longer contains level loading JSON parsing or booster selection
· GameUI delegates all HUD/booster panel/game-over UI to component scenes
· All cross-component communication via EventBus or signals
· Each component has a clear, single responsibility
· No direct references between UI and game logic layers (always via events or GameManager signals)

Performance Metrics

· Page transitions < 0.3 seconds
· WorldMap loads with 50+ level nodes in < 1 second
· Gallery loads 100+ thumbnails without stutter
· Save/load operations < 0.5 seconds

---

Appendix: Sample Code Templates

1. EventBus Template

```gdscript
# event_bus.gd
extends Node
class_name EventBus

# Navigation events
signal page_change_requested(page: PageManager.Page, data: Dictionary)
signal navigation_back_requested

# Game events
signal game_started(level_id: String)
signal game_paused
signal game_resumed
signal level_completed(level_data: Dictionary, stars: int)
signal level_failed(level_data: Dictionary, reason: String)

# Progression events
signal level_unlocked(level_id: String)
signal gallery_item_unlocked(category: String, item_id: String)
signal achievement_unlocked(achievement_id: String)
signal achievement_progress_updated(achievement_id: String, progress: int, target: int)

# Economy events
signal coins_updated(new_amount: int, change: int)
signal gems_updated(new_amount: int, change: int)
signal lives_updated(new_amount: int, next_refill: int)

# Narrative events
signal narrative_triggered(narrative_id: String, context: Dictionary)
signal narrative_completed(narrative_id: String)

# UI events
signal notification_shown(message: String, type: String)
signal badge_updated(button_id: String, show: bool, count: int)
```

2. PageManager Template

```gdscript
# page_manager.gd
extends Node
class_name PageManager

enum Page {
    HOME,
    WORLD_MAP,
    GALLERY,
    ACHIEVEMENTS,
    SETTINGS,
    ABOUT,
    PROFILE,
    GAME
}

var page_stack: Array = []
var current_page: Control = null
var page_scenes: Dictionary = {}

func _ready() -> void:
    # Register with EventBus
    EventBus.page_change_requested.connect(go_to_page)
    EventBus.navigation_back_requested.connect(go_back)
    
    # Preload all page scenes
    _preload_pages()
    
    # Start at home
    go_to_page(Page.HOME)

func go_to_page(page: Page, data: Dictionary = {}) -> void:
    # Hide current page and add to stack
    if current_page:
        current_page.hide()
        page_stack.append(current_page)
    
    # Instantiate new page
    var new_page = page_scenes[page].instantiate()
    add_child(new_page)
    current_page = new_page
    
    # Initialize with data if method exists
    if new_page.has_method("initialize"):
        new_page.initialize(data)
    
    # Animate transition
    _animate_page_transition(new_page)
    
    EventBus.page_changed.emit(page_stack.back() if page_stack else null, page)

func go_back() -> void:
    if page_stack.is_empty():
        # At root - maybe show exit confirmation
        _show_exit_dialog()
        return
    
    # Remove current page
    current_page.queue_free()
    
    # Restore previous page
    current_page = page_stack.pop_back()
    current_page.show()
    _animate_page_appearance(current_page)
    
    Eventbus.navigation_back_completed.emit()
```

3. ProgressManager Save/Load Template

```gdscript
# progress_manager.gd - Save/Load Implementation
extends Node
class_name ProgressManager

const SAVE_PATH := "user://player_progress.save"
var player_data: Dictionary = {}

func _ready() -> void:
    load_game()

func save_game() -> void:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    var json_string = JSON.stringify(player_data)
    file.store_string(json_string)
    print("Game saved: ", SAVE_PATH)

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        create_new_player_data()
        return
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    var json = JSON.new()
    var parse_result = json.parse(json_string)
    
    if parse_result == OK:
        player_data = json.data
        print("Game loaded successfully")
    else:
        print("Save file corrupt, creating new")
        create_new_player_data()

func create_new_player_data() -> void:
    player_data = {
        "levels": {},
        "narratives_seen": [],
        "gallery_unlocks": {},
        "achievements": {},
        "statistics": {
            "total_play_time": 0,
            "total_matches": 0,
            "total_swaps": 0,
            "boosters_used": 0,
            "best_combo": 0
        },
        "first_launch": Time.get_unix_time_from_system()
    }
    
    # Unlock first level
    player_data.levels["level_1"] = {
        "unlocked": true,
        "completed": false,
        "stars": 0
    }
    
    save_game()
```

4. GalleryManager Unlock Rules Template

```gdscript
# gallery_manager.gd - Unlock Condition Checking
extends Node
class_name GalleryManager

var gallery_data: Dictionary = {}
var unlock_rules: Dictionary = {}

func _ready() -> void:
    load_gallery_data()
    connect_signals()

func connect_signals() -> void:
    EventBus.level_completed.connect(_check_level_complete_unlocks)
    EventBus.achievement_unlocked.connect(_check_achievement_unlocks)
    EventBus.special_event.connect(_check_special_unlocks)

func _check_level_complete_unlocks(level_data: Dictionary, stars: int) -> void:
    for category in unlock_rules:
        for item_id in unlock_rules[category]:
            var rule = unlock_rules[category][item_id]
            if rule.type == "level_complete" and rule.level == level_data.id:
                if rule.get("stars_required", 0) <= stars:
                    unlock_item(category, item_id)
            
            if rule.type == "level_stars" and rule.level == level_data.id:
                if stars >= rule.stars_required:
                    unlock_item(category, item_id)

func unlock_item(category: String, item_id: String) -> void:
    var progress = ProgressManager.get_player_data()
    
    if not progress.gallery_unlocks.has(category):
        progress.gallery_unlocks[category] = []
    
    if item_id not in progress.gallery_unlocks[category]:
        progress.gallery_unlocks[category].append(item_id)
        ProgressManager.save_game()
        EventBus.gallery_item_unlocked.emit(category, item_id)
        
        # Show notification
        var item_name = gallery_data[category][item_id].title
        EventBus.notification_shown.emit(
            "Gallery Unlocked: %s" % item_name,
            "gallery"
        )
```

5. GameManager Refactored Template

```gdscript
# game_manager.gd - REFACTORED (Pure game logic)
extends Node
class_name GameManager

# Signals only - no direct UI/progression calls
signal game_initialized(level_data)
signal score_updated(score)
signal moves_updated(moves_left)
signal objectives_updated(objectives)
signal game_completed(result: Dictionary)  # {success: bool, stars: int, score: int}
signal combo_made(combo_count)
signal special_match_made(match_type)

# Game state
var grid: Array = []
var score: int = 0
var moves_left: int = 0
var processing: bool = false

func initialize_game(level_data: Dictionary) -> void:
    # Pure game setup - no progression logic
    grid = _create_grid_from_layout(level_data.grid_layout)
    moves_left = level_data.moves
    score = 0
    processing = false
    
    # Initialize objective system with level goals
    ObjectiveSystem.initialize(level_data.objectives)
    
    game_initialized.emit(level_data)

func process_swap(pos1: Vector2i, pos2: Vector2i) -> bool:
    if processing or moves_left <= 0:
        return false
    
    processing = true
    
    # Validate swap creates match
    if not _would_create_match(pos1, pos2):
        processing = false
        return False
    
    # Perform swap
    _swap_tiles(pos1, pos2)
    moves_left -= 1
    moves_updated.emit(moves_left)
    
    # Process matches and cascade
    var match_result = _process_matches()
    
    # Update score
    score += match_result.score
    score_updated.emit(score)
    
    # Update objectives via ObjectiveSystem
    var objectives_status = ObjectiveSystem.update(match_result)
    objectives_updated.emit(objectives_status)
    
    # Check completion
    if ObjectiveSystem.all_completed():
        var stars = _calculate_stars()
        game_completed.emit({
            "success": true,
            "stars": stars,
            "score": score,
            "moves_used": level_data.moves - moves_left
        })
    elif moves_left == 0:
        game_completed.emit({
            "success": false,
            "reason": "out_of_moves",
            "score": score
        })
    
    # Emit special events for narrative system
    if match_result.combo >= 5:
        combo_made.emit(match_result.combo)
    
    processing = false
    return true

# All other match-3 logic methods remain, but with NO progression or UI code
```
