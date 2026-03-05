## Current Problems

## Instruction for copilot to populate this document
Looking at out problem statement, come up with a plan to reacrchitect the GameUI and Gamemanager. Organise scenes into separate folder hierarchy, do the same with scripts. Divide the 2 files into PageManager, ProgressManager, Gallerymanager, Acheivementsmanager, Profilemanager, etc. Extract Sub-UI controllers into their own componets, delegate responsibilites of the gamemanager, Adopt an Event-bus for loose coupling, Leverage godot's features more effectively, like Resoures for data and Signals instead of direct calls

### Identified issues in Current Code Base

| Problem | Location                           | Impact |
|---------|------------------------------------|--------|
| **God Classes** | `GameManager.gd`, `GameUI.gd`      | High - Difficult to maintain and extend |
| **Tight Coupling** | UI directly manipulates Game logic | High - Changes in one class affect the other |
| **Lack of Separation of Concerns** | UI and Game logic intertwined | High - Hard to test and debug |
| **Missing Abstraction** | No clear interfaces for UI and Game logic | Medium - Limits flexibility and scalability |
|** Unclear Navigation** | No centralized navigation system | Medium - Difficult to manage scene transitions |
| **Progress Tracking** | No clear way to track player progress | Medium - Hinders player experience and game flow |

## Proposed Refactor

## Goal
Provide a pragmatic, incremental re-architecture of the monolithic `GameUI.gd` and `GameManager.gd` into small, testable, loosely-coupled components. The aim is to make UI flows predictable, easier to test, and safe to modify while keeping the game runnable at every migration step.

## High-level approach (one-sentence)
Split responsibilities, adopt an EventBus for loose coupling, extract UI subcomponents into their own scene/script pairs, and use Godot Resources + Signals for data and communication instead of direct tight calls.

---

Checklist (do these in order, each step small and testable):
- [ ] Create package layout (scenes + scripts folders)
- [ ] Add EventBus singleton (Signals only)
- [ ] Scaffold new manager classes (PageManager, ProgressManager, GalleryManager, AchievementsManager, ProfileManager, UIComponents)
- [ ] Wire one adapter end-to-end (Gallery) and run smoke test
- [ ] Migrate StartPage wiring to PageManager and verify navigation flows
- [ ] Move game-progress responsibilities from GameManager -> ProgressManager with Resource-backed save data
- [ ] Replace remaining direct calls with EventBus signals and small public APIs
- [ ] Add unit tests/harness for managers and a small integration smoke test
- [ ] Cleanup, docs, and prepare for incremental removal of legacy code (comment, don't delete)

---

Proposed repository layout
- scenes/
  - ui/
    - StartPage.tscn
    - Gallery/
      - Gallery.tscn
      - GalleryInner.tscn
    - WorldMap/
    - Settings/
- scripts/
  - ui/
    - PageManager.gd            # central navigation/page lifecycle manager
    - PageAdapters/             # adapters that instantiate pages (GalleryUI.gd already partly here)
      - GalleryAdapter.gd
      - AchievementsAdapter.gd
      - WorldMapAdapter.gd
    - components/               # extracted sub-UI controllers
      - HUDComponent.gd
      - BoosterPanelComponent.gd
      - FloatingMenuComponent.gd
  - managers/
    - ProgressManager.gd       # progress persistence, checkpointing, queries
    - GalleryManager.gd        # manages unlocked images, load/save, thumbnails
    - AchievementsManager.gd   # achievement state, claim flow
    - ProfileManager.gd        # player profile, settings
  - core/
    - EventBus.gd              # singleton autoload for all signals
    - Resources/               # .tres resource classes and factories
      - PlayerProgress.tres
      - GalleryConfig.tres

Rationale: separating scenes from scripts and grouping by role improves discoverability and reduces accidental edits to large monoliths.

---

Manager responsibilities (contract style)
- PageManager (scripts/ui/PageManager.gd)
  - Inputs: Events from UI adapters (open_page, close_page, request_navigation)
  - Outputs: Emits signals: page_opened(page_id), page_closed(page_id), navigation_failed(reason)
  - Responsibilities: instantiate/destroy page scenes, maintain page stack, manage modal overlays (single source of truth)
  - Error modes: failed instantiation, missing scene — log and fall back to safe placeholder

- ProgressManager (scripts/managers/ProgressManager.gd)
  - Inputs: Events to update progress or request load/save
  - Outputs: Signals progress_loaded(progress), progress_saved(success)
  - Data: backs store in `user://` via Resource `PlayerProgress.tres`
  - Error modes: corrupt save file — fallback to safe defaults and produce a recoverable backup file

- GalleryManager
  - Responsibilities: centralize unlocked images, thumbnails, download/update operations, and expose an async API for GalleryAdapter
  - Emits: gallery_updated(image_id), gallery_image_ready(image_id, path)

- AchievementsManager
  - Responsibilities: track achievement progress, claim flows, persist claimed state; raise events when achievements unlock

- ProfileManager
  - Responsibilities: language settings, vibration/music toggles, account metadata

- EventBus (autoload)
  - Single file with only signals and helpers. No heavy logic. Example signals: open_page(page_name:String), close_page(page_name:String), progress_updated(dict), gallery_opened(), achievement_claimed(id:String)
  - Managers and UI adapters should prefer EventBus signals over direct references. Use Typed Callables for optional direct connect when appropriate.

---

Design decisions and Godot features to leverage
- Resources (`.tres`) for structured, versioned data: player progress, gallery config, level metadata. Easier to inspect and migrate.
- Signals everywhere: push events through EventBus, avoid get_node() spaghetti between distant UI nodes.
- Scenes as small, single-responsibility units: adapters vs inner content separation (e.g., `GalleryAdapter.tscn` contains Background + adapter glue; `GalleryInner.tscn` contains the actual gallery viewer)
- CanvasLayer / z-index conventions: centralize z-index helpers in PageManager or VisualAnchorManager (already exists) and avoid ad-hoc manipulation throughout UI code.
- Single source of truth for modal overlays: PageManager should be responsible for creating/destroying full-screen overlays — adapters can request overlays to appear via EventBus.

---

Migration plan (phased, reversible)
Phase 0 — Safety + scaffolding (small, <= 1 file each step)
- Add `scripts/core/EventBus.gd` and register as Autoload. Implement only signals (no logic). Commit.
- Add `scripts/managers/ProgressManager.gd` scaffold with empty methods (load/save). Add `scripts/managers/GalleryManager.gd` scaffold. Commit.

Phase 1 — Extract adapters & components (low-risk)
- Move HUD, FloatingMenu, BoosterPanel into `scripts/ui/components/` as thin wrappers (no behavior changes). Replace direct references in `GameUI.gd` to call component API. Commit.
- Add `ui/PageManager.gd` scaffold and wire GameUI to forward open/close requests to PageManager where practical (call into PageManager only; do not delete original code yet). Commit.

Phase 2 — Replace single flows end-to-end (medium risk)
- Implement GalleryManager API and GalleryAdapter that consumes it. Route StartPage->Gallery via EventBus (open_page request). Fully test gallery open/close and ensure StartPage regains focus. Commit.
- Run smoke tests: open/close gallery, settings, achievements.

Phase 3 — Migrate GameManager responsibilities (higher risk)
- Move progress/load/save logic from GameManager into ProgressManager and switch code to query ProgressManager for player state.
- Keep `GameManager.gd` as a thin facade that delegates to new managers until full cutover.

Phase 4 — Clean up and remove legacy
- When flows validated, comment/deprecate old functions in `GameUI.gd` and `GameManager.gd` (do not delete immediately). Run large-scale lint/tests and then remove dead code.

Rollback strategy: commits are small and frequent. Create WIP branches at phase boundaries. Use comments for deprecated code so it can be restored quickly.

---

Signals & API examples (naming convention)
- EventBus signals (semantic, small payloads):
  - open_page(page_name: String, params: Dictionary = {})
  - close_page(page_name: String)
  - progress_request_save(reason:String)
  - progress_loaded(progress: Resource)
  - gallery_opened()
  - gallery_closed()
  - achievement_unlocked(id:String)

- Manager public methods (examples):
  - ProgressManager.save_progress(reason: String) -> void
  - ProgressManager.load_progress() -> Resource
  - GalleryManager.request_thumbnail(image_id) -> void (emits gallery_image_ready)
  - PageManager.open(page_name: String, params: Dictionary = {}) -> bool

---

Testing, QA and quality gates
- Unit tests for managers (ProgressManager, GalleryManager, AchievementsManager) using the existing tests harness.
  - Happy path + corrupted save fallback for ProgressManager
  - GalleryManager: locked/unlocked, image-ready events
- Integration smoke tests:
  - Start app -> open Gallery -> close -> StartPage interactive
  - Start app -> open Settings -> change vibration -> persisted across restart
- Quality gates before merge:
  - Lint/format (GDScript style + tabs)
  - Run the project's static checker (get_errors) and fix any parse/runtime warnings introduced
  - Run smoke runs locally (developer runs Godot and exercises flows)

---

Edge cases and risks
- Race conditions: many adapters call `call_deferred()` and create overlays. Mitigation: PageManager centralizes overlay lifecycle and provides explicit ordering.
- Save file corruption: ProgressManager must detect and back up corrupted saves (move to `.bak`) and re-create a default progress resource.
- Z-index / CanvasLayer collisions: central z-index table with safe bounds. VisualAnchorManager should be the authority.

---

Deliverables for the first sprint (concrete)
- `scripts/core/EventBus.gd` (autoload)
- `scripts/managers/ProgressManager.gd` (scaffold + tests)
- `scripts/managers/GalleryManager.gd` (scaffold + basic API)
- `scripts/ui/PageManager.gd` (scaffold)
- Move at least two UI subcomponents into `scripts/ui/components/` and wire them through PageManager
- `docs/GameUI-GameManger-Refactor.md` updated (this document)

---

Next immediate developer action (one-liner)
1) Create `scripts/core/EventBus.gd` as an Autoload with the minimal set of signals, commit it. 2) Create `scripts/managers/ProgressManager.gd` scaffold and a unit test that loads/saves an in-memory Resource. 3) Wire StartPage -> EventBus.open_page("gallery") path and test.

Notes
- Keep all edits small, commit often, and create a backup branch at each milestone. Prefer commenting out deprecated code instead of deleting it until the new flow is fully validated.
- I avoided rewriting code in this doc; the next step is to scaffold the files above and run the smoke tests you prefer.
