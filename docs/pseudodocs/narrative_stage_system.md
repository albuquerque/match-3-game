# Narrative Stage System Design

## Purpose

NarrativeStage is a dynamic storytelling system that:

* Uses UI real estate above the board
* Supports animated story progression
* Updates during gameplay
* Syncs with match events and progression

Example:

Exodus Level:

Start:
Moses overlooking full sea

During Play:
Water turbulence increases

Goal Complete:
Sea parts fully

---

## Core Concepts

NarrativeStage is NOT a cutscene.

It is:

* Persistent UI layer
* Event driven
* JSON configured
* DLC extendable

---

## Architecture Placement

UI Layer
NarrativeStage Renderer
NarrativeStage Controller
Experience Director
Game Systems

---

## Components

### NarrativeStageController.gd

Responsibilities:

* Load stage JSON
* Manage stage state
* React to EventBus
* Trigger animations
* Update visual anchors

---

### NarrativeStageRenderer.gd

Handles:

* Sprite animations
* Spine animations
* Particle effects
* Timeline transitions

Uses:

VisualAnchorManager

---

### NarrativeStageData

JSON Example:

```json
{
  "id": "exodus_sea",
  "anchor": "top_banner",
  "states": [
    {
      "name": "intro",
      "asset": "moses_full_sea.png"
    },
    {
      "name": "progress_50",
      "asset": "water_shifting.png"
    },
    {
      "name": "goal_complete",
      "asset": "sea_parted.png"
    }
  ],
  "transitions": [
    { "event": "level_start", "to": "intro" },
    { "event": "progress_50", "to": "progress_50" },
    { "event": "goal_complete", "to": "goal_complete" }
  ]
}
```

---

## Supported Narrative Elements

* Static images
* Animated sprites
* Character poses
* Timeline animations
* Interactive visual panels
* Particle effects
* Audio cues

---

## DLC Integration

DLC may provide:

* Narrative JSON
* Animation assets
* Audio tracks
* Custom anchors

Loaded through DLCManager.

---

## Event Integration

Receives:

* MatchCountReached
* ComboAchieved
* BossDamage
* LevelStart
* LevelComplete

via EventBus.

---

## Visual Anchors

Uses:

VisualAnchorManager

Example Anchors:

* top_banner
* left_story_panel
* background_overlay
* foreground_character

---

## State Machine

NarrativeStage is a state driven system.

States:

Intro
Progress
Climax
Completion

Transitions triggered by events.

---

## Performance Considerations

* Preload assets per level
* Use object pooling for animations
* Avoid per-frame heavy logic
* Use signal based updates

---

## Example Runtime Flow

ExperienceDirector -> start Narrative Stage

NarrativeStageController:

* loads JSON
* sets initial state

Game events occur

Controller updates stage state

Renderer updates visuals dynamically
