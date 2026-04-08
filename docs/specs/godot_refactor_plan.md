# Godot Refactor Plan -- Match-3 Project

Generated: 2026-03-27T13:10:11.282334

------------------------------------------------------------------------

## 🎯 Goal

Refactor the project to: - Remove "God orchestrator" anti-pattern - Make
game modes (Match3, Mahjong, Sudoku) swappable - Use Godot-native
signals instead of global event buses - Simplify architecture and
improve maintainability

------------------------------------------------------------------------

## 🗂️ TARGET STRUCTURE

    res://
    ├── app/
    ├── core/
    ├── systems/
    ├── meta/
    ├── experience/
    ├── games/
    │   ├── base/
    │   ├── match3/
    │   ├── mahjong/
    │   └── sudoku/
    └── ui/

------------------------------------------------------------------------

## 🔁 FILE MAPPING (CURRENT → NEW)

### ❌ REMOVE COMPLETELY

-   scripts/GameManager.gd → DELETE
-   scripts/MatchOrchestrator.gd → DELETE
-   scripts/core/EventBus.gd → DELETE
-   scripts/EventBus.gd → DELETE

------------------------------------------------------------------------

### 🔄 MOVE + REFACTOR

#### Experience Layer

-   scripts/ExperienceDirector.gd → experience/ExperienceDirector.gd

------------------------------------------------------------------------

#### Game Layer (Match3)

-   scripts/GameBoard.gd → games/match3/board/GameBoard.gd

-   scripts/game/GameFlowController.gd →
    games/match3/GameFlowController.gd\
    (⚠️ Reduce responsibility heavily)

------------------------------------------------------------------------

### 🆕 CREATE NEW FILES

#### Base Game Interface

games/base/BaseGame.gd

``` gdscript
class_name BaseGame

signal game_won
signal game_lost

func start(level_data): pass
func stop(): pass
```

------------------------------------------------------------------------

#### Match3 Root

games/match3/Match3Game.gd

Responsibilities: - Own GameBoard - Emit win/loss - No internal logic

------------------------------------------------------------------------

#### Pipeline System

experience/pipeline/ - ExperiencePipeline.gd - PipelineStep.gd

------------------------------------------------------------------------

## 🧠 RESPONSIBILITY RULES

### ExperienceDirector

-   controls flow
-   starts/stops games
-   listens to game signals

❌ must NOT access GameBoard

------------------------------------------------------------------------

### Match3Game

-   owns GameBoard
-   translates signals upward

------------------------------------------------------------------------

### GameBoard

-   ALL gameplay logic
-   match finding
-   cascades
-   spawning

------------------------------------------------------------------------

### UI

-   listens only
-   no logic

------------------------------------------------------------------------

## 🔥 MIGRATION PLAN

### Phase 1 -- Remove God Objects

-   Delete GameManager
-   Delete MatchOrchestrator
-   Remove EventBus usage

------------------------------------------------------------------------

### Phase 2 -- Introduce BaseGame

-   Create BaseGame
-   Wrap Match3 logic inside Match3Game

------------------------------------------------------------------------

### Phase 3 -- Move GameBoard

-   Relocate GameBoard to match3 module
-   Ensure no external dependencies

------------------------------------------------------------------------

### Phase 4 -- Refactor ExperienceDirector

-   Only talk to BaseGame
-   Implement simple flow: start → wait → result → next

------------------------------------------------------------------------

### Phase 5 -- Signals Only

Replace all global events with: - signals - direct connections

------------------------------------------------------------------------

### Phase 6 -- Cleanup

-   Remove duplicate managers
-   Merge progression logic into meta/

------------------------------------------------------------------------

------------------------------------------------------------------------

# PR 5e --- Final Decoupling Fix Plan

## 🎯 Goal

Eliminate remaining architectural coupling: 1. GameBoard → UI / Meta
systems 2. GameFlowController → GameBoard direct calls

------------------------------------------------------------------------

## 🚨 Issue 1 --- GameBoard coupled to UI / Meta

### Problem

GameBoard directly calls: - GalleryManager - GameUI

### Fix Strategy

Convert all outward effects into signals.

### Step 1 --- Add Signals to GameBoard

``` gdscript
signal shard_collected(amount)
signal level_completed(result)
```

------------------------------------------------------------------------

### Step 2 --- Replace Direct Calls

#### Before:

``` gdscript
GalleryManager.add_shard(amount)
GameUI.hide_level_complete_ui()
```

#### After:

``` gdscript
emit_signal("shard_collected", amount)
emit_signal("level_completed", result)
```

------------------------------------------------------------------------

### Step 3 --- Wire in Match3Game

``` gdscript
game_board.shard_collected.connect(GalleryManager.add_shard)
game_board.level_completed.connect(GameUI.on_level_complete)
```

------------------------------------------------------------------------

## 🚨 Issue 2 --- GameFlowController controlling GameBoard

### Problem

GameFlowController calls: - show_skip_bonus_hint - update_tile_visual -
hide_skip_bonus_hint

### Fix Strategy

Convert to signal-driven commands.

------------------------------------------------------------------------

### Step 1 --- Add Signals to GameFlowController

``` gdscript
signal request_show_skip_bonus_hint
signal request_hide_skip_bonus_hint
signal request_update_tile_visual(tile)
```

------------------------------------------------------------------------

### Step 2 --- Replace Direct Calls

#### Before:

``` gdscript
game_board.show_skip_bonus_hint()
```

#### After:

``` gdscript
emit_signal("request_show_skip_bonus_hint")
```

------------------------------------------------------------------------

### Step 3 --- Connect in GameBoard

``` gdscript
flow_controller.request_show_skip_bonus_hint.connect(show_skip_bonus_hint)
flow_controller.request_hide_skip_bonus_hint.connect(hide_skip_bonus_hint)
flow_controller.request_update_tile_visual.connect(update_tile_visual)
```

------------------------------------------------------------------------

## ✅ Validation Checklist

-   GameBoard has ZERO references to UI / Meta systems
-   GameFlowController has ZERO direct calls to GameBoard
-   All interactions use signals
-   Game remains fully playable

------------------------------------------------------------------------
------------------------------------------------------------------------

## 🚀 Outcome

-   GameBoard = pure gameplay owner
-   GameFlowController = pure decision maker
-   UI / Meta = passive listeners

Architecture is now fully decoupled and scalable.


## 🚨 HARD RULES

-   No cross-layer access
-   No global event bus
-   No "manager" controlling gameplay
-   Game logic stays inside game module

------------------------------------------------------------------------

## ✅ FINAL RESULT

-   Clean separation of concerns
-   Swappable game modes
-   Predictable flow
-   Easier debugging

------------------------------------------------------------------------

## 💬 NEXT STEP

Implement Phase 1 first. Do NOT attempt full refactor at once.
