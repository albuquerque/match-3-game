## PR 12 — Final Cleanup + BoosterPanel Fix

**Branch:** `refactor_pr_12_final_cleanup` → `main` · **Date:** 4 Apr 2026

---

### Summary

Removes all dead scripts, orphaned `.uid` files, and stale duplicates that accumulated across PRs 6–11. Also fixes the BoosterPanel which was broken due to a deleted stub script, a wrong base class, and a signal timing race against `GameStateBridge`. No other behaviour changes — game is identical after this PR. Leaves `scripts/` containing only files that are actively used.

---

### BoosterPanel Bug Fixes

Three separate bugs were causing the BoosterPanel to show empty when a level loaded:

#### 1. Stale `ext_resource` path in `MainGame.tscn`
`MainGame.tscn` line 136 referenced the deleted stub `res://scripts/ui/components/BoosterPanelComponent.gd`. Updated to the real script at `res://games/match3/ui/components/BoosterPanelComponent.gd`.

#### 2. Wrong base class
`BoosterPanelComponent.gd` declared `extends Control` but the `BoosterPanel` node in `MainGame.tscn` is a `PanelContainer`. Godot's `instance_create` rejects the assignment when the script base class doesn't match the node type — so `_ready()` never ran and no boosters were ever populated. Fixed to `extends PanelContainer`.

#### 3. Signal timing race with `GameStateBridge`
The panel was wiring itself to `board_ref.level_loaded_ctx`, but `GameStateBridge.emit_level_loaded_ctx()` has an early return when `board_ref` is `null` — which it often is at initial load time. The signal was never emitted so the panel never received it. Replaced the signal-wait approach with a `_process` poll that watches `GameRunState.initialized` directly each frame and calls `_populate()` as soon as it becomes `true`, then disables the poll. Future level loads still connect to `board_ref.level_loaded_ctx` once the board is available.

---

### Files Deleted

#### Dead scripts — no references in any `.gd`, `.tscn`, or `.tres`

| File | Reason |
|---|---|
| `scripts/LevelTransition.gd` | Replaced by pipeline `ShowRewardsStep` / `ShowLevelFailureStep` in PR 8 |
| `scripts/GalleryUI.gd` | Replaced by `systems/gallery_system.gd` + `scripts/ui/gallery/` |
| `scripts/RewardNotification.gd` | Replaced by `RewardTransitionController` in `meta/rewards/system/` |
| `scripts/DLCDownloadTest.gd` | Debug test script — never referenced by any scene or autoload |
| `scripts/DLCSystemTest.gd` | Debug test script — never referenced by any scene or autoload |

#### Root-level duplicates — live version is in `scripts/ui/`

| Deleted | Live version |
|---|---|
| `scripts/AchievementsPage.gd` (905 lines, old standalone) | `scripts/ui/AchievementsPage.gd` (421 lines, extends `ScreenBase`) — referenced by `scenes/ui/pages/AchievementsPage.tscn` |
| `scripts/ShopUI.gd` | `scripts/ui/ShopUI.gd` — referenced by `scenes/ui/pages/ShopUI.tscn` |

#### Orphaned `.uid` files — no matching `.gd` exists

All 11 `.uid` files whose source script was deleted in earlier PRs:

| Orphan `.uid` | Source deleted in |
|---|---|
| `scripts/GameManager.gd.uid` | PR 6.5d |
| `scripts/SettingsDialog.gd.uid` | PR 5 / PR 6 |
| `scripts/WorldMap.gd.uid` | PR 6 |
| `scripts/TextureCache.gd.uid` | PR 6 |
| `scripts/ui/BoosterPanel.gd.uid` | PR 6 |
| `scripts/ui/FloatingMenu.gd.uid` | PR 6 |
| `scripts/ui/UIBootstrap.gd.uid` | PR 6 |
| `scripts/ui/GalleryUI.gd.uid` | PR 6 |
| `scripts/ui/AchievementsPanel.gd.uid` | PR 6 |
| `scripts/ui/gallery_adapter.gd.uid` | PR 6 |
| `scripts/ui/WorldMapAdapter.gd.uid` | PR 6 |

---

### What Was Not Deleted

All remaining `scripts/` files are live:

| File | Used by |
|---|---|
| `scripts/Tile.gd` | `scenes/Tile.tscn` |
| `scripts/GameUI.gd` | `scenes/MainGame.tscn` |
| `scripts/OutOfLivesDialog.gd` | `scenes/MainGame.tscn` |
| `scripts/MainMenu.gd` | `scenes/MainMenu.tscn` |
| `scripts/AboutDialog.gd` | `scenes/AboutDialog.tscn` |
| `scripts/VisualAnchorManager.gd` | Autoload (`project.godot`), `systems/effects/` |
| `scripts/helpers/node_resolvers.gd` | Autoload, used throughout |
| `scripts/ui/` | All page scenes under `scenes/ui/pages/` |
| `scripts/ui/components/` | `scenes/MainGame.tscn` |
| `scripts/components/LevelNode.gd` | WorldMap level buttons |

---

### Verification

Zero stale references to deleted files remain — confirmed by full codebase grep across all `.gd`, `.tscn`, `.tres`, and `.godot` files.

---

### Files Changed

| Category | Count |
|---|---|
| Dead scripts deleted | 5 |
| Duplicate scripts deleted | 2 |
| Orphan `.uid` files removed | 11 |
| `MainGame.tscn` — fixed stale `ext_resource` path | 1 |
| `BoosterPanelComponent.gd` — fixed base class + replaced signal-wait with `_process` poll | 1 |
| **Total** | **20** |

---

### Testing

- ✅ Game launches — zero `SCRIPT ERROR` or `Parse Error`
- ✅ BoosterPanel populates correctly when a level board loads
- ✅ Booster counts update when boosters are used
- ✅ Level plays through to completion
- ✅ Reward screen, gallery, narrative all functional
- ✅ Progress saves correctly

---

### Migration Plan Status

| PR | Status |
|---|---|
| PR 6 — Isolate GameBoard | ✅ Complete |
| PR 7 — Thin GameFlowController | ✅ Complete |
| PR 8 — Introduce Pipeline | ✅ Complete |
| PR 9 — Meta Extraction | ✅ Complete |
| PR 10 — Systems Cleanup | ✅ Complete |
| PR 11 — Remove EventBus Completely | ✅ Complete |
| **PR 12 — Final Cleanup** | ✅ **Complete** |

### 🏁 Refactor Complete

The target architecture from `godot_refactor_plan.md` is now fully achieved:

```
res://
├── games/match3/      — all gameplay logic, self-contained
├── experience/        — pipeline, narrative, flow orchestration
├── meta/              — progression, rewards, profile, gallery
├── systems/           — audio, ads, assets, DLC, effects
├── scripts/           — UI pages, components, helpers (thin layer)
└── data/              — JSON-driven content
```

- ✅ `GameManager` removed
- ✅ `EventBus` removed
- ✅ `MatchOrchestrator` removed
- ✅ `ExperienceDirector` = only orchestrator
- ✅ Match3 fully encapsulated in `games/match3/`
- ✅ No global event system
- ✅ No cross-layer import violations
- ✅ Signals owned by true emitters
