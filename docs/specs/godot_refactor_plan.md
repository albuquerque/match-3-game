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
