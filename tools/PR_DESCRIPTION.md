## PR 7 — Thin `GameFlowController` + Swap Booster Freeze Fix

**Commit:** `df3af2a` · **Branch:** `main` · **Date:** 2 Apr 2026

---

### Summary

This PR completes the PR 7 milestone from the Godot migration plan:
**`GameFlowController` is now a pure sequencer** — it waits, runs the bonus cascade, saves stars, and fires the bridge event. All reward granting and ad-hoc node lookups have been removed. A related gameplay freeze triggered by the swap booster collecting a coin on the last move is also fixed.

---

### Changes

#### `games/match3/board/services/GameFlowController.gd`

**Removed — reward granting**
- Removed `RewardManager.grant_level_completion_reward()` call. Reward granting is the pipeline's responsibility (`GrantRewardsStep` runs after `show_rewards`). `GameFlowController` must not reach outside its sequencing role.

**Removed — fragile node lookups**
- Replaced four `get_node_or_null("/root/...")` and `Engine.get_singleton(...)` calls with direct autoload references (`StarRatingManager`, `LevelManager`). Both are registered in `project.godot` and are globally available — no traversal needed.

**Fixed — `_calculate_stars()` crash**
- `LevelData` is a typed `RefCounted` class, not a `Dictionary`. Calling `.has("moves")` on it threw `Invalid call. Nonexistent function 'has'`, silently falling back to 0 stars every time. Fixed by accessing `level_data.moves` directly.

**Before / After — `on_level_complete`**
```gdscript
# BEFORE
var star_manager = Engine.get_singleton("StarRatingManager") if ... else
    (GameRunState.board_ref.get_node_or_null("/root/StarRatingManager") if ...)
if star_manager:
    star_manager.save_level_stars(...)
var rm = GameRunState.board_ref.get_node_or_null("/root/RewardManager") if ...
if rm and rm.has_method("grant_level_completion_reward"):
    rm.grant_level_completion_reward(GameRunState.level, stars)  # ← removed

# AFTER
if StarRatingManager:                          # autoload, direct reference
    StarRatingManager.save_level_stars(GameRunState.level, stars)
# NOTE: Reward granting is GrantRewardsStep's responsibility — not here.
GameStateBridge.emit_level_complete()
```

---

#### `games/match3/board/services/BoosterService.gd`

**Fixed — parse error** (`NodeResolversApi` undeclared identifier)

`_get_board()` was trying to reference `NodeResolversApi` which was never declared in scope, causing a script parse error that broke the entire `GameBoard._ready()` load chain. Replaced with a direct call to the `NodeResolvers` autoload (registered in `project.godot`).

```gdscript
# BEFORE — caused SCRIPT ERROR: Parse Error: Identifier "NodeResolversApi" not declared
if NodeResolversApi != null:
    nr = NodeResolversApi
else:
    nr = load("res://scripts/helpers/node_resolvers.gd")

# AFTER — NodeResolvers is an autoload, use it directly
if NodeResolvers.has_method("_get_board"):
    var b = NodeResolvers._get_board()
```

---

#### `games/match3/board/services/BoardActionExecutor.gd`

**Fixed — swap booster freeze on collectible collection**

When the swap booster moved a coin to the bottom row on the last move:
1. `processing_moves` was still `true` when `_check_collectibles_at_bottom()` was called
2. `CollectibleService` collected the coin correctly but then skipped gravity+refill (`"Skipping deferred_gravity_then_refill because processing_moves is true"`)
3. The empty cell was never filled, the board froze

Fix: clear `processing_moves` **before** calling `_check_collectibles_at_bottom()`, then explicitly run `animate_gravity()` + `animate_refill()` to own the refill in the booster path. Also call `GameStateBridge.attempt_level_complete()` in the no-cascade branch so objectives met via booster are always checked.

```gdscript
# BEFORE
board._check_collectibles_at_bottom()          # flag still true → refill skipped
... process_cascade if matches ...
GameRunState.processing_moves = false          # too late — empty cell already frozen

# AFTER
GameRunState.processing_moves = false          # clear first
await board._check_collectibles_at_bottom()   # collectible collected AND refill allowed
if board.has_method("animate_gravity"):
    await board.animate_gravity()              # fill the empty cell
if board.has_method("animate_refill"):
    await board.animate_refill()
if matches:
    await board.process_cascade()
else:
    GameStateBridge.attempt_level_complete()   # check completion when no cascade follows
```

---

#### `games/match3/board/services/CollectibleService.gd`

**Fixed — `attempt_level_complete()` skipped during booster moves**

The level-complete check after collecting the last objective was gated on `if not GameRunState.processing_moves`. This prevented the game from detecting a win when a booster (swap, hammer, etc.) was the action that delivered the final collectible. Removed the guard — the caller is now responsible for clearing the flag before invoking the collectible check.

```gdscript
# BEFORE
if not GameRunState.processing_moves:     # ← blocked completion during booster moves
    var gsb = _get_bridge()
    if gsb != null and gsb.has_method("attempt_level_complete"):
        gsb.attempt_level_complete()

# AFTER — always check; flag management is the caller's responsibility
var gsb = _get_bridge()
if gsb != null and gsb.has_method("attempt_level_complete"):
    gsb.attempt_level_complete()
```

---

### Files Changed

| File | +/- | What |
|---|---|---|
| `games/match3/board/services/GameFlowController.gd` | +14 / -15 | Remove RewardManager call, replace `get_node_or_null` with autoloads, fix `LevelData.has()` crash |
| `games/match3/board/services/BoardActionExecutor.gd` | +14 / -2 | Fix swap booster freeze: clear flag before collectible check, own gravity+refill, always check completion |
| `games/match3/board/services/BoosterService.gd` | +3 / -13 | Fix parse error: replace `NodeResolversApi` with `NodeResolvers` autoload |
| `games/match3/board/services/CollectibleService.gd` | +3 / -5 | Remove `processing_moves` guard on `attempt_level_complete()` |

---

### Bugs Fixed

| # | Symptom | Root Cause | Fix |
|---|---|---|---|
| 1 | Reward screen never appeared after level complete | `GameStateBridge.emit_level_complete()` had been removed by previous work; `LoadLevelStep` never received the signal to advance the pipeline | Restored the bridge emit |
| 2 | 0 stars awarded every level | `LevelData.has("moves")` threw `Nonexistent function 'has'` on a typed class | Use `level_data.moves` directly |
| 3 | Board froze after swap booster collected last coin | `processing_moves = true` when `CollectibleService` tried to schedule gravity+refill | Clear flag before collectible check; own refill in booster path |
| 4 | `BoosterService` parse error on load | `NodeResolversApi` identifier undeclared in scope | Use `NodeResolvers` autoload directly |

---

### Testing

- ✅ Completed a level via normal play — reward/narrative pipeline advances correctly
- ✅ Completed a level by collecting the last coin with the swap booster on the last move — board refills, level complete screen shown
- ✅ Failed a level (out of moves) — failure screen shown correctly
- ✅ `BoosterService` no longer causes a parse error on `GameBoard._ready()`

---

### Migration Plan Status

| PR | Status |
|---|---|
| PR 6 — Isolate GameBoard | ✅ Complete |
| **PR 7 — Thin GameFlowController** | ✅ **Complete** |
| PR 8 — Introduce Pipeline | 🔜 Next |
